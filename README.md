# 🦙 Llama.cpp Monitor

![KDE Plasma 6](https://img.shields.io/badge/KDE-Plasma%206-blue) ![Version](https://img.shields.io/badge/Version-0.1.0-green) ![Requirements](https://img.shields.io/badge/Requirements-llama--swap-orange) ![License](https://img.shields.io/badge/License-MIT-yellow) ![Platform](https://img.shields.io/badge/Platform-Linux-lightgrey)

## ✨ Overview

Monitor and manage llama.cpp models served through [llama-swap](https://github.com/mostlygeek/llama-swap) directly from your KDE Plasma 6 panel. Get real-time visibility into VRAM and RAM usage with an intuitive round panel icon.

![Main Widget View](./screenshots/main-widget-view.png)  
***Popup with detailed memory usage and model unload button***

![Configure Widget View](./screenshots/configure-widget-view.png)  
***Widget configuration***

## 🎯 Features

### 📊 Real-time Monitoring
- **Round Panel Icon** with badge showing loaded model count
- **Tooltip** with loaded model count and free VRAM/RAM
- **Popup Display** shows free/total VRAM and free/total RAM usage
- **Per-model Memory Footprint** with loading/ready status
- **External Server Detection** lists `llama-server` processes not started by llama-swap (e.g. inside a container) as *External*, named from `--alias`, `--model`, or `--hf-repo`
- **Live Updates** with separate refresh intervals for popup open and closed

### 🧹 Model Management
- **Unload Buttons** for each llama-swap model (hidden for external servers, which llama-swap cannot unload)
- **Granular Memory Attribution** per `llama-server` PID, matched to llama-swap models by port
  - VRAM from DRM fdinfo (`drm-memory-vram`)
  - RAM as GTT (`drm-memory-gtt`) plus process RSS

### ⚙️ Customization
- **Server URL Configuration** (default: `http://127.0.0.1:8090`)
- **Adjustable Refresh Intervals** for popup open and closed states
- **Works without an AMD GPU** (VRAM shows as *unavailable*, RAM still displayed)

## 📋 Requirements

- **Desktop Environment**: KDE Plasma 6
- **Dependencies**: llama-swap, `curl`, `pgrep` (procps), `awk`, `kpackagetool6` (for installation)
- **Hardware**: AMD GPU for VRAM metrics (optional)
  - System VRAM is read from `/sys/class/drm/card*/device/mem_info_vram_*` (amdgpu)
- **Permissions**: Read access to `/proc/<pid>/fdinfo` and `/proc/<pid>/status` of `llama-server` processes for per-model memory

## 🚀 Installation

```bash
git clone https://github.com/danielmdecker/llamacppmon-kde.git
cd llamacppmon-kde

# Install, or upgrade if already installed
./install.sh

# Upgrade only
./install.sh upgrade

# Uninstall
./install.sh remove
```

If the widget was already on the panel when upgrading, reload Plasma:

```bash
kquitapp6 plasmashell && kstart plasmashell
```

### Setup Instructions

1. **Install llama-swap** if you haven't already
2. **Run the install script** to install the monitor
3. **Add Widget** from the panel's *Add Widgets* menu
4. **Configure Settings** by right-clicking the icon

## ⚙️ Configuration

**Right-click the icon → Configure…**

- **Server URL**: llama-swap base URL (default: `http://127.0.0.1:8090`)
- **Refresh interval (popup open)**: 1 to 3600 seconds, default 3
- **Refresh interval (popup closed)**: badge/tooltip polling, 5 to 3600 seconds, default 30

## 🔧 Troubleshooting

### 🔴 "Cannot reach llama-swap"
- **Check if llama-swap is running**: `curl http://127.0.0.1:8090/running`
- **Check the Server URL** in the widget configuration

### 🟡 VRAM Shows "unavailable"
- **Non-AMD GPU**: System VRAM is only read from amdgpu sysfs
- **Verify the files exist**: `ls /sys/class/drm/card*/device/mem_info_vram_*`

### 🟣 External Server Missing or Memory Not Shown
- **Process name**: Detection matches the exact process name `llama-server`: `pgrep -x llama-server`
- **Memory only while open**: Per-process VRAM/RAM is read only while the popup is open
- **Permissions**: Memory for processes owned by another user (e.g. a container running as root) requires read access to `/proc/<pid>/fdinfo` and `/proc/<pid>/status`

### 🔵 Widget Not Updating After Upgrade
- **Reload Plasma**: `kquitapp6 plasmashell && kstart plasmashell`
- **Verify Plasma 6 version**: `plasmashell --version`

### Debugging

```bash
# Run the widget in a standalone window with QML errors on the terminal
plasmoidviewer -a com.danielmdecker.llamacppmon

# Plasma shell logs
journalctl --user -b | grep plasmashell
```

## 🔨 Development

### Project Structure
```
llamacppmon-kde/
├── package/                        # Plasmoid package
│   ├── contents/
│   │   ├── config/                 # KConfig schema (main.xml) and config categories
│   │   ├── icons/                  # Bundled panel and unload icons
│   │   └── ui/
│   │       ├── main.qml            # Data refresh, process detection, compact representation
│   │       ├── FullRepresentation.qml  # Popup
│   │       ├── ModelDelegate.qml   # Model list row
│   │       └── configGeneral.qml   # Settings page
│   └── metadata.json               # Plasmoid metadata
├── screenshots/
├── install.sh                      # Install / upgrade / remove script
└── README.md
```

After editing QML, run `./install.sh upgrade` and test with `plasmoidviewer -a com.danielmdecker.llamacppmon`.

## 📄 License

MIT, as declared in `package/metadata.json`.

## 🤝 Contributing

Contributions are welcome. Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📧 Contact

- **Author**: Daniel M. Decker
- **Repository**: [llamacppmon-kde](https://github.com/danielmdecker/llamacppmon-kde)
- **Issues**: [Open an issue](https://github.com/danielmdecker/llamacppmon-kde/issues)
- **Email**: [daniel.m.decker@gmail.com](mailto:daniel.m.decker@gmail.com)

## 🙏 Acknowledgments

- [llama-swap](https://github.com/mostlygeek/llama-swap) for model swapping and the management API
- [llama.cpp](https://github.com/ggml-org/llama.cpp) for `llama-server`
- [KDE Plasma](https://kde.org/) for the desktop environment

---

Made with ❤️ for the KDE community

[⬆ Back to Top](#-llamacpp-monitor)
