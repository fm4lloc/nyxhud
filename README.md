# NyxHud

Minimal, modular and low-overhead Linux desktop HUD focused on performance,
auditability and Unix philosophy.

NyxHud is a collector-based desktop overlay designed for Linux/X11
environments using a shell-first architecture with a separated renderer
pipeline.

The project prioritizes:
- simplicity
- modularity
- low overhead
- portability
- transparency
- inspectable code
- long-term maintainability

---

# Philosophy

NyxHud follows a strict engineering-oriented philosophy.

Core principles:

- Offline-first
- Modular collectors
- POSIX-first shell architecture
- Renderer separated from collectors
- Minimal dependency count
- X11-first workflow
- Hardened desktop friendly
- Auditability over abstraction
- Unix pipeline philosophy
- Copyleft licensing (GPLv3-or-later)

The project intentionally avoids:
- Electron
- browser runtimes
- cloud dependency
- telemetry
- monolithic desktop frameworks
- unnecessary abstractions
- heavy widget systems
- excessive runtime daemons

NyxHud is intentionally opinionated.

It prioritizes:
- engineering clarity
- deterministic behavior
- low-level control
- maintainability

over:
- visual excess
- framework complexity
- feature bloat

---

# Non-Goals

NyxHud intentionally does not aim to provide:

- a full desktop environment
- a widget framework
- Wayland-first support
- integrated package management
- cloud synchronization
- telemetry platforms
- plugin sandboxing layers
- Electron-style extensibility

---

# Architecture

NyxHud uses a split pipeline architecture.

```text
Collectors (Shell/POSIX)
        ↓
nyx-collectord.sh
        ↓
Renderer (Python)
        ↓
X11 overlay window
```

This separation keeps the project:
- modular
- replaceable
- portable
- easier to debug
- easier to audit

Collectors gather data.

The renderer only handles visualization.

The renderer remains intentionally stateless regarding collector logic.

---

# Project Structure

```text
nyxhud/
├── LICENSE
├── README.md
├── README-pt-br.md
└── src
    ├── main
    │   ├── collectors
    │   │   ├── 01_system.sh
    │   │   ├── 02_gpu.sh
    │   │   ├── 03_network.sh
    │   │   ├── 04_wireguard.sh
    │   │   ├── 05_sandbox.sh
    │   │   ├── 06_markets.sh
    │   │   └── 07_diskio.sh
    │   ├── nyx-collectord.sh
    │   └── nyx-renderer.py
    └── start.sh
```

---

# Core Components

## Collectors

Collectors are independent shell modules responsible for retrieving
system information.

Examples:

```text
collectors/
├── 01_cpu.sh
├── 02_gpu.sh
├── 03_memory.sh
├── 04_network.sh
├── 05_wireguard.sh
├── 06_sandbox.sh
├── 07_markets.sh
├── 08_battery.sh
├── 09_diskio.sh
└── 10_weather.sh
```

Collectors should:
- do one thing
- remain simple
- avoid side effects
- avoid unnecessary dependencies
- output structured text
- remain easily auditable

Collectors are intentionally shell-oriented.

The project favors:
- POSIX shell
- awk
- sed
- grep
- coreutils

over large runtime environments.

---

## Collectord

`nyx-collectord.sh` acts as the orchestration layer.

Responsibilities:
- scheduling
- collector execution
- synchronization
- formatting
- caching
- pipeline coordination

The collectord intentionally avoids:
- databases
- complex IPC systems
- dependency-heavy schedulers
- hidden background services
- preserve shell portability whenever reasonable

---

## Renderer

The renderer is implemented in Python and acts strictly as the
visualization layer.

Responsibilities include:
- overlay drawing
- transparency handling
- compositor interaction
- positioning
- rendering
- visual composition

The renderer remains intentionally stateless regarding collector logic.

This separation allows:
- renderer replacement
- future renderer experiments
- easier debugging
- cleaner architecture

---

# Transparency and Compositing

NyxHud supports transparency using lightweight X11 compositors.


Recommended compositor:
- picom (GLX backend)

For correct transparency rendering and shadow exclusion with `nyxhud`, configure `picom`:

```sh
mkdir -p ~/.config/picom/
touch ~/.config/picom/picom.conf
nano ~/.config/picom/picom.conf
```

Add:

```conf
shadow-exclude = [
    "name = 'nyxhud'"
];
```

Initialize with:

```sh
picom --backend glx &
```

This prevents shadow artifacts and enables proper transparency rendering for the HUD window.

---

NyxHud works best with:
- opaque black wallpapers
- minimal compositing
- low-overhead desktops
- lightweight X11 environments

---

# Dependencies

## Core Dependencies

Arch Linux:

```bash
sudo pacman -S \
    bash \
    coreutils \
    grep \
    sed \
    gawk \
    procps-ng \
    iproute2 \
    curl \
    jq \
    python \
    python-gobject \
    gtk3
```

## Font

Recommended primary font:

```text
Iosevka Term 12
```

Official resources:

* [Iosevka Website](https://typeof.net/Iosevka/)
* [Iosevka GitHub Repository](https://github.com/be5invis/Iosevka)

Recommended characteristics:

* monospace
* compact glyph metrics
* terminal-oriented rendering
* low visual noise
* high readability on dark backgrounds

Nerd-font variants are optional and not required.

## Optional Dependencies

Optional packages used by specific collectors:

```bash
sudo pacman -S \
    picom \
    lm_sensors \
    wireguard-tools \
    nvidia-utils \
    firejail
```

| Package | Purpose | Related Module |
|---|---|---|
| picom | Transparency/compositing | renderer |
| lm_sensors | CPU temperature telemetry | system |
| wireguard-tools | WireGuard interface telemetry | wireguard |
| nvidia-utils | NVIDIA GPU telemetry (`nvidia-smi`) | gpu |
| firejail | Sandbox/process isolation telemetry | sandbox |

---

# Installation

Clone repository:

```bash
git clone https://github.com/fm4lloc/nyxhud.git
cd nyxhud
```

Make executable files executable:

```bash
chmod +x ./src/*.sh
chmod +x ./src/main/*.sh
chmod +x ./src/main/*.py
chmod +x ./src/main/collectors/*.sh
```

---

# Running

Start NyxHud:

```bash
./src/start.sh
```

---

# POSIX Compatibility

NyxHud prioritizes POSIX shell compatibility whenever possible.

Goals:
- avoid unnecessary bashisms
- preserve portability
- keep collectors inspectable
- reduce dependency inflation
- maintain predictable behavior
- Shell portability is preferred whenever it does not compromise clarity or maintainability.

Non-POSIX behavior should remain isolated and justified.

---

# Performance

NyxHud is designed to minimize:
- wakeups
- CPU usage
- memory overhead
- unnecessary polling
- runtime complexity

Collectors should:
- cache expensive operations
- avoid infinite loops
- avoid excessive subprocess spawning
- avoid unnecessary parsing layers

The project favors:
- deterministic updates
- low-latency rendering
- low-resource desktop workflows

---

# Security Philosophy

NyxHud follows a defensive engineering model.

Principles:
- no telemetry
- no hidden networking
- no cloud APIs by default
- explicit dependencies
- inspectable collectors
- predictable execution flow

The project is designed to integrate well with:
- hardened kernels
- sandboxed environments
- minimal X11 desktops
- security-oriented Linux systems

---

# Desktop Compatibility

Focused primarily on:
- X11
- lightweight Linux desktops
- Unix-oriented workflows

Target environments:
- BSPWM
- Openbox
- XFCE4
- i3
- DWM
- AwesomeWM

---

# Configuration

NyxHud currently follows a self-contained structure.

Configuration and customization are performed directly through:
- collectors
- renderer logic
- startup scripts

This simplifies:
- deployment
- debugging
- auditing
- portability

The project intentionally avoids:
- complex configuration layers
- plugin frameworks
- dependency-heavy runtime loaders

---

# Customization

Customization can be performed through:
- shell collectors
- renderer parameters
- compositor settings
- startup scripts

Typical modifications:
- transparency
- overlay positioning
- collector intervals
- text formatting
- renderer visuals

---

# Screenshots

![screen1](screenshots/desktop.png)

---

# Open Source

NyxHud is licensed under:

```text
GPL-3.0-or-later
```

This guarantees that:
- forks remain open source
- modifications remain auditable
- derivative works preserve software freedom

---

# Authors

## Fernando Magalhães

fm4lloc@gmail.com
nyx-eco@proton.me

Creator, maintainer and lead developer.

---

## Nyx

Technical collaboration, architecture review
and systems engineering assistance.

# Contributing

Contributions are welcome if they align with the project philosophy.

Preferred contributions:
- performance improvements
- collector optimization
- portability improvements
- renderer cleanup
- X11 tooling
- shell simplification

Avoid:
- unnecessary abstraction
- dependency inflation
- framework-heavy rewrites
- monolithic redesigns

---

# Ecosystem

Planned ecosystem components:

```text
NyxHud
NyxBar
NyxCollectord
```

Future goals:
- improved renderer abstraction
- better caching
- lightweight IPC experiments
- additional X11 tooling
- modular desktop utilities

---

# Final Notes

NyxHud is not intended to become a full desktop environment.

The project focuses on:
- lightweight overlays
- modular information pipelines
- low-level desktop integration
- Unix-oriented workflows
- long-term maintainability

Simplicity is treated as a feature, not a limitation.
