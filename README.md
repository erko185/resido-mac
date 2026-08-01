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
| `script/resido.sh` | generátor projektu (main.js, preload.js, nastavenia) |
| `script/build.sh` | release: verzia → build → upload |
| `script/.env` | `RESIDO_CLIENT_VERSION` |
