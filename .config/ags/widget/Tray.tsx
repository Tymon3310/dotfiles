import { Gtk } from "ags/gtk4"
import Tray from "gi://AstalTray"
import { createBinding, For } from "ags"

const GioNative = imports.gi.Gio
const GLib = imports.gi.GLib

// ── DBus helpers ────────────────────────────────────────────────────────────

function fetchMenuItems(
  busName: string,
  menuPath: string,
  callback: (items: MenuItem[]) => void
) {
  try {
    const connection = GioNative.bus_get_sync(GioNative.BusType.SESSION, null)
    connection.call(
      busName,
      menuPath,
      "com.canonical.dbusmenu",
      "GetLayout",
      new GLib.Variant("(iias)", [0, -1, ["label", "type", "enabled", "visible", "icon-name"]]),
      new GLib.VariantType("(u(ia{sv}av))"),
      GioNative.DBusCallFlags.NONE,
      3000,
      null,
      (conn: any, result: any) => {
        try {
          const reply = conn.call_finish(result)
          const [, layout] = reply.deepUnpack()
          callback(parseLayout(layout))
        } catch (e) {
          console.error("[Tray] GetLayout error:", e)
          callback([])
        }
      }
    )
  } catch (e) {
    console.error("[Tray] DBus setup error:", e)
    callback([])
  }
}

interface MenuItem {
  id: number
  label: string
  type: "item" | "separator"
  enabled: boolean
  iconName?: string
  children: MenuItem[]
}

function parseLayout(raw: any): MenuItem[] {
  if (!raw) return []
  const result: MenuItem[] = []
  try {
    const unpacked = raw.deepUnpack ? raw.deepUnpack() : raw
    const [, , children] = unpacked
    for (const child of (children || [])) {
      try {
        const cu = child.deepUnpack ? child.deepUnpack() : child
        const [id, propsRaw, grandchildren] = cu
        const props: any = {}
        if (propsRaw) {
          const pu = propsRaw.deepUnpack ? propsRaw.deepUnpack() : propsRaw
          for (const [k, v] of Object.entries(pu)) {
            try { props[k] = (v as any).deepUnpack ? (v as any).deepUnpack() : v } catch (_) {}
          }
        }
        const type = props["type"] === "separator" ? "separator" : "item"
        const enabled = props["enabled"] !== false
        const visible = props["visible"] !== false
        const label: string = props["label"] || ""
        const iconName: string = props["icon-name"] || ""
        const gc: any[] = grandchildren || []

        if (!visible) continue

        if (type === "separator") {
          result.push({ id, label: "", type: "separator", enabled: true, children: [] })
          continue
        }

        // Submenu — recurse
        if (gc.length > 0) {
          const subChildren = parseLayout(cu)
          if (subChildren.length > 0) {
            result.push({ id, label, type: "item", enabled, iconName, children: subChildren })
          }
          continue
        }

        if (label) {
          result.push({ id, label, type: "item", enabled, iconName, children: [] })
        }
      } catch (e) {
        console.error("[Tray] parse child error:", e)
      }
    }
  } catch (e) {
    console.error("[Tray] parseLayout error:", e)
  }
  return result
}

function activateItem(busName: string, menuPath: string, itemId: number) {
  try {
    const connection = GioNative.bus_get_sync(GioNative.BusType.SESSION, null)
    connection.call(
      busName, menuPath,
      "com.canonical.dbusmenu", "Event",
      new GLib.Variant("(isvu)", [itemId, "clicked", new GLib.Variant("i", 0), 0]),
      null,
      GioNative.DBusCallFlags.NONE,
      -1, null, null
    )
  } catch (e) {
    console.error("[Tray] Event error:", e)
  }
}

// ── Popover menu builder ─────────────────────────────────────────────────────

function buildMenuBox(
  items: MenuItem[],
  busName: string,
  menuPath: string,
  popover: Gtk.Popover
): Gtk.Widget {
  const box = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 2 })
  box.add_css_class("tray-menu-box")

  for (const item of items) {
    if (item.type === "separator") {
      const sep = new Gtk.Separator({ orientation: Gtk.Orientation.HORIZONTAL })
      sep.add_css_class("tray-sep")
      box.append(sep)
      continue
    }

    if (item.children.length > 0) {
      // Section header label (non-clickable submenu title)
      const lbl = new Gtk.Label({ label: item.label, halign: Gtk.Align.START })
      lbl.add_css_class("tray-menu-section")
      box.append(lbl)
      // Render children indented
      const sub = buildMenuBox(item.children, busName, menuPath, popover)
      sub.add_css_class("tray-submenu")
      box.append(sub)
      continue
    }

    const btn = new Gtk.Button({ halign: Gtk.Align.FILL })
    btn.add_css_class("tray-menu-item")
    if (!item.enabled) btn.add_css_class("tray-menu-item-disabled")

    const btnBox = new Gtk.Box({ spacing: 8 })
    if (item.iconName) {
      const img = new Gtk.Image({ icon_name: item.iconName, pixel_size: 16 })
      btnBox.append(img)
    }
    const lbl = new Gtk.Label({ label: item.label, halign: Gtk.Align.START, hexpand: true })
    btnBox.append(lbl)
    btn.set_child(btnBox)

    if (item.enabled) {
      btn.connect("clicked", () => {
        popover.popdown()
        activateItem(busName, menuPath, item.id)
      })
    }

    box.append(btn)
  }

  return box
}

function showTrayPopover(
  parent: Gtk.Widget,
  busName: string,
  menuPath: string,
  title: string
) {
  // Remove old popover if any
  const old = (parent as any)._trayPopover as Gtk.Popover | undefined
  if (old) {
    old.popdown()
    old.unparent()
    ;(parent as any)._trayPopover = null
  }

  const popover = new Gtk.Popover()
  popover.add_css_class("tray-popover")
  popover.set_parent(parent)
  popover.set_has_arrow(false)
  ;(parent as any)._trayPopover = popover

  // Show loading state immediately
  const loadingBox = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL })
  loadingBox.add_css_class("tray-menu-box")
  const titleLbl = new Gtk.Label({ label: title })
  titleLbl.add_css_class("tray-menu-title")
  const spinner = new Gtk.Spinner()
  spinner.set_spinning(true)
  loadingBox.append(titleLbl)
  loadingBox.append(spinner)
  popover.set_child(loadingBox)
  popover.popup()

  fetchMenuItems(busName, menuPath, (items) => {
    spinner.set_spinning(false)
    if (items.length === 0) {
      const lbl = new Gtk.Label({ label: "No options available" })
      lbl.add_css_class("tray-menu-empty")
      loadingBox.remove(spinner)
      loadingBox.append(lbl)
      return
    }

    const menuBox = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL, spacing: 0 })
    menuBox.add_css_class("tray-menu-box")
    const titleLbl2 = new Gtk.Label({ label: title })
    titleLbl2.add_css_class("tray-menu-title")
    menuBox.append(titleLbl2)
    const sep = new Gtk.Separator({ orientation: Gtk.Orientation.HORIZONTAL })
    sep.add_css_class("tray-sep")
    menuBox.append(sep)
    const content = buildMenuBox(items, busName, menuPath, popover)
    menuBox.append(content)
    popover.set_child(menuBox)
  })
}

// ── Component ────────────────────────────────────────────────────────────────

export default function SysTray({ setup }: { setup?: (self: any) => void }) {
  const tray = Tray.get_default()
  const items = createBinding(tray, "items")

  return (
    <box class="SysTray" spacing={4} $={(self) => { if (setup) setup(self) }}>
      <For each={items}>
        {(item) => (
          <box
            tooltipMarkup={item.tooltip_markup}
            class="tray-item"
            $={(self) => {
              // Left click — activate
              const leftGesture = new Gtk.GestureClick({ button: 1 })
              leftGesture.connect("released", (_, _n, x, y) => {
                item.activate(x, y)
              })
              self.add_controller(leftGesture)

              // Right click — show native popover
              const rightGesture = new Gtk.GestureClick({ button: 3 })
              rightGesture.connect("released", () => {
                if (item.menu_path && item.item_id) {
                  const busName = item.item_id.split("/")[0]
                  showTrayPopover(self, busName, item.menu_path, item.title || "Menu")
                }
              })
              self.add_controller(rightGesture)
            }}
          >
            <image gicon={item.gicon} pixel_size={18} />
          </box>
        )}
      </For>
    </box>
  )
}
