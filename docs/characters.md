# Character assets

Built-in monsters use stable, lowercase English folder IDs. Display names belong in metadata,
so changing the UI language does not change session bindings.

```text
Resources/Characters/zinogre/
├── character.json
├── idle/       # 0.png, 1.png, 2.png, 3.png
├── working/    # 0.png, 1.png, 2.png, 3.png
└── waiting/    # 0.png, 1.png, 2.png, 3.png
```

Each action has four 256 × 256 PNG frames with transparent backgrounds.
Use a consistent position and scale across frames to avoid jitter.

```json
{
  "displayScale": 1.0,
  "names": {
    "en": "Zinogre",
    "zh-Hant": "雷狼龍",
    "ja": "ジンオウガ"
  },
  "aliases": ["雷狼龍"]
}
```

- `displayScale`: multiplier for the selected pet size, from 0.5 to 2; defaults to 1.
- `names`: localized labels; missing translations fall back to English, then the folder ID.
- `aliases`: previous folder IDs for built-in characters. Existing bindings migrate automatically;
  new characters can omit this field. Keep aliases unique and avoid other character IDs.

Add a folder with this layout and run `make app`. No character list is hard-coded.
`make sprites` only generates `.build/Characters/`; `make app` also bundles the results.
Generated GIFs use a 1.6-second loop, which the app can override without rebuilding images.
Do not commit GIFs, app bundles, ZIPs, drafts, or local session data.

UI translations live in `Resources/{en,zh-Hant,ja}.lproj/Localizable.strings`.
Keep keys and format placeholders consistent across languages; `make test` checks them.
