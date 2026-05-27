---
title: "Theming"
description: "Accent colors, panel backgrounds, ASCII art, and terminal compatibility"
order: 8
group: "Bashboard"
badge: "STYLE"
---
# Theming Guide
> ⚠️ AI-generated docs — verify against [imsudoer/bashboard](https://github.com/imsudoer/bashboard) before relying on details.
Bashboard uses 256-color ANSI codes for theming. You can change the look
entirely from `~/.sutd/info.conf` — no code edits required.

## The three theme variables

```bash
THEME_ACCENT="208"
THEME_BG="237"
THEME_BG_ENABLED=1
```

| Variable           | Meaning                                       |
|--------------------|-----------------------------------------------|
| `THEME_ACCENT`     | Logo, headers, highlights — the "brand color" |
| `THEME_BG`         | Background of panels (header, footer in menu) |
| `THEME_BG_ENABLED` | `1` to enable backgrounds, `0` to disable     |

## Picking colors

The 256-color palette covers everything from system colors (0–15) to a
6×6×6 RGB cube (16–231) to a grayscale ramp (232–255).

### Quick reference

```
Accent suggestions
  46  matrix green     208  vivid orange  (default)
  75  ocean blue       201  hot pink
  141 lavender         196  red
  220 yellow gold      82   lime
  165 magenta          51   cyan
  214 amber            87   sky blue

Background suggestions (grayscale ramp)
  232  almost black
  234  very dark
  235  dark (subtle)
  237  dark-medium  (default)
  238  medium-dark
  239  medium
  240  medium-light
```

### See all colors in your terminal

Save as `colors.sh` and run:

```bash
#!/bin/bash
for i in {0..255}; do
    printf "\033[38;5;${i}m %3d \033[0m" "$i"
    (( (i+1) % 16 == 0 )) && echo ""
done
```

Or one-liner:

```bash
for i in {0..255}; do printf "\e[38;5;${i}m%4d\e[0m" "$i"; (( (i+1) % 16 == 0 )) && echo; done
```

## Preset themes

Copy any of these into `info.conf`:

### Default (orange)
```bash
THEME_ACCENT="208"
THEME_BG="237"
THEME_BG_ENABLED=1
```

### Matrix
```bash
THEME_ACCENT="46"
THEME_BG="234"
THEME_BG_ENABLED=1
```

### Ocean
```bash
THEME_ACCENT="75"
THEME_BG="236"
THEME_BG_ENABLED=1
```

### Cyber pink
```bash
THEME_ACCENT="201"
THEME_BG="235"
THEME_BG_ENABLED=1
```

### Solarized-ish dark
```bash
THEME_ACCENT="136"
THEME_BG="235"
THEME_BG_ENABLED=1
```

### Dracula
```bash
THEME_ACCENT="141"
THEME_BG="236"
THEME_BG_ENABLED=1
```

### Minimal (no backgrounds)
```bash
THEME_ACCENT="208"
THEME_BG_ENABLED=0
```

### Monochrome (terminal-default look)
```bash
THEME_ACCENT="15"
THEME_BG_ENABLED=0
```

## Where colors are used

| Element                       | Color                  |
|-------------------------------|------------------------|
| ASCII logo                    | `$COLOR_ACCENT`        |
| Slide titles                  | `$COLOR_ACCENT`        |
| Selected item in TUI sidebar  | `$COLOR_ACCENT`        |
| Help center headers           | `$COLOR_ACCENT`        |
| `field` labels                | `$COLOR_WHITE`         |
| `field` separator             | `$COLOR_WHITE` `:`     |
| Dividers                      | `$COLOR_GRAY`          |
| Service status (active)       | `$COLOR_GREEN`         |
| Service status (failed)       | `$COLOR_RED`           |
| Service status (other)        | `$COLOR_YELLOW`        |
| SSL cert (>14 days)           | `$COLOR_GREEN`         |
| SSL cert (<14 days)           | `$COLOR_YELLOW`        |
| SSL cert (expired)            | `$COLOR_RED`           |
| Progress bars (<70%)          | `$COLOR_GREEN`         |
| Progress bars (70–90%)        | `$COLOR_YELLOW`        |
| Progress bars (>90%)          | `$COLOR_RED`           |
| Prompt arrow (last cmd ok)    | `$COLOR_GREEN`         |
| Prompt arrow (last cmd fail)  | `$COLOR_RED`           |
| Prompt git branch (clean)     | `$COLOR_GREEN`         |
| Prompt git branch (dirty)     | `$COLOR_ACCENT`        |
| Prompt timing tag             | `$COLOR_YELLOW`        |

## Custom ASCII art

The logo is hard-coded in three places (because each interface needs a
slightly different version):

- `motd.sh` — plain MOTD mode
- `menu.sh` — slides mode
- `terminal/tui.sh` — TUI mode (compact, with proper escaping for `tput`)

To change the logo, edit those files. Use ASCII art generators:

- [patorjk.com/software/taag](http://patorjk.com/software/taag/) — text-to-ASCII
- [manytools.org/hacker-tools/ascii-banner](https://manytools.org/hacker-tools/ascii-banner/)

Recommended fonts that fit the standard logo dimensions:
- **Standard** — readable but tall
- **Slant** — used by default
- **Big** — bold and visible
- **Small** — for narrow terminals

### Logo embedding pattern

Inside a script, use a heredoc with `'EOF'` (quoted) to prevent variable
expansion in the art:

```bash
echo -e "${COLOR_ACCENT}"
cat << 'EOF'
  __  __         _                  
 |  \/  |_   _  | |    ___   __ _  ___ 
 | |\/| | | | | | |   / _ \ / _` |/ _ \
 | |  | | |_| | | |__| (_) | (_| | (_) |
 |_|  |_|\__, | |_____\___/ \__, |\___/
         |___/              |___/    
EOF
echo -e "${COLOR_RESET}"
```

If your art contains `$`, backticks, or backslashes, the quoted heredoc
keeps them literal.

## Custom color schemes for modules

Inside your own module, you can use any 256-color directly:

```bash
#!/bin/bash

PINK="\033[38;5;213m"
BLUE_BG="\033[48;5;24m"
RESET="\033[0m"

echo -e "  ${PINK}Custom color${RESET}"
echo -e "  ${BLUE_BG}With background${RESET}"
```

But for consistency, **prefer the shared palette** so a global theme
change affects your module too.

### Theme-aware modules

If you want your module to react to the active theme:

```bash
#!/bin/bash

if [ "${THEME_ACCENT:-208}" = "46" ]; then
    # matrix theme detected
    SUBTITLE_COLOR="\033[38;5;82m"
else
    SUBTITLE_COLOR="${COLOR_ACCENT}"
fi

echo -e "  ${SUBTITLE_COLOR}subtitle${COLOR_RESET}"
```

## Panel backgrounds

When `THEME_BG_ENABLED=1`, the `panel` function (used by `menu.sh`) paints
a background across the entire terminal width.

```bash
panel "  Some content here"
```

This writes the line, then pads with spaces of the same background color
to terminal width. Useful for visual sections.

The function strips ANSI codes from the input before calculating width,
so your colored text won't break alignment.

## Disabling colors entirely

Some terminals don't support 256-color. To force everything to plain text,
set in `info.conf`:

```bash
# Force basic colors only
COLOR_ACCENT=""
COLOR_BG=""
COLOR_BG_RESET=""
```

Better: use a monochrome theme above. Bashboard always uses 256-color
defaults for non-theme colors (green/red/yellow), so the dashboard remains
readable but loses the brand color.

## Terminal compatibility

Tested terminals:

| Terminal           | 256-color | Background | Notes                       |
|--------------------|-----------|------------|-----------------------------|
| GNOME Terminal     | ✓         | ✓          | Full support                |
| iTerm2 (macOS)     | ✓         | ✓          | Full support                |
| Alacritty          | ✓         | ✓          | Full support                |
| Kitty              | ✓         | ✓          | Full support                |
| Windows Terminal   | ✓         | ✓          | Full support                |
| PuTTY              | ✓         | ✓          | Need to enable in settings  |
| screen             | partial   | partial    | Use `screen-256color`       |
| tmux               | ✓         | ✓          | Set `tmux -2`               |
| Linux console (TTY)| ✗         | partial    | Falls back to basic colors  |

If your terminal shows weird characters instead of colors, set in
`info.conf`:

```bash
THEME_BG_ENABLED=0
```

And check that `$TERM` reports a 256-color value:

```bash
echo $TERM       # should be xterm-256color, screen-256color, or similar
```

If not, fix in your SSH config or `.bashrc`:

```bash
export TERM=xterm-256color
```