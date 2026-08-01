# APP_NAME_PLACEHOLDER (macOS)

## Spustenie

```bash
npm install
npm start
```

## Build .dmg / .zip

```bash
npm run dist
```

Vystupne subory budu v `dist/`.

## Distribucia — bez auto-update (zatial)

`build.sh` po zbuildovani nahra `.dmg`/`.zip`/`.blockmap` na
`residomac.vorntech.sk` (SFTP, fallback IP `37.9.175.196`, port 22) — je to
teda jedno miesto, odkial sa da najnovsia verzia stiahnut, ale appka sama od
seba nekontroluje ani neaplikuje aktualizacie (na rozdiel od Windows klienta).
Ziadny `electron-updater`, ziadne tlacidlo "Skontrolovat aktualizacie".
Novu verziu treba nainstalovat rucne (stiahnut novy `.dmg` z
residomac.vorntech.sk, nahradit appku v `/Applications`).

Ked to bude potrebne, auto-update sa da doplnit rovnako ako na Windows:
pridat `electron-updater` zavislost, `publish` sekciu do `package.json`
(build), update-check kod do `src/main.js` a generovanie `latest-mac.yml`
pri kazdom builde. Bude navyse potrebne appku podpisat Apple Developer ID
certifikatom a notarizovat — Squirrel.Mac (na com auto-update na macOS
stoji) odmieta aplikovat update na nepodpisanu appku.

## Nepodpisana appka — Gatekeeper

Kedze appka nie je podpisana Apple Developer ID certifikatom ani
notarizovana, macOS Gatekeeper pri prvom spusteni z `.dmg`/`.zip` zahlasi,
ze appku "nie je mozne overit". Na prvom spusteni je potrebne:

1. Presunut `APP_NAME_PLACEHOLDER.app` do `/Applications`.
2. V Doku/Finderi kliknut pravym tlacidlom na appku a zvolit **Otvorit**
   (namiesto dvojkliku) — potvrdit dialog.

Prípadne z terminalu odstranit quarantine flag rucne:

```bash
xattr -cr "/Applications/APP_NAME_PLACEHOLDER.app"
```

## Tlacenie

Kazdy slot (blociky + 4 bonovacky) sa vybera explicitne v Nastaveniach —
neexistuje rezim "systemova predvolena tlaciaren". Pre kazdy slot sa da
zapnut RAW ESC/POS rezim (predvolene zapnuty): stranka blocika sa vyrenderuje
off-screen, rasterizuje presne na sirku papiera (203 dpi) a posle sa do CUPS
ako raw job (`lp -o raw`), cim sa uplne obide ovladac tlaciarne. Pre bezne
kancelarske/A4 tlaciarne treba RAW vypnut.

Diagnostika tlace sa zapina skratkou `Cmd+Shift+L` — log sa zobrazuje
v Nastaveniach a zapisuje do `print-log.txt` v datovom priecinku appky.

## Predvolene nastavenie

Aplikacia sa pripaja na adresu nakonfigurovanu v nastaveniach (obrazovka sa
zobrazi automaticky, kym adresa servera nie je nastavena, alebo cez tlacidlo
"Nastavenia" v pravom hornom rohu).
