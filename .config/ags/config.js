import App from 'resource:///com/github/Aylur/ags/app.js'
import Widget from 'resource:///com/github/Aylur/ags/widget.js'
import Network from 'resource:///com/github/Aylur/ags/service/network.js'
import Service from 'resource:///com/github/Aylur/ags/service.js'
import Utils from 'resource:///com/github/Aylur/ags/utils.js'
import Variable from 'resource:///com/github/Aylur/ags/variable.js'
import Bluetooth from 'resource:///com/github/Aylur/ags/service/bluetooth.js'

// System monitoring
const cpu = Variable(0, {
  poll: [2000, 'top -b -n 1', out => {
    const usage = out.split('\n')
      .find(line => line.includes('Cpu(s)'))
      .split(/\s+/)[1]
      .replace(',', '.');
    return Number(usage) / 100;
  }],
});

const ram = Variable(0, {
  poll: [2000, 'free', out => {
    const lines = out.split('\n');
    const info = lines.find(line => line.includes('Mem:'))
      .split(/\s+/);
    const [total, used] = [info[1], info[2]].map(n => Number(n));
    return used / total;
  }],
});

// Initialize audio service
const audio = await Service.import('audio');


async function getWeather() {
  try {
    const out = await Utils.execAsync(['curl', 'wttr.in/trzebnica/?format=3']);
    const temp = out?.trim() || 'N/A';
    return temp.match(/[0-9Â°]+/)?.[0] || 'N/A';
  } catch (error) {
    return 'N/A';
  }
};

// Weather widget with polling and type checking
const WeatherWidget = () => {
  return Widget.Button({
    className: 'quick-toggle',
    child: Widget.Box({
      children: [
        Widget.Icon('weather-clear-symbolic'),
        Widget.Label({
          className: 'weather-label',
          setup: self => {
            getWeather().then(temp => {
              self.label = temp;
            });
          }
        }),
      ],
    }),
  });
};

const CpuBox = () => Widget.Box({
  vertical: true,
  children: [
    Widget.Label({
      label: cpu.bind().transform(v => `${Math.round(v * 100)}%`),
      className: 'system-value'
    }),
    Widget.CircularProgress({
      className: 'system-progress',
      value: cpu.bind(),
    }),
    Widget.Label({
      label: 'CPU',
      className: 'system-label'
    })
  ]
});

const RamBox = () => Widget.Box({
  vertical: true,
  children: [
    Widget.Label({
      label: ram.bind().transform(v => `${Math.round(v * 100)}%`),
      className: 'system-value'
    }),
    Widget.CircularProgress({
      className: 'system-progress',
      value: ram.bind(),
    }),
    Widget.Label({
      label: 'RAM',
      className: 'system-label'
    })
  ]
});



const QuickSettings = () => Widget.Box({
  className: 'quick-settings',
  children: [
    Widget.Button({
      className: 'quick-toggle',
      onClicked: () => Utils.execAsync(['pavucontrol']),
      onSecondaryClick: () => audio.speaker.isMuted = !audio.speaker.isMuted,
      child: Widget.Box({
        children: [
          Widget.Icon({
            icon: audio.speaker.bind('isMuted').transform(m =>
              m ? 'audio-volume-muted-symbolic' : 'audio-volume-high-symbolic'
            ),
          }),
          Widget.Label({
            className: 'volume-label',
            label: audio.speaker.bind('volume').transform(v =>
              `${Math.round(v * 100)}%`
            ),
          }),
        ]
      }),
    }),
    Widget.Button({
      className: 'quick-toggle',
      onClicked: () => Utils.execAsync(['pavucontrol']),
      onSecondaryClick: () => audio.microphone.isMuted = !audio.microphone.isMuted,
      child: Widget.Box({
        children: [
          Widget.Icon({
            icon: audio.microphone.bind('isMuted').transform(m =>
              m ? 'audio-input-microphone-muted-symbolic' : 'audio-input-microphone-symbolic'
            ),
          }),
          Widget.Label({
            className: 'volume-label',
            label: audio.microphone.bind('volume').transform(v =>
              `${Math.round(v * 100)}%`
            ),
          }),
        ]
      }),
    }),
    WeatherWidget(),
  ],
});

const NetworkControls = () => Widget.Box({
  className: 'network-controls',
  children: [
    Widget.Box({
      className: 'network-status',
      children: [
        Widget.Button({
          className: 'quick-toggle',
          onClicked: () => Utils.execAsync(['alacritty', '--class', 'Alacritty,floating', '-T', 'floating', '-e', 'nmtui']),
          child: Widget.Box({
            children: [
              Widget.Icon({
                icon: Network.wired?.connected ?
                  'network-wired-symbolic' :
                  'network-wired-disconnected-symbolic'
              }),
              Widget.Label({
                className: 'status-label',
                label: Network.wired?.bind('speed').transform(speed =>
                  speed ? `${speed} Mb/s` : 'Disconnected'
                ),
              }),
            ]
          }),
        }),
        Widget.Button({
          className: 'quick-toggle',
          onClicked: () => Utils.execAsync(['blueman-manager']),
          child: Widget.Box({
            children: [
              Widget.Icon('bluetooth-symbolic'),
              Widget.Label({
                className: 'status-label',
                setup: self => self.hook(Bluetooth, () => {
                  const connected = Bluetooth.connected_devices;
                  self.label = connected.length > 0 ?
                    connected[0].alias :
                    `${Bluetooth.devices.length} devices`;
                }),
              }),
            ]
          }),
        }),
      ]
    }),
  ],
});

// Sidebar Window
const sidebar = Widget.Window({
  name: 'sidebar',
  className: 'sidebar',
  anchor: ['right', 'top'],
  margins: [8, 8],
  layer: 'overlay',
  visible: false,
  keymode: 'on-demand',
  setup: self => {
    self.keybind('Escape', () => {
      if (self.visible) {
        // self.visible = false;
        App.quit();
      }
    });
  },
  child: Widget.Box({
    className: 'sidebar',
    vertical: true,
    children: [
      QuickSettings(),
      Widget.Box({
        className: 'row',
        homogeneous: true,
        children: [CpuBox(), RamBox()]
      }),
      NetworkControls(),
    ],
  }),
});

const cld = Widget.Calendar({
  showDayNames: true,
  showDetails: false,
  showHeading: true,
  showWeekNumbers: true,
  className: "cld"
})
const Calendar = Widget.Box({
  spacing: 8,
  vertical: true,
  className: "calendar",
  children: [
    Widget.Box({
      className: "group",
      homogeneous: true,
      children: [cld]
    })
  ]
})
const CalendarWindow = Widget.Window({
  name: 'calendar',
  className: "window",
  anchor: ['top', 'right'],
  // Start with hidden window, toggle with ags -t sidebar
  // visible: true,
  visible: false,
  child: Widget.Box({
    css: 'padding: 1px;',
    child: Calendar,
  })
})

const css = `


.sidebar {
    background: #222222;
    padding: 12px;
    margin:14px;
    border-radius: 12px;
    font-weight: bold;
    border: 3px solid @color11;
    box-shadow: 0px 0px 10px 1px rgba(0, 0, 0, 0.8);
    padding:20px;
}

.calendar {
    background: #222222;
    padding: 12px;
    margin:14px;
    border-radius: 12px;
    font-weight: bold;
    border: 3px solid @color11;
    box-shadow: 0px 0px 10px 1px rgba(0, 0, 0, 0.8);
    padding:20px;
    min-width:320px;
}

.window {
    background:transparent;
}


.quick-settings, .row, .network-controls {
    padding: 8px;
    background-color: rgba(0, 0, 0, 0.2);
    border-radius: 12px;
    margin: 8px 0;
    border: 1px solid #0070D8;
}

.quick-toggle {
    padding: 8px;
    margin: 4px;
    border-radius: 10px;
    background-color: rgba(255, 255, 255, 0.1);
    border: 1px solid #0070D8;
}

.quick-toggle:hover {
    background-color: rgba(255, 255, 255, 0.15);
}

.volume-label, .weather-label, .status-label {
    margin-left: 8px;
    color: #ccc;
}

.system-progress {
    min-width: 80px;
    min-height: 80px;
    margin: 8px;
    border: 2px solid #0070D8;
    border-radius: 50%;
}
`;

App.connect("window-toggled", (_, name, visible) => {
  if (visible && name == 'calendar') {
    const d = new Date();
    cld.select_day(d.getDate())
    cld.select_month(d.getMonth(), d.getFullYear())
  }
})

App.config({
  css: css,
  windows: [sidebar, CalendarWindow],
});
