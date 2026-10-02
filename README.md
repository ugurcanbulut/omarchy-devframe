# Devframe

An [Omarchy](https://omarchy.org) bar widget for testing websites at real device sizes. Click the icon, pick a device, and the browser on your current workspace becomes a floating window of exactly that size, centered on the screen.

## Features

- **Device presets.** Sizes are logical (CSS) pixels, the size a browser on that device reports.

  | Preset | Size |
  |---|---|
  | Full HD | 1920 × 1080 |
  | MacBook Pro 16" | 1728 × 1117 |
  | MacBook Pro 14" | 1512 × 982 |
  | iPad (11") landscape / portrait | 1180 × 820 / 820 × 1180 |
  | iPad Pro 13" landscape / portrait | 1376 × 1032 / 1032 × 1376 |
  | iPhone 16 Pro | 402 × 874 |
  | iPhone 16 Pro Max | 440 × 956 |

  The preset is the size of the whole browser window, toolbar included. In Chrome the page itself gets 87px less height.

- **Phone sizes.** Chrome can't make a normal window narrower than 500px. For the iPhone presets, Devframe opens the current page in a new toolbar-less window (`--app` mode), so the page gets the full phone size. Logins carry over, and DevTools still work.
- **Incognito.** With the switch on, any preset opens the current page in a new private window at that size instead of resizing your window.
- **DevTools.** With the switch on, DevTools opens in its own window to the right of the browser, at the same height. The two are centered together. When you switch tabs, DevTools switches to the new tab.
- **Workspace.** Buttons 1–10 move the browser and its DevTools to that workspace and take you there, like Super+Shift+number.
- **Reset.** Tiles the browser back into the layout, closes its DevTools, and closes phone windows.

## Install

```bash
omarchy plugin add https://github.com/ugurcanbulut/omarchy-devframe.git --enable
```

The widget is added to the right section of the bar. To move it:

```bash
omarchy bar move ugurcanbulut.devframe --section right --index 0
```

To open the popup from a key binding, bind it to `omarchy-shell ugurcanbulut.devframe toggle`.

## Requirements

- Omarchy 4 (Hyprland with Lua config)
- A Chromium-based default browser. Devframe is tested with Google Chrome.
- `jq`, `socat`, `wtype` and `wl-clipboard`, all part of a standard Omarchy install

## Popup keyboard shortcuts

| Key | Action |
|---|---|
| `1`–`9` | Apply a preset |
| `h` `j` `k` `l` / arrows | Move the cursor |
| `Enter` / `Space` | Activate the selected item |
| `i` | Turn Incognito on or off |
| `d` | Turn DevTools on or off |
| `r` | Reset |
| `Esc` | Close |

Right-clicking the bar icon also turns Incognito on or off.

## Command line

The script behind the widget works on its own too, for example from your own key bindings. It lives at `~/.config/omarchy/plugins/ugurcanbulut.devframe/devframe`:

```bash
devframe 1920 1080 [--incognito] [--devtools]
devframe move 3
devframe reset
```

## How it works, and its limits

Chrome offers no way for a script to talk to an already-running browser, so Devframe drives it through Hyprland and keyboard shortcuts:

- **Reading the page address.** Phone and incognito windows need the current page's address. Devframe briefly copies it from the address bar and then puts your clipboard back. The address still shows up in your clipboard history.
- **Opening DevTools in its own window.** If your DevTools is docked, Devframe undocks it through the DevTools command menu. Reset docks it back. If you close the DevTools window yourself, Chrome keeps opening DevTools as a separate window until you dock it again (Ctrl+Shift+D inside DevTools).
- **Following tabs.** Devframe watches the browser's window title, which changes when you switch tabs. As a result:
  - Switching between tabs with exactly the same title isn't detected.
  - Every switch opens a fresh DevTools for the new tab, so the old tab's console and network history are lost.
  - The inspect-element highlight can flash for a moment when a page changes its title.
- **Sending keys.** Devframe only sends keys while the browser window has focus.

## License

MIT
