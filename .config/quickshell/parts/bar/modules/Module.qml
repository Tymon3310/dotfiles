// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O D U L E                                                            │
// │   maps a module id to its component                                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"
import "../island/controls"

// Maps a module id to its component, so the bar, the island and the services
// pass ids around as strings.
//
// `compact` is the ring face for modules that have one
// (`ModuleService.ringed`); otherwise the detail is built. A new module needs a
// row here and one in the catalogue.
Item {
    id: root

    property string moduleId: ""
    property bool compact: false

    readonly property var components: ({
        clock: clockModule,
        media: mediaModule,
        battery: batteryModule,
        volume: volumeModule,
        brightness: brightnessModule,
        network: networkModule,
        bluetooth: bluetoothModule,
        weather: weatherModule,
        stats: statsModule,
        calendar: calendarModule,
        notifications: notificationsModule
    })

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        active: root.moduleId !== ""
        sourceComponent: root.components[root.moduleId] ?? null
    }

    Component { id: clockModule;      ClockModule {} }
    Component { id: mediaModule;      MediaModule { compact: root.compact } }
    Component { id: batteryModule;    BatteryModule { compact: root.compact } }
    Component { id: volumeModule;     VolumeModule { compact: root.compact } }
    Component { id: brightnessModule; BrightnessModule { compact: root.compact } }
    Component { id: networkModule;    NetworkModule { compact: root.compact } }
    Component { id: bluetoothModule;  BluetoothModule { compact: root.compact } }
    Component { id: weatherModule;    WeatherModule { compact: root.compact } }
    Component { id: statsModule;      StatsModule { compact: root.compact } }
    // No module files of their own in the extraction: the cards stand in.
    Component { id: calendarModule;      CalendarCard { bare: true } }
    Component { id: notificationsModule; NotificationList { bare: true } }
}
