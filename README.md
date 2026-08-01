# Llama.cpp Monitor (Plasma 6 plasmoid)

Monitor and manage llama.cpp models served through
[llama-swap](https://github.com/mostlygeek/llama-swap) from the KDE Plasma panel.

- Round panel icon with a badge showing how many models are currently loaded
- Popup header with available/total **VRAM** (amdgpu sysfs) and **RAM** (`/proc/meminfo`)
- List of loaded models with per-model VRAM and RAM footprint and state
  (loading / ready), each with an unload button that clears it from memory
- Per-model memory is attributed via the model's llama-server process:
  VRAM/GTT from DRM fdinfo, RSS from `/proc`

## Requirements

- KDE Plasma 6
- llama-swap (uses `GET /running` and `POST /api/models/unload/<model>`)
- `curl`
- An amdgpu GPU for the VRAM numbers (`/sys/class/drm/card*/device/mem_info_vram_*`);
  everything else works without one

## Install

```sh
./install.sh            # install or upgrade
./install.sh remove     # uninstall
```

Then add **Llama.cpp Monitor** from the panel's *Add Widgets* menu.

## Configuration

Right-click the icon → *Configure…*

- **Server URL** — llama-swap base URL (default `http://127.0.0.1:8090`)
- **Refresh interval (popup open)** — default 3 s
- **Refresh interval (popup closed)** — badge/tooltip polling, default 30 s
