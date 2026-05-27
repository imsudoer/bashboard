---
title: "Bashboard Documentation"
description: "Modular bash dashboard, MOTD, and shell-augmentation framework — start here"
order: 0
group: "Bashboard"
badge: "HOME"
---

> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.

# Bashboard — Documentation

> Modular bash dashboard, MOTD, and shell-augmentation framework.

Welcome to the full reference documentation for Bashboard. Whether you're
trying to install it for the first time, write your own dashboard module,
or just looking up how a specific command works — start here.

## Documentation map

### Beginner

1. **[Getting Started](#module:01-getting-started)** — installation, first run, basic concepts
2. **[Configuration](#module:02-configuration)** — `info.conf`, themes, interface modes
3. **[Commands Reference](#module:09-commands-reference)** — every command at a glance
4. **[Keybindings](#module:10-keybindings)** — all keyboard shortcuts

### Intermediate

5. **[Architecture](#module:03-architecture)** — directory layout, load order, lifecycle
6. **[Theming](#module:08-theming)** — accent colors, panels, custom ASCII art
7. **[Data Storage](#module:07-data-storage)** — where state lives and how to back it up

### Advanced (writing your own)

8. **[Modules](#module:04-modules)** — how to write dashboard modules
9. **[Terminal Extensions](#module:05-terminal-extensions)** — how to write shell tools
10. **[Library API](#module:06-lib-api)** — helper functions available to your code

### Guides

- [Add a Custom Module](#module:add-custom-module)
- [Add a Terminal Tool](#module:add-terminal-tool)
- [Telegram Notifications](#module:telegram-notifications)
- [Multi-Server SSH Workflow](#module:ssh-multi-server)
- [Per-Project Configuration](#module:per-project-setup)
- [Troubleshooting](#module:troubleshooting)
- [Performance Tuning](#module:performance-tuning)

## Quick links

- **Installed at**: `~/.sutd/`
- **Main config**: `~/.sutd/info.conf`
- **Module dir**: `~/.sutd/modules/`
- **Terminal extensions**: `~/.sutd/terminal/`
- **State files**: `~/.sutd/data/`

## Philosophy

Bashboard follows three principles:

**1. Zero hard dependencies.** Everything works with `bash`, `coreutils`,
`awk`, `sed`, `grep`. Optional features (SSL parsing, QR codes, JSON view)
degrade gracefully when their tools are missing.

**2. Modules are isolated.** A failing module never breaks the dashboard.
Each runs in its own subshell. You can write one in 5 minutes.

**3. Config over code.** Almost everything is a toggle in `info.conf`.
Want different colors? One variable. Disable a module? One variable.

## Getting help

- Run `helpme` for the interactive help center
- Run `helpme -w` to browse docs in your web browser
- Read [Troubleshooting](#module:troubleshooting) for common issues

## Version

This documentation reflects Bashboard as of **2026-05-27**.
