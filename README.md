# Desk Pets MH

Monster Hunter desktop companions for Claude Code and Codex on macOS, built with Swift and AppKit.
Each pet follows a CLI session and animates when it is working, waiting for input, or idle.

- English, Traditional Chinese, and Japanese UI and monster names
- Adjustable animation speed and size, saved automatically
- Drag pets anywhere; double-click to focus their terminal, including tmux panes and cmux tabs
- Import custom GIF characters or add monsters from PNG frames

## Build and install

Requires an Apple Silicon Mac, macOS 14+, Swift 6 (Command Line Tools), and FFmpeg.

```sh
git clone https://github.com/chesterXalan/desk-pets-mh.git
cd desk-pets-mh
brew install ffmpeg
make app
```

Copy `build/DeskPets.app` to `/Applications` and open it.
`make run` builds and opens the app; `make test` runs the tests.

## Use

1. Open **Manage… → Hooks** from the menu bar, install the hooks, and restart your CLI sessions.
2. In **Sessions**, assign a monster to each session. Bindings reconnect when sessions restart in the same directory.
3. Right-click a pet → **Settings…** to choose a language, size, or animation duration.

The language follows macOS by default, with manual English / 繁體中文 / 日本語 selection.
Animation duration applies to a complete loop: four frames at 1.2 seconds means 0.3 seconds per frame.
Settings apply immediately. Turn off the duration override to use each GIF's original timing.

Double-click a pet or choose **Show Terminal** to focus its session. With multiple native Ghostty tabs,
you may still need to select the tab hosting the tmux client.

## Add characters

Use **Characters → Add Character…** to import `idle.gif`, with optional `working.gif` and `waiting.gif`.
To add a built-in monster, see [Character assets](docs/characters.md).
PNG frames and character metadata are versioned; GIFs are generated during the build.

## Local data

Settings, bindings, and imported characters live in `~/Library/Application Support/DeskPets/`.
Hook installation updates `~/.claude/settings.json` and `~/.codex/hooks.json`, preserving existing hooks
and backing up each file before changes. The app does not make network requests.

## Credits

Based on [youngOman/desk-pets](https://github.com/youngOman/desk-pets), inspired by Evan's agent-pets.
Code retains the upstream [MIT license](LICENSE).
Monster Hunter characters belong to CAPCOM; the included artwork is AI-generated fan art.
