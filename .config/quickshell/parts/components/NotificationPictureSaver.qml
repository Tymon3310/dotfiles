
import QtQuick

import "../services"

// A picture that arrives as image data (`image://qsimage`) only lives as long
// as its notification, so it is rendered into a cache file once drawn and the
// history is pointed at that file. (NotificationService.keepPicture.)
//
// That render must happen from an item that outlives the grab. grabToImage()
// draws the item into a texture on the scene-graph thread on a later frame,
// and Qt parents the grab's result to the item being grabbed: if the item is
// deleted before that frame is finished, the render — and the completion event
// it posts to the result — touch freed memory and take Quickshell down with a
// segfault. Picture rows are rebuilt on every change to the notification lists
// (they are plain arrays, so the Repeater starts over) and the heads-up popup
// is hidden whenever it closes, so the row that shows a picture is exactly the
// wrong thing to grab from. This item lives in the always-mapped bar, never
// moves, and grabs a single image at a time.
Item {
    id: root

    Component.onCompleted: NotificationService.registerPictureSaver(root)
    Component.onDestruction: NotificationService.unregisterPictureSaver(root)

    // Behind everything in the bar; it draws nothing once it settles.
    z: -1000

    property var pending: null

    // Called by the service; only one request is in flight at a time.
    function save(key: int, url: string, path: string): void {
        root.pending = { key: key, url: url, path: path }
        // Cleared first so a repeat of the same source still reloads.
        loader.source = ""
        loader.source = url
    }

    function finish(): void {
        const key = root.pending ? root.pending.key : -1
        root.pending = null
        loader.source = ""
        NotificationService.pictureSaveFinished(key)
    }

    // Transparent so it never shows. An item's own opacity is applied outside
    // the layer grabToImage renders, so the saved picture is unaffected.
    Image {
        id: loader

        opacity: 0
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectFit
        sourceSize.width: 200

        onStatusChanged: {
            if (!root.pending)
                return
            if (status === Image.Error) {
                root.finish()
                return
            }
            if (status !== Image.Ready)
                return

            // The grab renders the item at its own size, so match it to the
            // picture being saved.
            const w = Math.max(1, Math.round(loader.implicitWidth))
            const h = Math.max(1, Math.round(loader.implicitHeight))
            loader.width = w
            loader.height = h

            const started = loader.grabToImage(result => {
                const item = root.pending
                if (item && result && result.saveToFile(item.path))
                    NotificationService.keepPicture(item.key, `file://${item.path}?${Date.now()}`)
                root.finish()
            })
            // Not attached to a window (bar hidden, say): nothing to wait for.
            if (!started)
                root.finish()
        }
    }
}
