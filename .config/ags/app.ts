import app from "ags/gtk4/app"
import Bar from "./widget/Bar"

app.start({
  css: "./style.css", 
  main() {
    for (const monitor of app.get_monitors()) {
        const win = Bar(monitor)
        app.add_window(win)
    }
  },
})

export default app
