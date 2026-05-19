const Tray = imports.gi.AstalTray; const t = Tray.get_default(); console.log(Object.getOwnPropertyNames(Object.getPrototypeOf(t)).join(', '))
