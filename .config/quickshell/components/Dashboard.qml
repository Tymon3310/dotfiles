import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    
    property var parentWindow: null
    property var spotify: null
    property var sys: null
    property bool hovered: dashHoverHandler.hovered
    
    implicitHeight: mainLayout.height + 28
    readonly property string customFont: "Google Sans Code NF"

    HoverHandler {
        id: dashHoverHandler
    }
    
    ListModel {
        id: cpuProcsModel
    }
    
    ListModel {
        id: memProcsModel
    }
    
    ListModel {
        id: gpuProcsModel
    }
    
    onSysChanged: {
        if (!sys) {
            cpuProcsModel.clear();
            memProcsModel.clear();
            gpuProcsModel.clear();
            return;
        }
        updateProcModel(cpuProcsModel, sys.cpu_procs, "cpu");
        updateProcModel(memProcsModel, sys.mem_procs, "ram");
        updateProcModel(gpuProcsModel, sys.gpu_procs, "gpu");
    }
    
    function updateProcModel(listModel, newArray, type) {
        if (!newArray) {
            listModel.clear();
            return;
        }
        
        var normalized = [];
        for (var i = 0; i < newArray.length; i++) {
            var p = newArray[i];
            var valText = "";
            if (type === "cpu") {
                valText = Math.round(p.cpu) + "%";
            } else if (type === "ram") {
                valText = Math.round(p.mem_mb) + "M";
            } else if (type === "gpu") {
                valText = (p.gpu > 0 ? (Math.round(p.gpu) + "% ") : "") + Math.round(p.vram_mb) + "M";
            }
            normalized.push({
                "pid": p.pid || 0,
                "name": p.name || "",
                "valueText": valText
            });
        }
        
        while (listModel.count > normalized.length) {
            listModel.remove(listModel.count - 1);
        }
        
        for (var idx = 0; idx < normalized.length; idx++) {
            var item = normalized[idx];
            if (idx >= listModel.count) {
                listModel.append(item);
            } else {
                var existing = listModel.get(idx);
                if (existing.name !== item.name) {
                    listModel.setProperty(idx, "name", item.name);
                }
                if (existing.pid !== item.pid) {
                    listModel.setProperty(idx, "pid", item.pid);
                }
                if (existing.valueText !== item.valueText) {
                    listModel.setProperty(idx, "valueText", item.valueText);
                }
            }
        }
    }
    
    // Formatting helper
    function formatTime(us) {
        if (!us || us < 0) return "0:00";
        var seconds = Math.floor(us / 1000000);
        var mins = Math.floor(seconds / 60);
        var secs = seconds % 60;
        return mins + ":" + secs.toString().padStart(2, '0');
    }

    // LYRICS STATE MANAGEMENT
    property var parsedLyrics: []
    property int trackDurationMs: 0
    property string lastLyricsTrackId: ""
    property int activeLyricIndex: -1
    property bool queueCollapsed: true
    property bool lyricsCollapsed: false
    readonly property bool lyricsAvailable: parsedLyrics.length > 0 && 
                                           parsedLyrics[0].text !== "Loading lyrics..." && 
                                           parsedLyrics[0].text !== "Lyrics not found" && 
                                           parsedLyrics[0].text !== "Instrumental / No lyrics available"
    
    // Check if the lyrics have actual timestamps (i.e. at least one line with time > 0)
    readonly property bool isLyricsSynced: {
        if (!parsedLyrics || parsedLyrics.length === 0) return false;
        for (var i = 0; i < parsedLyrics.length; i++) {
            if (parsedLyrics[i].time > 0) return true;
        }
        return false;
    }

    // Auto-collapse lyrics panel when lyrics become unavailable
    onLyricsAvailableChanged: {
        if (!lyricsAvailable && expandedMode === "lyrics") {
            expandedMode = "none";
        }
    }

    onExpandedModeChanged: {
        if (expandedMode === "lyrics" && activeLyricIndex !== -1) {
            lyricsListView.currentIndex = activeLyricIndex;
            lyricsListView.positionViewAtIndex(activeLyricIndex, ListView.Center);
        }
    }

    function parseTagMs(tag) {
        var match = /<(\d+):(\d+)(?:\.(\d+))?>/.exec(tag);
        if (!match) return 0;
        var mins = parseInt(match[1]);
        var secs = parseInt(match[2]);
        var ms = 0;
        if (match[3]) {
            var msStr = match[3].padEnd(3, '0').substring(0, 3);
            ms = parseInt(msStr);
        }
        return (mins * 60 + secs) * 1000 + ms;
    }

    function parseLRC(lrcText) {
        if (!lrcText) return [];
        var lines = lrcText.split("\n");
        var parsed = [];
        var timeRegex = /\[(\d+):(\d+)(?:\.(\d+))?\]/;
        var tagSplitRegex = /(<[^>]+>)/;
        
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim();
            if (!line) continue;
            var match = timeRegex.exec(line);
            if (match) {
                var mins = parseInt(match[1]);
                var secs = parseInt(match[2]);
                var ms = 0;
                if (match[3]) {
                    var msStr = match[3].padEnd(3, '0').substring(0, 3);
                    ms = parseInt(msStr);
                }
                var totalMs = (mins * 60 + secs) * 1000 + ms;
                var text = line.replace(timeRegex, "").trim();
                
                // Parse syllable timestamps if present
                var syllables = [];
                var parts = text.split(tagSplitRegex);
                if (parts.length > 1) {
                    if (parts[0].trim().length > 0 || parts.length > 2) {
                        syllables.push({ "time": totalMs, "text": parts[0] });
                    }
                    for (var k = 1; k < parts.length; k += 2) {
                        var tag = parts[k];
                        var wordText = parts[k + 1] || "";
                        var tagMs = root.parseTagMs(tag);
                        syllables.push({ "time": tagMs, "text": wordText });
                    }
                }
                
                parsed.push({ 
                    "time": totalMs, 
                    "text": text.replace(/<[^>]+>/g, ""), 
                    "syllables": syllables 
                });
            }
        }
        parsed.sort(function(a, b) { return a.time - b.time; });
        return parsed;
    }

    function getActiveLyricIndex(positionUs, lyricsArray) {
        if (!lyricsArray || lyricsArray.length === 0 || !root.isLyricsSynced) return -1;
        var positionMs = positionUs / 1000;
        var activeIdx = -1;
        for (var i = 0; i < lyricsArray.length; i++) {
            if (lyricsArray[i].time <= positionMs) {
                activeIdx = i;
            } else {
                break;
            }
        }
        return activeIdx;
    }

    function getFormattedLyric(idx, rawText) {
        if (!rawText) return "";
        if (!root.parsedLyrics[idx]) return rawText;
        
        var lyric = root.parsedLyrics[idx];
        
        if (idx !== root.activeLyricIndex || !spotify || spotify.position === undefined) {
            return lyric.text;
        }
        
        // It's the active line!
        // Case 1: Standard line (no syllable timestamps)
        if (!lyric.syllables || lyric.syllables.length === 0) {
            return "<font color='#0070D8'><b>" + lyric.text + "</b></font>";
        }
        
        // Case 2: Enhanced line (has syllable timestamps)
        var syllables = lyric.syllables;
        var currentMs = spotify.position / 1000.0;
        
        // Find which syllable is active
        var activeSyllableIdx = -1;
        for (var i = 0; i < syllables.length; i++) {
            if (syllables[i].time <= currentMs) {
                activeSyllableIdx = i;
            } else {
                break;
            }
        }
        if (activeSyllableIdx === -1) activeSyllableIdx = 0;
        
        // Build the rich text
        var formatted = "";
        for (var j = 0; j < syllables.length; j++) {
            if (j === activeSyllableIdx) {
                // Highlight active syllable in system blue and bold
                formatted += "<font color='#0070D8'><b>" + syllables[j].text + "</b></font>";
            } else {
                formatted += syllables[j].text;
            }
        }
        return formatted;
    }

    function cleanSongTitle(title) {
        if (!title) return "";
        return title.replace(/\s*[\(\[][fF]eat\..*?[\)\]]/g, "")
                    .replace(/\s*[\(\[][wW]ith\..*?[\)\]]/g, "")
                    .replace(/\s*[\(\[][oO]fficial.*?[\)\]]/g, "")
                    .replace(/\s*[\(\[][rR]adio\s*[eE]dit.*?[\)\]]/g, "")
                    .replace(/\s*-\s*[rR]adio\s*[eE]dit.*/gi, "")
                    .replace(/\s*-\s*[0-9]{4}\s*Remaster.*/gi, "")
                    .replace(/\s*-\s*Remaster.*/gi, "")
                    .replace(/\s*[\(\[].*?Remaster.*?[\)\]]/gi, "")
                    .trim();
    }

    function getPrimaryArtist(artist) {
        if (!artist) return "";
        var parts = artist.split(/[,/&]|(?:\s+feat\.?\s+)|(?:\s+ft\.?\s+)/i);
        return parts.length > 0 ? parts[0].trim() : artist.trim();
    }

    function isSongMatch(item, rawArtist, rawTitle, durationSec) {
        if (!item) return false;
        var itemTrack = (item.trackName || item.name || "").toLowerCase().trim();
        var itemArtist = (item.artistName || "").toLowerCase().trim();
        
        var cleanTargetTrack = root.cleanSongTitle(rawTitle).toLowerCase().trim();
        var cleanItemTrack = root.cleanSongTitle(itemTrack).toLowerCase().trim();
        
        var primaryTargetArtist = root.getPrimaryArtist(rawArtist).toLowerCase().trim();
        var primaryItemArtist = root.getPrimaryArtist(itemArtist).toLowerCase().trim();
        var fullTargetArtist = (rawArtist || "").toLowerCase().trim();
        var fullItemArtist = (itemArtist || "").toLowerCase().trim();
        
        // 1. Track Match
        var trackMatches = (cleanItemTrack === cleanTargetTrack) ||
                           (cleanItemTrack.indexOf(cleanTargetTrack) !== -1) ||
                           (cleanTargetTrack.indexOf(cleanItemTrack) !== -1);
        if (!trackMatches) return false;
        
        // 2. Artist Match
        var artistMatches = (primaryItemArtist.length > 0 && fullTargetArtist.indexOf(primaryItemArtist) !== -1) ||
                            (primaryTargetArtist.length > 0 && fullItemArtist.indexOf(primaryTargetArtist) !== -1) ||
                            (fullItemArtist.length > 0 && fullTargetArtist.indexOf(fullItemArtist) !== -1) ||
                            (fullTargetArtist.length > 0 && fullItemArtist.indexOf(fullTargetArtist) !== -1);
        if (!artistMatches) return false;
        
        // 3. Duration match
        var itemDur = item.duration || 0;
        if (durationSec > 0 && itemDur > 0) {
            var diff = Math.abs(itemDur - durationSec);
            if (diff > 18) {
                if (cleanItemTrack !== cleanTargetTrack || primaryItemArtist !== primaryTargetArtist) {
                    return false;
                }
            }
        }
        return true;
    }

    property string currentTrackId: spotify ? (spotify.title + " - " + spotify.artist) : ""
    onCurrentTrackIdChanged: fetchLyrics()

    function processLrcResponse(res) {
        if (!res) return false;
        var ok = false;
        if (res.syncedLyrics) {
            parsedLyrics = parseLRC(res.syncedLyrics);
            ok = true;
        } else if (res.plainLyrics) {
            var lines = res.plainLyrics.split("\n");
            var flat = [];
            for (var i = 0; i < lines.length; i++) {
                flat.push({ "time": 0, "text": lines[i].trim() });
            }
            parsedLyrics = flat;
            ok = true;
        } else if (res.instrumental) {
            parsedLyrics = [{"time": 0, "text": "Instrumental / No lyrics available"}];
            ok = true;
        }
        if (ok) {
            var dur = 0;
            if (res.duration) {
                dur = res.duration * 1000;
            } else if (parsedLyrics.length > 0) {
                var lastTime = 0;
                for (var j = parsedLyrics.length - 1; j >= 0; j--) {
                    if (parsedLyrics[j].time > 0) {
                        lastTime = parsedLyrics[j].time;
                        break;
                    }
                }
                if (lastTime > 0) {
                    dur = lastTime + 5000;
                }
            }
            root.trackDurationMs = dur;
        }
        return ok;
    }

    function fetchLyrics() {
        if (!spotify || !spotify.title || spotify.title === "" || spotify.status === "Stopped") {
            parsedLyrics = [];
            lastLyricsTrackId = "";
            activeLyricIndex = -1;
            return;
        }
        
        if (spotify.title === "Advertisement" || spotify.title === "Reklama" || spotify.title === "Ad Break" || spotify.title === "Ad") {
            parsedLyrics = [{"time": 0, "text": "Ad Break / Reklama"}];
            lastLyricsTrackId = spotify.title;
            activeLyricIndex = 0;
            return;
        }
        
        var trackId = spotify.title + " - " + spotify.artist;
        if (trackId === lastLyricsTrackId) return;
        lastLyricsTrackId = trackId;
        parsedLyrics = [{"time": 0, "text": "Loading lyrics..."}];
        trackDurationMs = 0;
        activeLyricIndex = -1;
        
        var currentFetchId = trackId;
        var rawArtist = spotify.artist || "";
        var rawTitle = spotify.title || "";
        var cleanTitle = root.cleanSongTitle(rawTitle);
        var primaryArtist = root.getPrimaryArtist(rawArtist);
        var durationSec = (spotify.length && spotify.length > 0) ? Math.round(spotify.length / 1000000) : 0;
        
        var searchUrls = [];
        searchUrls.push("https://lrclib.net/api/search?artist_name=" + encodeURIComponent(rawArtist) + "&track_name=" + encodeURIComponent(cleanTitle));
        if (primaryArtist !== rawArtist) {
            searchUrls.push("https://lrclib.net/api/search?artist_name=" + encodeURIComponent(primaryArtist) + "&track_name=" + encodeURIComponent(cleanTitle));
        }
        searchUrls.push("https://lrclib.net/api/search?q=" + encodeURIComponent(primaryArtist + " " + cleanTitle));
        if (rawTitle !== cleanTitle) {
            searchUrls.push("https://lrclib.net/api/search?q=" + encodeURIComponent(rawArtist + " " + rawTitle));
        }
        
        var uniqueSearchUrls = [];
        for (var u = 0; u < searchUrls.length; u++) {
            if (uniqueSearchUrls.indexOf(searchUrls[u]) === -1) {
                uniqueSearchUrls.push(searchUrls[u]);
            }
        }
        
        var fallbackCandidate = null;
        
        function trySearchStep(stepIndex) {
            if (currentFetchId !== root.lastLyricsTrackId) return;
            if (stepIndex >= uniqueSearchUrls.length) {
                if (fallbackCandidate) {
                    root.processLrcResponse(fallbackCandidate);
                } else {
                    root.parsedLyrics = [{"time": 0, "text": "Lyrics not found"}];
                }
                return;
            }
            
            var sUrl = uniqueSearchUrls[stepIndex];
            var xhr = new XMLHttpRequest();
            xhr.open("GET", sUrl, true);
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (currentFetchId !== root.lastLyricsTrackId) return;
                    if (xhr.status === 200) {
                        try {
                            var items = JSON.parse(xhr.responseText);
                            if (items && items.length > 0) {
                                for (var i = 0; i < items.length; i++) {
                                    if (root.isSongMatch(items[i], rawArtist, rawTitle, durationSec)) {
                                        if (items[i].syncedLyrics && items[i].syncedLyrics.trim().length > 0) {
                                            root.processLrcResponse(items[i]);
                                            return;
                                        }
                                    }
                                }
                                if (!fallbackCandidate) {
                                    for (var j = 0; j < items.length; j++) {
                                        if (root.isSongMatch(items[j], rawArtist, rawTitle, durationSec)) {
                                            if (items[j].plainLyrics || items[j].instrumental) {
                                                fallbackCandidate = items[j];
                                                break;
                                            }
                                        }
                                    }
                                }
                            }
                        } catch (e) {}
                    }
                    trySearchStep(stepIndex + 1);
                }
            };
            xhr.send();
        }
        
        var getUrl = "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(rawArtist) + 
                     "&track_name=" + encodeURIComponent(rawTitle);
        if (durationSec > 0) {
            getUrl += "&duration=" + durationSec;
        }
        
        var getXhr = new XMLHttpRequest();
        getXhr.open("GET", getUrl, true);
        getXhr.onreadystatechange = function() {
            if (getXhr.readyState === XMLHttpRequest.DONE) {
                if (currentFetchId !== root.lastLyricsTrackId) return;
                if (getXhr.status === 200) {
                    try {
                        var res = JSON.parse(getXhr.responseText);
                        if (res && root.isSongMatch(res, rawArtist, rawTitle, durationSec)) {
                            if (res.syncedLyrics && res.syncedLyrics.trim().length > 0) {
                                root.processLrcResponse(res);
                                return;
                            } else if (res.plainLyrics || res.instrumental) {
                                fallbackCandidate = res;
                            }
                        }
                    } catch (e) {}
                }
                trySearchStep(0);
            }
        };
        getXhr.send();
    }

    onSpotifyChanged: {
        if (spotify && spotify.position !== undefined) {
            var idx = getActiveLyricIndex(spotify.position, parsedLyrics);
            if (idx !== activeLyricIndex) {
                activeLyricIndex = idx;
                if (root.expandedMode === "lyrics" && idx !== -1) {
                    lyricsListView.currentIndex = idx;
                    lyricsListView.positionViewAtIndex(idx, ListView.Center);
                }
            }
        }
    }

    // Fast lyric position poll — runs every 250ms when playing, reads position from daemon data
    Timer {
        id: lyricSyncTimer
        interval: 250
        running: spotify !== null && spotify.status === "Playing"
        repeat: true
        onTriggered: {
            if (!spotify || spotify.status !== "Playing" || !root.parsedLyrics || root.parsedLyrics.length === 0) return;
            var idx = root.getActiveLyricIndex(spotify.position, root.parsedLyrics);
            if (idx !== root.activeLyricIndex) {
                root.activeLyricIndex = idx;
                if (root.expandedMode === "lyrics" && idx !== -1) {
                    lyricsListView.currentIndex = idx;
                    lyricsListView.positionViewAtIndex(idx, ListView.Center);
                }
            }
        }
    }


    // WEATHER STATE MANAGEMENT (Fetched in QML)
    property bool dashboardOpen: false
    property string expandedMode: "none"
    readonly property real targetHeight: {
        if (root.expandedMode === "none") return 404;
        if (root.expandedMode === "weather") return 554;
        if (root.expandedMode === "system") return 674;
        // lyrics mode: dynamic height based on lyrics availability and queue
        var base = 524;
        if (root.parsedLyrics.length > 0) {
            if (!root.lyricsAvailable) {
                base -= 240; // 270px - 30px
            }
        } else {
            base -= 270;
        }
        if (spotify && spotify.queue && spotify.queue.length > 0) {
            base += root.queueCollapsed ? 30 : Math.min(spotify.queue.length * 22 + 50, 160);
        }
        return base;
    }
    property string weatherCity: "" // Set to your city name to override (e.g. "Warsaw"), or leave empty for IP auto-detection
    property string weatherTemp: "--"
    property string weatherDesc: "Loading..."
    property string weatherIcon: "󰖐"
    property string weatherLocation: ""
    property string weatherHumidity: "--"
    property string weatherWind: "--"
    property string weatherUV: "--"
    property var weatherForecast: []
    
    function fetchWeather() {
        var xhr = new XMLHttpRequest();
        var url = "https://wttr.in/" + (root.weatherCity ? encodeURIComponent(root.weatherCity) : "") + "?format=j1";
        xhr.open("GET", url, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        var current = res.current_condition[0];
                        root.weatherTemp = current.temp_C + "°C";
                        root.weatherDesc = current.weatherDesc[0].value;
                        root.weatherHumidity = (current.humidity || "--") + "%";
                        root.weatherWind = (current.windspeedKmph || "--") + " km/h";
                        root.weatherUV = current.uvIndex || "--";
                        
                        if (res.nearest_area && res.nearest_area[0] && res.nearest_area[0].areaName && res.nearest_area[0].areaName[0]) {
                            root.weatherLocation = res.nearest_area[0].areaName[0].value;
                        } else {
                            root.weatherLocation = "";
                        }
                        
                        // Parse weather code into Nerd Font icons
                        var code = intValue(current.weatherCode);
                        root.weatherIcon = root.resolveWeatherIcon(code);
                        
                        // Parse 3-day forecast
                        var forecastData = [];
                        if (res.weather && res.weather.length >= 3) {
                            for (var i = 0; i < 3; i++) {
                                var day = res.weather[i];
                                var displayDate = day.date;
                                try {
                                    var parts = day.date.split("-");
                                    if (parts.length === 3) {
                                        var d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
                                        var daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
                                        displayDate = daysOfWeek[d.getDay()];
                                    }
                                } catch(err) {}
                                
                                var middayCode = 113;
                                var middayDesc = "Sunny";
                                if (day.hourly && day.hourly.length > 0) {
                                    var midIdx = Math.floor(day.hourly.length / 2);
                                    if (day.hourly[midIdx]) {
                                        middayCode = root.intValue(day.hourly[midIdx].weatherCode);
                                        middayDesc = day.hourly[midIdx].weatherDesc[0].value;
                                    }
                                }
                                
                                forecastData.push({
                                    "date": displayDate,
                                    "temp": day.mintempC + "°-" + day.maxtempC + "°C",
                                    "icon": root.resolveWeatherIcon(middayCode),
                                    "desc": middayDesc
                                });
                            }
                        }
                        root.weatherForecast = forecastData;
                    } catch (e) {
                        root.weatherDesc = "Error parsing weather";
                    }
                } else {
                    root.weatherDesc = "Weather offline";
                }
            }
        }
        xhr.send();
    }
    
    function intValue(str) {
        var val = parseInt(str);
        return isNaN(val) ? 113 : val;
    }
    
    function resolveWeatherIcon(code) {
        // Simple mapping from WWO code to Nerd Font weather icons
        if (code === 113) return "󰖙"; // Sunny
        if (code === 116) return "󰖕"; // Partly Cloudy
        if ([119, 122].indexOf(code) !== -1) return "󰖐"; // Cloudy
        if ([143, 248, 260].indexOf(code) !== -1) return "󰖑"; // Foggy
        if ([176, 263, 266, 293, 296, 299, 302, 353, 356].indexOf(code) !== -1) return "󰖗"; // Light Rain
        if ([305, 308, 359, 362].indexOf(code) !== -1) return "󰖖"; // Heavy Rain
        if ([200, 386, 389, 392].indexOf(code) !== -1) return "󰙾"; // Thunder
        if ([179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 365, 368, 371, 395].indexOf(code) !== -1) return "󰼶"; // Snow
        return "󰖐";
    }
    
    Timer {
        interval: 1800000 // Refresh every 30 minutes
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchWeather()
    }
    
    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 14
        spacing: 12
        
        height: root.targetHeight
        Behavior on height { 
            enabled: root.dashboardOpen
            NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } 
        }
        
        // 1. Spotify Player
        Rectangle {
            Layout.fillWidth: true
            // Height: base (150) + lyrics when expanded + queue when expanded and not collapsed
            Layout.preferredHeight: {
                var h = 150;
                if (root.expandedMode === "lyrics") {
                    if (root.parsedLyrics.length > 0) {
                        h += root.lyricsAvailable ? 270 : 30;
                    }
                    if (spotify && spotify.queue && spotify.queue.length > 0) {
                        h += root.queueCollapsed ? 30 : Math.min(spotify.queue.length * 22 + 50, 160);
                    }
                }
                return h;
            }
            Behavior on Layout.preferredHeight {
                enabled: root.dashboardOpen
                NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
            }
            color: "#0DFFFFFF"
            radius: 8
            border.color: "#1AFFFFFF"
            border.width: 1
            clip: true
            
            // Background click area to toggle lyrics expansion mode (excluding lyrics list)
            MouseArea {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 150
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.expandedMode = (root.expandedMode === "lyrics") ? "none" : "lyrics"
                }
            }
            
            // Allow wheel volume control anywhere on the player card (excluding lyrics list)
            MouseArea {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 150
                acceptedButtons: Qt.NoButton
                onWheel: (event) => {
                    if (event.angleDelta.y > 0) {
                        Quickshell.execDetached(["/home/tymon/dotfiles/.config/quickshell/scripts/player_control.py", "volume", "0.05+"]);
                    } else if (event.angleDelta.y < 0) {
                        Quickshell.execDetached(["/home/tymon/dotfiles/.config/quickshell/scripts/player_control.py", "volume", "0.05-"]);
                    }
                }
            }
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 126
                    spacing: 12
                    
                    // Album art
                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 80
                        color: "#0DFFFFFF"
                        radius: 6
                        Layout.alignment: Qt.AlignVCenter
                        
                        Image {
                            id: albumArt
                            source: spotify && spotify.artUrl ? spotify.artUrl : ""
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            visible: spotify && spotify.artUrl !== ""
                        }
                        
                        Text {
                            text: "󰓇"
                            font.family: root.customFont
                            font.pixelSize: 32
                            color: "#33FFFFFF"
                            anchors.centerIn: parent
                            visible: !albumArt.visible
                        }
                    }
                    
                    // Track title, artist, seekbar & controls
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        
                        // Scrolling song title
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 16
                            clip: true

                            Text {
                                id: titleText
                                text: spotify && spotify.title ? spotify.title : "Not Playing"
                                font.family: root.customFont
                                font.pixelSize: 12
                                font.bold: true
                                color: "#FFFFFF"
                                width: implicitWidth

                                NumberAnimation on x {
                                    id: titleScrollAnim
                                    running: root.dashboardOpen && (titleText.implicitWidth > titleText.parent.width)
                                    from: 0
                                    to: -(titleText.implicitWidth - titleText.parent.width + 12)
                                    duration: Math.max(2000, (titleText.implicitWidth - titleText.parent.width) * 18)
                                    loops: Animation.Infinite
                                    onRunningChanged: {
                                        if (!running) titleText.x = 0;
                                    }
                                }
                            }
                            onWidthChanged: titleScrollAnim.restart()
                        }

                        // Scrolling artist name
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 14
                            clip: true

                            Text {
                                id: artistText
                                text: spotify && spotify.artist ? spotify.artist : "Unknown Artist"
                                font.family: root.customFont
                                font.pixelSize: 10
                                color: "#99FFFFFF"
                                width: implicitWidth

                                NumberAnimation on x {
                                    id: artistScrollAnim
                                    running: root.dashboardOpen && (artistText.implicitWidth > artistText.parent.width)
                                    from: 0
                                    to: -(artistText.implicitWidth - artistText.parent.width + 12)
                                    duration: Math.max(2000, (artistText.implicitWidth - artistText.parent.width) * 20)
                                    loops: Animation.Infinite
                                    onRunningChanged: {
                                        if (!running) artistText.x = 0;
                                    }
                                }
                            }
                            onWidthChanged: artistScrollAnim.restart()
                        }

                        // Context name (playlist/album)
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12
                            clip: true
                            visible: spotify && spotify.contextName && spotify.contextName !== ""

                            Text {
                                id: contextText
                                text: spotify ? spotify.contextName : ""
                                font.family: root.customFont
                                font.pixelSize: 8
                                font.italic: true
                                color: "#0070D8"
                                width: implicitWidth

                                NumberAnimation on x {
                                    id: contextScrollAnim
                                    running: root.dashboardOpen && (contextText.implicitWidth > contextText.parent.width)
                                    from: 0
                                    to: -(contextText.implicitWidth - contextText.parent.width + 12)
                                    duration: Math.max(2000, (contextText.implicitWidth - contextText.parent.width) * 20)
                                    loops: Animation.Infinite
                                    onRunningChanged: {
                                        if (!running) contextText.x = 0;
                                    }
                                }
                            }
                            onWidthChanged: contextScrollAnim.restart()
                        }
                        
                        // Single-line synced lyric (ONLY visible when collapsed)
                        Text {
                            id: singleLineLyric
                            visible: root.expandedMode !== "lyrics" && text !== ""
                            text: {
                                if (!spotify || spotify.status === "Stopped") return "";
                                var idx = root.activeLyricIndex;
                                if (idx !== -1 && root.parsedLyrics[idx]) {
                                    return root.parsedLyrics[idx].text;
                                }
                                return "";
                            }
                            font.family: root.customFont
                            font.pixelSize: 9
                            font.italic: true
                            color: "#0070D8" // Beautiful system blue to draw focus
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            
                            Behavior on text {
                                SequentialAnimation {
                                    NumberAnimation { target: singleLineLyric; property: "opacity"; to: 0; duration: 100 }
                                    PropertyAction { target: singleLineLyric; property: "text" }
                                    NumberAnimation { target: singleLineLyric; property: "opacity"; to: 1; duration: 150 }
                                }
                            }
                        }
                        
                        // Seekbar slider
                        Slider {
                            id: seekSlider
                            visible: spotify && (spotify.length > 0 || root.trackDurationMs > 0)
                            Layout.fillWidth: true
                            Layout.preferredHeight: 14
                            leftPadding: 0
                            rightPadding: 0
                            topPadding: 0
                            bottomPadding: 0
                            from: 0
                            to: (spotify && spotify.length) ? spotify.length : (root.trackDurationMs * 1000)
                            value: spotify && spotify.position ? spotify.position : 0
                            live: false
                            
                            background: Rectangle {
                                x: seekSlider.leftPadding
                                y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                                width: seekSlider.availableWidth
                                height: 4
                                radius: 2
                                color: "#1AFFFFFF"
                                
                                Rectangle {
                                    width: seekSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: "#0070D8"
                                    radius: 2
                                }
                            }
                            
                            handle: Rectangle {
                                x: seekSlider.leftPadding + seekSlider.visualPosition * (seekSlider.availableWidth - width)
                                y: seekSlider.topPadding + seekSlider.availableHeight / 2 - height / 2
                                width: (seekSlider.hovered || seekSlider.pressed) ? 12 : 8
                                height: (seekSlider.hovered || seekSlider.pressed) ? 12 : 8
                                radius: width / 2
                                color: seekSlider.pressed ? "#0070D8" : ((seekSlider.hovered) ? "#3399FF" : "#FFFFFF")
                                
                                Behavior on width { NumberAnimation { duration: 150 } }
                                Behavior on height { NumberAnimation { duration: 150 } }
                            }
                            
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.NoButton
                            }
                            
                            onPressedChanged: {
                                if (!pressed) {
                                    var posSec = value / 1000000;
                                    Quickshell.execDetached(["/home/tymon/dotfiles/.config/quickshell/scripts/player_control.py", "position", posSec.toString()]);
                                }
                            }
                        }
                        
                        // Elapsed/Total/Volume duration labels
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: root.formatTime(spotify ? spotify.position : 0)
                                font.family: root.customFont
                                font.pixelSize: 9
                                color: "#99FFFFFF"
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Text {
                                property double vol: spotify && spotify.volume !== undefined ? spotify.volume : 0.5
                                text: {
                                    var iconStr = "";
                                    if (vol <= 0.01) iconStr = "";
                                    else if (vol < 0.33) iconStr = "";
                                    return iconStr + " " + Math.round(vol * 100) + "%";
                                }
                                font.family: root.customFont
                                font.pixelSize: 9
                                color: "#99FFFFFF"
                            }
                            
                            Item { Layout.fillWidth: true }
                            
                            Text {
                                text: (spotify && spotify.length > 0) ? root.formatTime(spotify.length) : (root.trackDurationMs > 0 ? root.formatTime(root.trackDurationMs * 1000) : (spotify && spotify.playerName === "mpv" ? "LIVE" : "0:00"))
                                font.family: root.customFont
                                font.pixelSize: 9
                                color: "#99FFFFFF"
                            }
                        }
                        
                        // Control buttons row
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 14
                            
                            Button {
                                id: shuffleBtn
                                enabled: spotify && spotify.playerName !== "mpv"
                                opacity: enabled ? 1.0 : 0.35
                                text: spotify && spotify.shuffle ? "󰒟" : "󰒞"
                                font.family: root.customFont
                                font.pixelSize: 12
                                flat: true
                                implicitWidth: 24
                                implicitHeight: 22
                                topPadding: 0
                                bottomPadding: 0
                                leftPadding: 0
                                rightPadding: 0
                                background: null
                                onClicked: Quickshell.execDetached(["/home/tymon/dotfiles/.config/quickshell/scripts/player_control.py", "shuffle", "Toggle"])
                                contentItem: Text { 
                                    text: shuffleBtn.text
                                    font: shuffleBtn.font
                                    color: shuffleBtn.hovered ? (spotify && spotify.shuffle ? "#3399FF" : "#FFFFFF") : (spotify && spotify.shuffle ? "#0070D8" : "#99FFFFFF")
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                            
                            Button {
                                id: prevBtn
                                text: "⏮"
                                font.family: root.customFont
                                font.pixelSize: 12
                                flat: true
                                implicitWidth: 24
                                implicitHeight: 22
                                topPadding: 0
                                bottomPadding: 0
                                leftPadding: 0
                                rightPadding: 0
                                background: null
                                onClicked: Quickshell.execDetached(["/home/tymon/dotfiles/.config/quickshell/scripts/player_control.py", "previous"])
                                contentItem: Text { 
                                    text: prevBtn.text
                                    font: prevBtn.font
                                    color: prevBtn.hovered ? "#0070D8" : "#FFFFFF"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                            
                            Button {
                                id: playBtn
                                text: spotify && spotify.status === "Playing" ? "⏸" : "▶"
                                font.family: root.customFont
                                font.pixelSize: 16
                                flat: true
                                implicitWidth: 24
                                implicitHeight: 22
                                topPadding: 0
                                bottomPadding: 0
                                leftPadding: 0
                                rightPadding: 0
                                background: null
                                onClicked: Quickshell.execDetached(["/home/tymon/dotfiles/.config/quickshell/scripts/player_control.py", "play-pause"])
                                contentItem: Text { 
                                    text: playBtn.text
                                    font: playBtn.font
                                    color: playBtn.hovered ? "#3399FF" : "#0070D8"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                            
                            Button {
                                id: nextBtn
                                text: "⏭"
                                font.family: root.customFont
                                font.pixelSize: 12
                                flat: true
                                implicitWidth: 24
                                implicitHeight: 22
                                topPadding: 0
                                bottomPadding: 0
                                leftPadding: 0
                                rightPadding: 0
                                background: null
                                onClicked: Quickshell.execDetached(["/home/tymon/dotfiles/.config/quickshell/scripts/player_control.py", "next"])
                                contentItem: Text { 
                                    text: nextBtn.text
                                    font: nextBtn.font
                                    color: nextBtn.hovered ? "#0070D8" : "#FFFFFF"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                            
                            Button {
                                id: loopBtn
                                enabled: spotify && spotify.playerName !== "mpv"
                                opacity: enabled ? 1.0 : 0.35
                                text: spotify && spotify.loop === "Track" ? "󰑘" : (spotify && spotify.loop === "Playlist" ? "󰑖" : "󰑗")
                                font.family: root.customFont
                                font.pixelSize: 12
                                flat: true
                                implicitWidth: 24
                                implicitHeight: 22
                                topPadding: 0
                                bottomPadding: 0
                                leftPadding: 0
                                rightPadding: 0
                                background: null
                                onClicked: Quickshell.execDetached(["/home/tymon/dotfiles/.config/quickshell/scripts/player_control.py", "loop", "Toggle"])
                                contentItem: Text { 
                                    text: loopBtn.text
                                    font: loopBtn.font
                                    color: loopBtn.hovered ? (spotify && spotify.loop !== "Off" ? "#3399FF" : "#FFFFFF") : (spotify && spotify.loop !== "Off" ? "#0070D8" : "#99FFFFFF")
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.NoButton
                                }
                            }

                            Button {
                                id: sourceBtn
                                text: spotify && spotify.playerName === "mpv" ? "󰎖" : "󰓇"
                                font.family: root.customFont
                                font.pixelSize: 12
                                flat: true
                                implicitWidth: 24
                                implicitHeight: 22
                                topPadding: 0
                                bottomPadding: 0
                                leftPadding: 0
                                rightPadding: 0
                                background: null
                                onClicked: Quickshell.execDetached(["/home/tymon/dotfiles/.config/quickshell/scripts/player_control.py", "toggle-source"])
                                contentItem: Text { 
                                    text: sourceBtn.text
                                    font: sourceBtn.font
                                    color: sourceBtn.hovered ? "#3399FF" : (spotify && spotify.playerName === "mpv" ? "#FF9900" : "#1DB954")
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                        }
                    }
                }
                
                // Full Synced Lyrics Area (visible only when expanded)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: root.expandedMode === "lyrics"
                    spacing: 0

                    // Lyrics List View
                    ListView {
                        id: lyricsListView
                        Layout.fillWidth: true
                        Layout.preferredHeight: {
                            if (root.parsedLyrics.length === 0) return 0;
                            return root.lyricsAvailable ? 270 : 30;
                        }
                        Layout.topMargin: 4
                        Layout.bottomMargin: 4
                        model: root.parsedLyrics
                        spacing: 8
                        clip: true

                        preferredHighlightBegin: height / 2 - 12
                        preferredHighlightEnd: height / 2 + 12
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        highlightFollowsCurrentItem: true
                        highlightMoveDuration: 350
                        highlightMoveVelocity: -1
                        highlight: Item {}

                        delegate: Item {
                            width: lyricsListView.width
                            height: Math.max(20, lyricText.implicitHeight * lyricText.scale)

                            Text {
                                id: lyricText
                                width: parent.width - 80
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.getFormattedLyric(index, modelData.text)
                                textFormat: Text.StyledText
                                font.family: root.customFont
                                font.pixelSize: 9
                                font.bold: index === root.activeLyricIndex
                                color: index === root.activeLyricIndex ? "#FFFFFF" : "#80FFFFFF"
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                scale: index === root.activeLyricIndex ? 1.12 : 1.0
                                transformOrigin: Item.Center

                                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.time !== undefined && modelData.time !== null && root.isLyricsSynced) {
                                        var posSec = modelData.time / 1000.0;
                                        Quickshell.execDetached(["/home/tymon/dotfiles/.config/quickshell/scripts/player_control.py", "position", posSec.toString()]);
                                    }
                                }
                            }
                        }
                    }

                    // Separator before queue
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: "#14FFFFFF"
                        visible: spotify && spotify.queue && spotify.queue.length > 0
                    }

                    // Collapsible Up Next Queue (below lyrics)
                    ColumnLayout {
                        id: queueColumn
                        Layout.fillWidth: true
                        spacing: 4
                        Layout.topMargin: 6
                        visible: spotify && spotify.queue && spotify.queue.length > 0

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18

                            RowLayout {
                                anchors.fill: parent

                                Text {
                                    text: "UP NEXT"
                                    font.family: root.customFont
                                    font.pixelSize: 8
                                    font.bold: true
                                    color: "#0070D8"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: root.queueCollapsed ? "󰅀" : "󰅃"
                                    font.family: root.customFont
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#99FFFFFF"
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.queueCollapsed = !root.queueCollapsed
                            }
                        }

                        // Queue items list
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: !root.queueCollapsed

                            Repeater {
                                model: spotify ? spotify.queue : []

                                delegate: RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 18
                                    spacing: 8

                                    // Mini art
                                    Rectangle {
                                        Layout.preferredWidth: 14
                                        Layout.preferredHeight: 14
                                        color: "#0DFFFFFF"
                                        radius: 2
                                        Layout.alignment: Qt.AlignVCenter

                                        Image {
                                            id: miniArt
                                            source: modelData.artUrl || ""
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            visible: modelData.artUrl !== ""
                                        }

                                        Text {
                                            text: "󰓇"
                                            font.family: root.customFont
                                            font.pixelSize: 6
                                            color: "#33FFFFFF"
                                            anchors.centerIn: parent
                                            visible: !miniArt.visible
                                        }
                                    }

                                    // Title & Artist
                                    Text {
                                        text: (modelData.title || "Unknown Track") + "   •   " + (modelData.artist || "Unknown Artist")
                                        font.family: root.customFont
                                        font.pixelSize: 8
                                        color: "#E6FFFFFF"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 2. Weather Card (Expandable on click)
        Rectangle {
            id: weatherCard
            Layout.fillWidth: true
            Layout.preferredHeight: root.expandedMode === "weather" ? 220 : 70
            Behavior on Layout.preferredHeight {
                enabled: root.dashboardOpen
                NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
            }
            color: "#0DFFFFFF"
            radius: 8
            border.color: "#1AFFFFFF"
            border.width: 1
            clip: true
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.expandedMode = (root.expandedMode === "weather") ? "none" : "weather"
                }
            }
            
            // Fixed 70px header row — always vertically centered regardless of expand state
            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 70

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Text {
                        text: root.weatherIcon
                        font.family: root.customFont
                        font.pixelSize: 24
                        color: "#0070D8"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                        spacing: 2
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            text: root.weatherTemp + (root.weatherLocation ? " (" + root.weatherLocation + ")" : "")
                            font.family: root.customFont
                            font.pixelSize: 12
                            font.bold: true
                            color: "#FFFFFF"
                        }
                        Text {
                            text: root.weatherDesc
                            font.family: root.customFont
                            font.pixelSize: 10
                            color: "#99FFFFFF"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.expandedMode === "weather" ? "󰅃" : "󰅀"
                        font.family: root.customFont
                        font.pixelSize: 12
                        color: "#66FFFFFF"
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }

            // Expanded detail section — sits directly below the 70px header
            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 70
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.bottomMargin: 12
                spacing: 10
                visible: root.expandedMode === "weather"

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#1AFFFFFF"
                }

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Humidity"; font.family: root.customFont; font.pixelSize: 8; color: "#99FFFFFF"; Layout.alignment: Qt.AlignHCenter }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Text { text: "󰖏"; font.family: root.customFont; font.pixelSize: 10; color: "#0070D8" }
                            Text { text: root.weatherHumidity; font.family: root.customFont; font.pixelSize: 10; color: "#FFFFFF"; font.bold: true }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Wind"; font.family: root.customFont; font.pixelSize: 8; color: "#99FFFFFF"; Layout.alignment: Qt.AlignHCenter }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Text { text: "󰖝"; font.family: root.customFont; font.pixelSize: 10; color: "#0070D8" }
                            Text { text: root.weatherWind; font.family: root.customFont; font.pixelSize: 10; color: "#FFFFFF"; font.bold: true }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "UV Index"; font.family: root.customFont; font.pixelSize: 8; color: "#99FFFFFF"; Layout.alignment: Qt.AlignHCenter }
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Text { text: "󰖙"; font.family: root.customFont; font.pixelSize: 10; color: "#0070D8" }
                            Text { text: root.weatherUV; font.family: root.customFont; font.pixelSize: 10; color: "#FFFFFF"; font.bold: true }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#1AFFFFFF"
                }

                // 3-Day Forecast Cards
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: root.weatherForecast

                        delegate: Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 85
                            color: "#0DFFFFFF"
                            radius: 6
                            border.color: "#1AFFFFFF"
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 3

                                Text {
                                    text: modelData.date
                                    font.family: root.customFont
                                    font.pixelSize: 9
                                    font.bold: true
                                    color: "#FFFFFF"
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: modelData.icon
                                    font.family: root.customFont
                                    font.pixelSize: 18
                                    color: "#0070D8"
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: modelData.temp
                                    font.family: root.customFont
                                    font.pixelSize: 8
                                    color: "#E6FFFFFF"
                                    Layout.alignment: Qt.AlignHCenter
                                }

                                Text {
                                    text: modelData.desc
                                    font.family: root.customFont
                                    font.pixelSize: 7
                                    color: "#99FFFFFF"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 3. Detailed System Monitor Stats
        Rectangle {
            id: systemCard
            Layout.fillWidth: true
            Layout.preferredHeight: root.expandedMode === "system" ? 430 : 160
            Behavior on Layout.preferredHeight {
                enabled: root.dashboardOpen
                NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
            }
            color: "#0DFFFFFF"
            radius: 8
            border.color: "#1AFFFFFF"
            border.width: 1
            clip: true
            
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.expandedMode = (root.expandedMode === "system") ? "none" : "system"
                }
            }

            // Fixed-height always-visible content — anchored to top, no stretch
            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 8

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "System Information"
                        font.family: root.customFont
                        font.pixelSize: 11
                        font.bold: true
                        color: "#0070D8"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.expandedMode === "system" ? "󰅃" : "󰅀"
                        font.family: root.customFont
                        font.pixelSize: 12
                        color: "#66FFFFFF"
                    }
                }

                // CPU Bar
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Text { text: "CPU Usage"; font.family: root.customFont; font.pixelSize: 10; color: "#99FFFFFF" }
                        Item { Layout.fillWidth: true }
                        Text { text: Math.round(sys ? sys.cpu : 0) + "%"; font.family: root.customFont; font.pixelSize: 10; color: "#FFFFFF"; font.bold: true }
                    }
                    ProgressBar {
                        id: cpuBar
                        Layout.fillWidth: true
                        value: sys ? sys.cpu / 100.0 : 0
                        implicitHeight: 6
                        background: Rectangle { color: "#1AFFFFFF"; radius: 3 }
                        contentItem: Item {
                            Rectangle {
                                width: cpuBar.visualPosition * parent.width
                                height: parent.height
                                radius: 3
                                color: "#0070D8"
                            }
                        }
                    }
                }

                // RAM Bar
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Text { text: "RAM Usage"; font.family: root.customFont; font.pixelSize: 10; color: "#99FFFFFF" }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: {
                                var pct = Math.round(sys ? sys.ram : 0);
                                if (!sys) return pct + "%";
                                var ramUsed = sys.ram_used_gib ? sys.ram_used_gib.toFixed(1) : "0.0";
                                var ramTotal = sys.ram_total_gib ? sys.ram_total_gib.toFixed(1) : "0.0";
                                var swapUsed = sys.swap_used_gib ? sys.swap_used_gib.toFixed(1) : "0.0";
                                var swapTotal = sys.swap_total_gib ? sys.swap_total_gib.toFixed(1) : "0.0";
                                return pct + "% (" + ramUsed + "/" + ramTotal + "GB | Swap: " + swapUsed + "/" + swapTotal + "GB)";
                            }
                            font.family: root.customFont; font.pixelSize: 10; color: "#FFFFFF"; font.bold: true
                        }
                    }
                    ProgressBar {
                        id: ramBar
                        Layout.fillWidth: true
                        value: sys ? sys.ram / 100.0 : 0
                        implicitHeight: 6
                        background: Rectangle { color: "#1AFFFFFF"; radius: 3 }
                        contentItem: Item {
                            Rectangle {
                                width: ramBar.visualPosition * parent.width
                                height: parent.height
                                radius: 3
                                color: "#0070D8"
                            }
                        }
                    }
                }

                // GPU & VRAM Bar
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Text { text: "GPU Usage"; font.family: root.customFont; font.pixelSize: 10; color: "#99FFFFFF" }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Math.round(sys ? sys.gpu : 0) + "% (VRAM: " + (sys ? sys.vram_used_gib.toFixed(1) : "0") + "/" + (sys ? sys.vram_total_gib.toFixed(1) : "0") + "GB)";
                            font.family: root.customFont; font.pixelSize: 10; color: "#FFFFFF"; font.bold: true
                        }
                    }
                    ProgressBar {
                        id: gpuBar
                        Layout.fillWidth: true
                        value: sys ? sys.gpu / 100.0 : 0
                        implicitHeight: 6
                        background: Rectangle { color: "#1AFFFFFF"; radius: 3 }
                        contentItem: Item {
                            Rectangle {
                                width: gpuBar.visualPosition * parent.width
                                height: parent.height
                                radius: 3
                                color: "#0070D8"
                            }
                        }
                    }
                }

                // Network Stats
                RowLayout {
                    Layout.fillWidth: true
                    
                    RowLayout {
                        spacing: 4
                        Text { text: "\u2193"; font.family: root.customFont; font.pixelSize: 14; color: "#0070D8" }
                        Text { text: sys ? sys.net_rx : "0 B/s"; font.family: root.customFont; font.pixelSize: 10; color: "#FFFFFF"; font.bold: true }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    // Moved Internet Status Widget (Ping connectivity)
                    Item {
                        id: netWidget
                        width: 16
                        height: 16
                        Layout.alignment: Qt.AlignVCenter
                        
                        property var pGateway: root.sys && root.sys.ping_gateway !== undefined ? root.sys.ping_gateway : -1
                        property var pCloudflare: root.sys && root.sys.ping_cloudflare !== undefined ? root.sys.ping_cloudflare : -1
                        property var pGoogle: root.sys && root.sys.ping_google !== undefined ? root.sys.ping_google : -1
                        
                        readonly property bool online: pGoogle > 0 || pCloudflare > 0
                        readonly property bool localOnly: !online && pGateway > 0
                        readonly property bool offline: !online && !localOnly
                        
                        Text {
                            anchors.centerIn: parent
                            text: netWidget.offline ? "󰲜" : (netWidget.localOnly ? "󰖪" : "󰖟")
                            font.family: root.customFont
                            font.pixelSize: 12
                            color: netWidget.offline ? "#ff3b30" : (netWidget.localOnly ? "#ff9500" : "#0070D8")
                        }
                        
                        MouseArea {
                            id: netMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            
                            
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    RowLayout {
                        spacing: 4
                        Text { text: "\u2191"; font.family: root.customFont; font.pixelSize: 14; color: "#0070D8" }
                        Text { text: sys ? sys.net_tx : "0 B/s"; font.family: root.customFont; font.pixelSize: 10; color: "#FFFFFF"; font.bold: true }
                    }
                }
            }

            // Expanded section — anchored below always-visible content (~172px)
            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 152
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 6
                visible: root.expandedMode === "system"

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#1AFFFFFF"
                }

                // CPU Cores Grid Header
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "CPU Thread Activity (" + (sys ? sys.cpu_ghz.toFixed(2) : "0.00") + " GHz)"; font.family: root.customFont; font.pixelSize: 9; color: "#99FFFFFF"; font.bold: true }
                    Item { Layout.fillWidth: true }
                    Text { text: (sys ? sys.cpu_temp.toFixed(0) : "0") + "°C"; font.family: root.customFont; font.pixelSize: 9; color: "#99FFFFFF"; font.bold: true }
                }

                // CPU Core Activity Grid
                Grid {
                    id: cpuGrid
                    columns: 4
                    rowSpacing: 3
                    columnSpacing: 6
                    Layout.alignment: Qt.AlignHCenter

                    Repeater {
                        model: (sys && sys.cpu_cores && sys.cpu_cores.length > 0) ? sys.cpu_cores : 32
                        delegate: Rectangle {
                            width: 70
                            height: 11
                            color: "#1AFFFFFF"
                            radius: 2

                            Rectangle {
                                width: (sys && sys.cpu_cores && sys.cpu_cores[index] !== undefined) ? (sys.cpu_cores[index] / 100.0 * parent.width) : 0
                                height: parent.height
                                radius: 2
                                color: {
                                    var val = (sys && sys.cpu_cores && sys.cpu_cores[index] !== undefined) ? sys.cpu_cores[index] : 0;
                                    if (val > 80) return "#E60000";
                                    if (val > 50) return "#FFA500";
                                    return "#0070D8";
                                }
                            }

                            Text {
                                text: (sys && sys.cpu_cores && sys.cpu_cores[index] !== undefined) ? Math.round(sys.cpu_cores[index]) + "%" : "0%"
                                font.family: root.customFont
                                font.pixelSize: 8
                                font.bold: true
                                color: "#FFFFFF"
                                anchors.centerIn: parent
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#1AFFFFFF"
                }

                // GPU Stats Clocks and Temps Row
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "GPU Clocks (" + (sys ? sys.gpu_sclk : 0) + " / " + (sys ? sys.gpu_mclk : 0) + " MHz)"
                        font.family: root.customFont; font.pixelSize: 9; color: "#99FFFFFF"; font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (sys ? sys.gpu_temp.toFixed(0) : "0") + "°C (Jnc: " + (sys ? sys.gpu_temp_junction.toFixed(0) : "0") + "°C, Mem: " + (sys ? sys.gpu_temp_mem.toFixed(0) : "0") + "°C)"
                        font.family: root.customFont; font.pixelSize: 9; color: "#99FFFFFF"; font.bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#1AFFFFFF"
                }

                // 3-Column Processes Lists
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Top CPU
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Top CPU"; font.family: root.customFont; font.pixelSize: 9; color: "#0070D8"; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                        Repeater {
                            model: cpuProcsModel
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: 11
                                    clip: true
                                    Text {
                                        id: cpuProcText
                                        text: model.name
                                        font.family: root.customFont
                                        font.pixelSize: 8
                                        color: "#FFFFFF"
                                        elide: Text.ElideNone
                                        anchors.verticalCenter: parent.verticalCenter
                                        SequentialAnimation on x {
                                            id: cpuScrollAnim
                                            running: cpuProcText.contentWidth > parent.width
                                            loops: Animation.Infinite
                                            PauseAnimation { duration: 1500 }
                                            NumberAnimation {
                                                from: 0
                                                to: parent.width - cpuProcText.contentWidth
                                                duration: Math.max(1000, (cpuProcText.contentWidth - parent.width) * 30)
                                                easing.type: Easing.InOutQuad
                                            }
                                            PauseAnimation { duration: 1500 }
                                            NumberAnimation {
                                                from: parent.width - cpuProcText.contentWidth
                                                to: 0
                                                duration: 800
                                                easing.type: Easing.InOutQuad
                                            }
                                            onRunningChanged: {
                                                if (!running) cpuProcText.x = 0;
                                            }
                                        }
                                        onTextChanged: cpuProcText.x = 0
                                    }
                                }
                                Text {
                                    text: model.valueText
                                    font.family: root.customFont
                                    font.pixelSize: 8
                                    color: "#E6FFFFFF"
                                    font.bold: true
                                    Layout.preferredWidth: 24
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                        Text { text: " "; font.pixelSize: 8; visible: cpuProcsModel.count === 0 }
                    }

                    // Top RAM
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Top RAM"; font.family: root.customFont; font.pixelSize: 9; color: "#0070D8"; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                        Repeater {
                            model: memProcsModel
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: 11
                                    clip: true
                                    Text {
                                        id: memProcText
                                        text: model.name
                                        font.family: root.customFont
                                        font.pixelSize: 8
                                        color: "#FFFFFF"
                                        elide: Text.ElideNone
                                        anchors.verticalCenter: parent.verticalCenter
                                        SequentialAnimation on x {
                                            id: memScrollAnim
                                            running: memProcText.contentWidth > parent.width
                                            loops: Animation.Infinite
                                            PauseAnimation { duration: 1500 }
                                            NumberAnimation {
                                                from: 0
                                                to: parent.width - memProcText.contentWidth
                                                duration: Math.max(1000, (memProcText.contentWidth - parent.width) * 30)
                                                easing.type: Easing.InOutQuad
                                            }
                                            PauseAnimation { duration: 1500 }
                                            NumberAnimation {
                                                from: parent.width - memProcText.contentWidth
                                                to: 0
                                                duration: 800
                                                easing.type: Easing.InOutQuad
                                            }
                                            onRunningChanged: {
                                                if (!running) memProcText.x = 0;
                                            }
                                        }
                                        onTextChanged: memProcText.x = 0
                                    }
                                }
                                Text {
                                    text: model.valueText
                                    font.family: root.customFont
                                    font.pixelSize: 8
                                    color: "#E6FFFFFF"
                                    font.bold: true
                                    Layout.preferredWidth: 32
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                        Text { text: " "; font.pixelSize: 8; visible: memProcsModel.count === 0 }
                    }

                    // Top GPU
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Top GPU"; font.family: root.customFont; font.pixelSize: 9; color: "#0070D8"; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                        Repeater {
                            model: gpuProcsModel
                            delegate: RowLayout {
                                Layout.fillWidth: true
                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: 11
                                    clip: true
                                    Text {
                                        id: gpuProcText
                                        text: model.name
                                        font.family: root.customFont
                                        font.pixelSize: 8
                                        color: "#FFFFFF"
                                        elide: Text.ElideNone
                                        anchors.verticalCenter: parent.verticalCenter
                                        SequentialAnimation on x {
                                            id: gpuScrollAnim
                                            running: gpuProcText.contentWidth > parent.width
                                            loops: Animation.Infinite
                                            PauseAnimation { duration: 1500 }
                                            NumberAnimation {
                                                from: 0
                                                to: parent.width - gpuProcText.contentWidth
                                                duration: Math.max(1000, (gpuProcText.contentWidth - parent.width) * 30)
                                                easing.type: Easing.InOutQuad
                                            }
                                            PauseAnimation { duration: 1500 }
                                            NumberAnimation {
                                                from: parent.width - gpuProcText.contentWidth
                                                to: 0
                                                duration: 800
                                                easing.type: Easing.InOutQuad
                                            }
                                            onRunningChanged: {
                                                if (!running) gpuProcText.x = 0;
                                            }
                                        }
                                        onTextChanged: gpuProcText.x = 0
                                    }
                                }
                                Text {
                                    text: model.valueText
                                    font.family: root.customFont
                                    font.pixelSize: 8
                                    color: "#E6FFFFFF"
                                    font.bold: true
                                    Layout.preferredWidth: 46
                                    horizontalAlignment: Text.AlignRight
                                }
                            }
                        }
                        Text { text: " "; font.pixelSize: 8; visible: gpuProcsModel.count === 0 }
                    }
                }
            }
        }
    }
}
