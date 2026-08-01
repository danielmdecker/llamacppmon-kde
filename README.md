# 🦙 Llama.cpp Monitor

<div align="center">
  <img src="https://img.shields.io/badge/KDE-Plasma%206-blue" alt="KDE Plasma 6" />
  <img src="https://img.shields.io/badge/Status-Active-green" alt="Active Status" />
  <img src="https://img.shields.io/badge/Requirements-llama--swap-orange" alt="Requirements" />
</div>

## ✨ Overview

Monitor and manage llama.cpp models served through [llama-swap](https://github.com/mostlygeek/llama-swap) directly from your KDE Plasma 6 panel. Get real-time visibility into VRAM and RAM usage with an intuitive round panel icon.

## 🎯 Features

- **📊 Real-time Monitoring**
  - Round panel icon with badge showing loaded model count
  - Popup displays VRAM/total VRAM and RAM/total RAM usage
  - Per-model memory footprint with loading/ready status

- **🧹 Memory Management**
  - Easy unload buttons for each loaded model
  - Automatic RAM/VRAM cleanup via process attributes
  - Granular memory attribution from `llama-server` process

- **⚙️ Customizable**
  - Configurable server URL (default: `http://127.0.0.1:8090`)
  - Adjustable refresh intervals for popup and closed states
  - Works with or without AMD GPU (VRAM still displayed when available)

## 📋 Requirements

- **Desktop Environment**: KDE Plasma 6
- **Core Dependencies**: llama-swap, curl
- **Hardware**:
  - AMD GPU for VRAM metrics (optional - works without one)
  - Requires `/sys/class/drm/card*/device/mem_info_vram_*` access

## 🚀 Installation

### Quick Install

```bash
# Install or upgrade
./install.sh

# Uninstall
./install.sh remove
```

### Setup

1. Run the install script
2. Add **Llama.cpp Monitor** from the panel's *Add Widgets* menu
3. Configure your llama-swap server URL if needed

## ⚙️ Configuration

**Right-click the icon → Configure…**

- **Server URL** — llama-swap base URL (default: `http://127.0.0.1:8090`)
- **Refresh interval (popup open)** — default: 3 seconds
- **Refresh interval (popup closed)** — badge/tooltip polling, default: 30 seconds

## 🔧 Development

```bash
# Clone repository
git clone <repository-url>

# Install development dependencies
./install.sh dev

# Run tests
./run-tests.sh
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📧 Contact

For questions or issues, please open an issue on the repository.

---

<div align="center">
  Made with ❤️ for the KDE community
</div>
