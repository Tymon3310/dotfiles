const AstalTray = imports.gi.AstalTray;
const GLib = imports.gi.GLib;
const tray = AstalTray.Tray.get_default();

const loop = new GLib.MainLoop(null, false);

GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
    console.log("Tray items count:", tray.items.length);
    for (const item of tray.items) {
        console.log("------------------------");
        console.log("id:", item.id);
        console.log("item_id:", item.item_id);
        console.log("title:", item.title);
        console.log("menu_path:", item.menu_path);
        console.log("icon_name:", item.icon_name);
    }
    loop.quit();
    return GLib.SOURCE_REMOVE;
});

loop.run();
