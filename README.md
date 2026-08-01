# Resido — macOS klient

Electron shell nad webovou aplikáciou Resido pre macOS: načíta
`<server>/resido/` a tlačí bločky a bony potichu.

## Build a vydanie novej verzie

```
script/build.sh
```

Podrobnosti: `script/instal.txt`.

## Štruktúra

| Cesta | Obsah |
|---|---|
| `script/resido.sh` | generátor projektu — kopíruje zdrojáky z `script/assets/` |
| `script/assets/` | zdroj klienta: `main.js`, `preload.js`, `offline.html`, README, ikona |
| `script/build.sh` | release: verzia → build → upload |
| `script/.env` | `RESIDO_CLIENT_VERSION` |

## Tlačenie

Rovnaký prístup ako Windows klient: každý slot (bločky + 4 bonovačky) sa
vyberá explicitne, pre každý sa dá zapnúť RAW ESC/POS režim (predvolene
zapnutý) — stránka sa rasterizuje presne na šírku papiera a pošle sa do CUPS
ako raw job (`lp -o raw`), čím sa obíde ovládač tlačiarne. Diagnostika tlače
sa zapína skratkou `Cmd+Shift+L`.
