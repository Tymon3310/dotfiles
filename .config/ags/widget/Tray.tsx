import { Gtk } from "ags/gtk4"
import Tray from "gi://AstalTray"
import { createBinding, For } from "ags"

export default function SysTray() {
    const tray = Tray.get_default()
    const items = createBinding(tray, "items")

    return (
        <box class="SysTray" spacing={4}>
            <For each={items}>
                {(item) => (
                    <menubutton
                        tooltipMarkup={item.tooltip_markup}
                        menu_model={item.menu_model}
                        $={(self) => {
                            if (item.action_group) {
                                self.insert_action_group("dbusmenu", item.action_group)
                            }
                        }}
                    >
                        <image gicon={item.gicon} />
                    </menubutton>
                )}
            </For>
        </box>
    )
}
