# Desk Pets · 魔物桌寵

本機魔改版：八隻《魔物獵人》角色、手動播放速度與 tmux 切換
完整操作與版控安排請看 [本機魔物版說明](docs/monster-fork.md)

Little pixel pets that sit on your macOS desktop. Each pet is bound to one Claude Code or Codex
session and shows at a glance whether that session is **working**, **waiting for you**, or **idle**.

原生 Swift／AppKit 選單列程式，動畫由 Core Animation 播放
內建雷狼龍、泡狐龍、迅龍、滅盡龍、火龍、冰呪龍、天彗龍與轟龍，全部採用四幀版動作

## Features

- Menu bar app with no Dock icon: **Show Pets**, **Manage…**, **Launch at Login**, **Quit**.
- One borderless, always-on-top pet per session, visible on every Space and over full-screen apps.
  Drag it anywhere and the position is remembered.
- Hover a pet to see the session name and state. Double-click it to bring the session's terminal app
  to the front; in [cmux](https://cmux.dev) it also switches to the session's workspace and tab.
  Right-click it to change the character or unbind it.
- Sessions get readable names: the `/rename` title, else the cmux tab title, else Claude's
  auto-generated title, else `folder · pid`. Transcripts are read from the end in small chunks and
  cached, so even 100 MB transcripts cost almost nothing.
- Finds `claude` and `codex` sessions with `sysctl`/`libproc` every 2.5 s, without forking `ps`.
- State comes from Claude Code / Codex hooks, pushed to the app through a watched folder (no polling).
- Bindings follow a session across restarts: same CLI + same working directory re-attaches automatically.
- 支援匯入自訂 GIF，內建角色已換成八隻魔物
- 右鍵魔物 →「設定…」可調整播放時間、大小與顯示狀態，設定會立即生效並保存

| State | Meaning | Hook events |
| --- | --- | --- |
| working | the agent is busy | `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PreCompact` |
| waiting | needs your reply or approval | `Notification` (permission / idle prompt), `PermissionRequest` |
| idle | finished its turn | `Stop`, `SessionStart` |
| unknown | no hooks installed, so the pet plays its idle animation | – |

## 建置與安裝

此分支請從原始碼建置，上游 Releases 不包含本機魔改功能
需要 Apple Silicon Mac、macOS 14+、Swift 6（Command Line Tools 即可）與 FFmpeg

```sh
brew install ffmpeg
make app          # 產生 build/DeskPets.app
make run          # 建置並開啟
make test         # 程式測試
make sprites      # 將四幀 PNG 組成 GIF，輸出到 .build/Characters
```

將 `build/DeskPets.app` 放進「應用程式」即可使用

## Install the hooks

本機魔改版支援雙擊桌寵或右鍵「切到終端機」定位 tmux pane：
依 session 的 `TMUX`／`TMUX_PANE` 找到 socket 與 pane，優先使用已連到該 session 的本機終端 client，
切換 window／pane 後喚起終端 App。純 control client、未連線或沒有本機終端 App 的 client 不會被選中。
這不會修改 tmux 設定或重啟 server；終端 App 有多個原生分頁時，仍需手動選到承載該 client 的分頁。

Without hooks every pet shows *unknown*. To get live states:

1. Click the paw icon in the menu bar → **Manage…** → **Hooks** → **Install Hooks**.
2. Restart your Claude Code / Codex sessions so they load the new hooks.

This merges a few entries into `~/.claude/settings.json` and `~/.codex/hooks.json`. Your existing hooks
are kept, and each file is backed up as `settings.json.deskpets-<time>.bak` before it is changed.
**Remove Hooks** takes out only the Desk Pets entries.

You can do the same thing from a terminal:

```sh
/Applications/DeskPets.app/Contents/MacOS/deskpets-hook install            # or: uninstall
/Applications/DeskPets.app/Contents/MacOS/deskpets-hook install --home /tmp/test-home   # try it on a scratch HOME
/Applications/DeskPets.app/Contents/MacOS/deskpets-hook list               # detected sessions and states
/Applications/DeskPets.app/Contents/MacOS/deskpets-hook pets hide          # or: show
```

The hook command points to the app's current location. If you move the app, run **Install Hooks** again.
Codex may also need hooks turned on in its own config. Check the Codex docs for your version.

## Custom characters

A character is a folder of GIFs:

| File | Required | Played when |
| --- | --- | --- |
| `idle.gif` | yes | idle or unknown |
| `working.gif` | no (falls back to idle) | working |
| `waiting.gif` | no (falls back to idle) | waiting |

In **Manage… → Characters → Add Character…**, give it a name and choose one to three GIFs, or drop them
into the sheet (files named `idle`/`working`/`waiting` go to the right slot). They are copied to
`~/Library/Application Support/DeskPets/characters/<name>/`. You can also drop a folder there
yourself, or run:

```sh
/Applications/DeskPets.app/Contents/MacOS/DeskPets import-character Mochi idle.gif working.gif waiting.gif
```

Pets are drawn at 64, 96 or 128 px (pick one in the manager). Pixel art is scaled without smoothing,
so small sprites stay crisp.
內建魔物只版控每種動作的四張 PNG，GIF 於建置時產生，詳見 [素材與建置說明](docs/monster-fork.md#版控範圍)

本機魔改版支援在角色資料夾放置 `character.json`，例如 `{"displayScale":1.2}`，
讓該角色以所選尺寸的 1.2 倍顯示，保留 GIF 原圖、透明邊界與完整翅膀。
有效倍率為 0.5–2，未提供或格式無效時使用 1 倍。透過匯入視窗加入 GIF 後，需另行放入此檔；
直接複製整個角色資料夾則會一併保留倍率。編輯倍率後重新啟動 Desk Pets 即可套用。

## Privacy

Desk Pets never touches the network. Everything stays on your Mac:

- The hook writes only metadata (CLI, session id, event name, state, working directory, pid) to
  `~/Library/Application Support/DeskPets/sessions/`. Prompts, tool input, and output are never stored.
- Settings live in `~/Library/Application Support/DeskPets/config.json`.
- The only files outside that folder it changes are the two hook config files, and only when you
  click Install/Remove Hooks.

## 上游效能參考（原版素材）

Measured on an Apple Silicon Mac with 17 live sessions (`ps -o %cpu,rss`, averaged over 30 s):

| | |
| --- | --- |
| App size | ~0.8 MB |
| Launch → menu bar icon | ~150–450 ms |
| 3 pets animating | ~0.1% CPU, ~51 MB RSS |
| Pets hidden | ~0.1% CPU (the 2.5 s session scan) |

Animations run as Core Animation keyframes, so the app does no per-frame work. Animations stop
while a pet is hidden or fully covered.

## Acknowledgements

Inspired by agent-pets, made by my great coworker Evan.

## License

程式碼沿用 MIT © youngOman，見 [LICENSE](LICENSE)
魔物角色設定來自 CAPCOM《魔物獵人》，生成素材來源見 [素材說明](docs/monster-fork.md#素材來源)

---

## 繁體中文說明

Desk Pets 是一個 macOS 選單列小工具，在桌面上放幾隻像素小寵物。每隻寵物綁一個 Claude Code 或 Codex session，
一眼就能看出它是「工作中」、「等你回覆」還是「閒置」。原生 Swift／AppKit 寫成，動畫由 Core Animation 播放

**安裝**：執行 `make app`，將 `build/DeskPets.app` 放入「應用程式」
**設定**：右鍵魔物 →「設定…」，可手動調整一輪時間、大小與顯示狀態

**安裝 hooks**：選單列的爪子圖示 →「管理…」→「Hooks」→「安裝 hooks」，然後重開 session。
程式會把設定合併進 `~/.claude/settings.json` 和 `~/.codex/hooks.json`，保留你原本的 hooks，
修改前備份成 `*.deskpets-<時間>.bak`。「移除 hooks」只會拿掉 Desk Pets 自己的項目。

**自訂角色**：「管理…」→「角色」→「新增角色…」，取名後選一到三張 GIF（也可以直接拖進來）：
`idle.gif` 必填；`working.gif`、`waiting.gif` 可以不給，沒給就用 idle。
可以調整顯示大小（64／96／128 px），也可以刪除自訂角色。

**操作**：拖曳寵物可以移動，位置會記住；滑鼠移上去會顯示 session 名稱和狀態；
雙擊會把那個 session 所在的終端機叫到前景（在 cmux 裡會直接切到那個分頁）；右鍵可以換角色或解除綁定。
session 名稱依序取：`/rename` 取的名字 → cmux 分頁標題 → Claude 自動產生的標題 → 「資料夾 · pid」。
session 重開後 pid 會變，只要是同一個 CLI、同一個工作目錄，寵物會自動接回去。

**隱私**：完全在本機讀寫，不連網。hook 只記錄 session id、事件、狀態、工作目錄、pid 這些資訊，
不會記錄你的對話內容。

**致謝**：靈感來自好同事 Evan 的 agent-pets。
