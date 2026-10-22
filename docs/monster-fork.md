# 本機魔物版

此版本以 `youngOman/desk-pets` 為基礎，保留上游 MIT 程式碼授權與作者資訊
內建角色改為雷狼龍、泡狐龍、迅龍、滅盡龍、火龍、冰呪龍、天彗龍、轟龍

## 手動調整

右鍵任一魔物 →「設定…」，或選單列腳印 →「管理…」→「設定」

- 顯示／隱藏所有寵物
- 基準大小：64、96、128 px，各角色再套用自己的大小校正
- 自訂動畫一輪時間：0.4–6.0 秒，每次調整 0.1 秒，立即生效並自動儲存
- 快選：1.2、1.6、2.0、2.4 秒

所有角色、所有狀態共用一輪時間，秒數越小越快
目前採用四幀，所以一輪 1.2 秒表示每幀 0.3 秒；一輪 1.6 秒表示每幀 0.4 秒
關閉自訂時間時，使用 GIF 本身的時間；舊設定檔也沿用 GIF 原本時間
改速度不需要重新產生、匯入或提交圖片

設定儲存在 `~/Library/Application Support/DeskPets/config.json`，`animationDuration` 表示一輪秒數
這是個人執行資料，含 session 綁定與工作目錄，不放進 repo

## 版控範圍

| 路徑 | 內容 |
| --- | --- |
| `Sources/`、`Tests/` | 程式碼與測試 |
| `Resources/Characters/` | 八隻角色 × 三種動作 × 四張 PNG，共 96 張，以及大小校正 |
| `tools/build-monsters.swift` | PNG 組成 GIF 的建置工具 |

每種動作使用 `<角色>/<idle 或 working 或 waiting>/0.png` 至 `3.png`，尺寸為 256 × 256
PNG 是唯一需要版控的角色圖片；分格原稿、歷次試作與備份留在 repo 外
先安裝 FFmpeg（`brew install ffmpeg`），再執行 `make app`，會自動將 PNG 組成 GIF 並打包
也可用 `make sprites` 單獨產生 `.build/Characters/`，不需要重新生圖
GIF 為建置產物，保留在 `.build/` 與 App 內，不需要版控
`.app`、ZIP、`.build/`、`build/` 也不放進 Git
舊三隻角色與其產圖工具已移除

公開倉庫：[chesterXalan/desk-pets-mh](https://github.com/chesterXalan/desk-pets-mh)
`origin` 指向魔改版倉庫；原作者的 [youngOman/desk-pets](https://github.com/youngOman/desk-pets) 作為 `upstream`，供追蹤上游更新

## 終端切換

雙擊魔物，或右鍵「切到終端機」
tmux 會定位對應 session／window／pane，再喚起本機終端 App
Ghostty 多個原生分頁之間仍可能需要手動切到承載該 tmux client 的分頁

## 素材來源

魔物角色設定屬於 CAPCOM《魔物獵人》系列，圖片為生成的同人素材
上游程式碼的 MIT 授權不代表取得 CAPCOM 角色設定的權利
