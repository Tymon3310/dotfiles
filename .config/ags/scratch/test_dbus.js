const AstalTray = imports.gi.AstalTray;
const GLib = imports.gi.GLib;
const tray = AstalTray.Tray.get_default();

const loop = new GLib.MainLoop(null, false);

GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
    for (const item of tray.items) {
        console.log("------------------------");
        console.log("item_id:", item.item_id);
        console.log("menu_model:", item.menu_model);
        console.log("action_group:", item.action_group);
        if (item.action_group) {
            console.log("action_group type:", item.action_group.toString());
        }
    }
    loop.quit();
    return GLib.SOURCE_REMOVE;
});

loop.run();
