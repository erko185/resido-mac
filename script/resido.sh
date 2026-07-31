#!/usr/bin/env bash
# macOS counterpart of windows_app_script/script/resido.ps1 — generates the
# resido-client Electron project, configured to package as a .dmg/.zip for
# macOS instead of an NSIS .exe for Windows.
#
# No auto-update support yet (no electron-updater, no publish/update-server
# config, no "Skontrolovat aktualizacie" button) — build.sh still uploads
# the built .dmg/.zip to residomac.vorntech.sk so there is one place to
# download the latest build from, but installed apps do not check for or
# apply updates on their own. Auto-update can be added later the same way
# the Windows client has it, once the app is signed with an Apple Developer
# ID certificate (Squirrel.Mac, which electron-updater uses on macOS,
# refuses to apply updates to an unsigned app).
# Re-exec in proper bash mode if invoked as `sh resido.sh` — on macOS /bin/sh
# IS bash, just started in restricted POSIX mode (BASH_VERSION is still set
# there, so that alone can't be used to detect it; POSIXLY_CORRECT is what
# actually flips on), which breaks this script's bash-only syntax (process
# substitution, arrays).
if [ -n "${POSIXLY_CORRECT:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read APP_NAME from .env (look two levels up from script = project root, then
# fall back to the script's own .env), same lookup order as resido.ps1.
# NOTE: the project root .env exists (Laravel's own .env) but does not
# contain APP_NAME/RESIDO_CLIENT_VERSION for this script's purposes in a
# way that matters here — keep checking later candidates until one of them
# actually contains the line, instead of stopping at the first .env that
# merely exists.
app_name="Resido"
for candidate in "$SCRIPT_DIR/../../.env" "$SCRIPT_DIR/.env"; do
  if [ -f "$candidate" ]; then
    line="$(grep -m1 '^APP_NAME=' "$candidate" || true)"
    if [ -n "$line" ]; then
      app_name="$(echo "$line" | sed -E "s/^APP_NAME=['\"]?([^'\"]+)['\"]?\$/\1/")"
      break
    fi
  fi
done
if [ -n "${APP_NAME:-}" ]; then
  app_name="$APP_NAME"
fi

# Read RESIDO_CLIENT_VERSION the same way, so a release bump is a one-line
# .env edit instead of hunting for the hardcoded literal in this script.
client_version="3.5.0"
for candidate in "$SCRIPT_DIR/../../.env" "$SCRIPT_DIR/.env"; do
  if [ -f "$candidate" ]; then
    line="$(grep -m1 '^RESIDO_CLIENT_VERSION=' "$candidate" || true)"
    if [ -n "$line" ]; then
      client_version="$(echo "$line" | sed -E "s/^RESIDO_CLIENT_VERSION=['\"]?([^'\"]+)['\"]?\$/\1/")"
      break
    fi
  fi
done
if [ -n "${RESIDO_CLIENT_VERSION:-}" ]; then
  client_version="$RESIDO_CLIENT_VERSION"
fi

app_slug="$(echo "$app_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g' | sed -E 's/^-+|-+$//g')"

project_name="resido-client"
root="$(pwd)/$project_name"

mkdir -p "$root/src" "$root/assets"

# Copy pre-built icon from script assets
icon_src="$SCRIPT_DIR/assets/icon.icns"
icon_dst="$root/assets/icon.icns"
if [ -f "$icon_src" ]; then
  cp "$icon_src" "$icon_dst"
  echo "  ikona skopirovana: assets/icon.icns"
else
  echo "  VAROVANIE: icon.icns nenajdeny v $icon_src — vloz ho rucne do assets/" >&2
fi

cat > "$root/package.json" <<JSON
{
  "name": "resido-client",
  "version": "$client_version",
  "description": "$app_name desktop klient pre manazment",
  "main": "src/main.js",
  "author": "Resido",
  "license": "MIT",
  "scripts": {
    "start": "electron .",
    "dist": "CSC_IDENTITY_AUTO_DISCOVERY=false electron-builder --mac dmg zip"
  },
  "dependencies": {
    "electron-store": "^8.2.0"
  },
  "devDependencies": {
    "electron": "^37.2.0",
    "electron-builder": "26.15.0"
  },
  "build": {
    "appId": "sk.efabrica.resido",
    "productName": "$app_name",
    "asar": false,
    "icon": "assets/icon.icns",
    "directories": {
      "output": "dist"
    },
    "files": [
      "src/**/*",
      "assets/**/*",
      "package.json"
    ],
    "mac": {
      "target": ["dmg", "zip"],
      "icon": "assets/icon.icns",
      "category": "public.app-category.business",
      "hardenedRuntime": false,
      "gatekeeperAssess": false
    },
    "dmg": {
      "artifactName": "$app_slug-setup-\${version}.dmg"
    }
  }
}
JSON

cat > "$root/src/main.js" <<'EOF'
const { app, BrowserWindow, ipcMain, shell } = require('electron');
const path = require('path');
const Store = require('electron-store');

let store;
let mainWindow;

async function listAvailablePrinters() {
  if (!mainWindow || mainWindow.isDestroyed()) {
    return [];
  }

  try {
    return await mainWindow.webContents.getPrintersAsync();
  } catch {
    return [];
  }
}

function getDefaultPrinterName(printers) {
  const defaultPrinter = printers.find(printer => printer.isDefault);

  return defaultPrinter ? defaultPrinter.name : '';
}

async function resolvePrinterName() {
  const printers = await listAvailablePrinters();
  const savedPrinter = store.get('printer', '');

  if (savedPrinter && printers.some(printer => printer.name === savedPrinter)) {
    return savedPrinter;
  }

  const defaultPrinterName = getDefaultPrinterName(printers);

  if (defaultPrinterName) {
    store.set('printer', defaultPrinterName);
  }

  return defaultPrinterName;
}

async function resolvePrinter2Name() {
  const saved = store.get('printer2', '');

  if (!saved) {
    return '';
  }

  const printers = await listAvailablePrinters();

  return printers.some(p => p.name === saved) ? saved : '';
}

async function resolvePrinter3Name() {
  const saved = store.get('printer3', '');

  if (!saved) {
    return '';
  }

  const printers = await listAvailablePrinters();

  return printers.some(p => p.name === saved) ? saved : '';
}

async function resolvePrinter4Name() {
  const saved = store.get('printer4', '');

  if (!saved) {
    return '';
  }

  const printers = await listAvailablePrinters();

  return printers.some(p => p.name === saved) ? saved : '';
}

async function resolvePrinter5Name() {
  const saved = store.get('printer5', '');

  if (!saved) {
    return '';
  }

  const printers = await listAvailablePrinters();

  return printers.some(p => p.name === saved) ? saved : '';
}

function isValidHttpUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'http:' || url.protocol === 'https:';
  } catch {
    return false;
  }
}

function isInternalAppUrl(urlToOpen) {
  const serverUrl = store.get('serverUrl');

  if (!isValidHttpUrl(serverUrl) || !isValidHttpUrl(urlToOpen)) {
    return false;
  }

  try {
    const appOrigin = new URL(serverUrl).origin;
    const targetOrigin = new URL(urlToOpen).origin;

    return appOrigin === targetOrigin;
  } catch {
    return false;
  }
}

function configureNoCacheSession() {
  if (!mainWindow || mainWindow.isDestroyed()) {
    return;
  }

  const session = mainWindow.webContents.session;
  if (session.__hotelNoCacheConfigured) {
    return;
  }

  session.__hotelNoCacheConfigured = true;
  session.webRequest.onBeforeSendHeaders((details, callback) => {
    const headers = {
      ...details.requestHeaders,
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      Pragma: 'no-cache',
      Expires: '0'
    };

    callback({ requestHeaders: headers });
  });
}

function openSettingsScreen() {
  if (!mainWindow || mainWindow.isDestroyed()) {
    return;
  }

  mainWindow.loadFile(path.join(__dirname, 'offline.html')).catch(() => {});
}

function injectAppButtonsIfNeeded() {
  if (!mainWindow || mainWindow.isDestroyed()) {
    return;
  }

  const currentUrl = mainWindow.webContents.getURL();

  if (!isInternalAppUrl(currentUrl)) {
    return;
  }

  mainWindow.webContents.executeJavaScript(`
    (() => {
      const isPrintLikePage = /\\/(receipt|print(er)?)(\\/|$)/.test(window.location.pathname);
      const existingBackButton = document.getElementById('hotel-client-back-btn');
      let settingsButton = document.getElementById('hotel-client-settings-btn');

      if (!settingsButton) {
        settingsButton = document.createElement('button');
        settingsButton.id = 'hotel-client-settings-btn';
        settingsButton.type = 'button';
        settingsButton.textContent = 'Nastavenia';
        settingsButton.style.position = 'fixed';
        settingsButton.style.top = '14px';
        settingsButton.style.right = '134px';
        settingsButton.style.zIndex = '2147483647';
        settingsButton.style.padding = '10px 14px';
        settingsButton.style.border = '1px solid rgba(15, 23, 42, 0.18)';
        settingsButton.style.borderRadius = '10px';
        settingsButton.style.background = '#ffffff';
        settingsButton.style.color = '#0f172a';
        settingsButton.style.fontWeight = '700';
        settingsButton.style.fontSize = '14px';
        settingsButton.style.cursor = 'pointer';
        settingsButton.style.boxShadow = '0 6px 18px rgba(15, 23, 42, 0.16)';
        settingsButton.addEventListener('click', () => {
          if (window.reservationClient && typeof window.reservationClient.openSettings === 'function') {
            window.reservationClient.openSettings();
          }
        });
        document.body.appendChild(settingsButton);
      }

      if (!isPrintLikePage) {
        if (existingBackButton) existingBackButton.remove();
        return;
      }

      if (existingBackButton) {
        return;
      }

      const btn = document.createElement('button');
      btn.id = 'hotel-client-back-btn';
      btn.type = 'button';
      btn.textContent = '<';
      btn.style.position = 'fixed';
      btn.style.top = '14px';
      btn.style.left = '14px';
      btn.style.zIndex = '2147483647';
      btn.style.padding = '10px 14px';
      btn.style.border = '1px solid rgba(15, 23, 42, 0.18)';
      btn.style.borderRadius = '10px';
      btn.style.background = '#ffffff';
      btn.style.color = '#0f172a';
      btn.style.fontWeight = '700';
      btn.style.fontSize = '14px';
      btn.style.cursor = 'pointer';
      btn.style.boxShadow = '0 6px 18px rgba(15, 23, 42, 0.16)';

      btn.addEventListener('click', () => {
        if (window.history.length > 1) {
          window.history.back();
          return;
        }

        window.location.href = '/resido';
      });

      document.body.appendChild(btn);
    })();
  `, true).catch(() => {});
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 840,
    minWidth: 1024,
    minHeight: 700,
    backgroundColor: '#0f172a',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  mainWindow.maximize();

  configureNoCacheSession();

  mainWindow.webContents.on('before-input-event', (event, input) => {
    if (input.meta && input.key.toLowerCase() === 'r') {
      event.preventDefault();
      mainWindow.webContents.reloadIgnoringCache();
      return;
    }

    if (input.meta && input.key.toLowerCase() === 'o') {
      event.preventDefault();
      openSettingsScreen();
    }
  });

  mainWindow.webContents.on('did-fail-load', (_event, errorCode, _desc, validatedURL) => {
    if (errorCode === -3) return;
    if (validatedURL && validatedURL.startsWith('file://')) return;
    mainWindow.loadFile(path.join(__dirname, 'offline.html')).catch(() => {});
  });

  loadConfiguredUrl();

  mainWindow.webContents.on('did-finish-load', injectAppButtonsIfNeeded);
  mainWindow.webContents.on('did-navigate-in-page', injectAppButtonsIfNeeded);
  mainWindow.webContents.on('did-navigate', injectAppButtonsIfNeeded);

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (isInternalAppUrl(url)) {
      mainWindow.loadURL(url);
      return { action: 'deny' };
    }

    shell.openExternal(url);
    return { action: 'deny' };
  });
}

function loadConfiguredUrl() {
  const serverUrl = store.get('serverUrl');

  if (!isValidHttpUrl(serverUrl)) {
    mainWindow.loadFile(path.join(__dirname, 'offline.html')).catch(() => {});
    return;
  }

  mainWindow.webContents.session.clearCache().catch(() => {}).finally(() => {
    mainWindow.loadURL(serverUrl).catch(() => {
      mainWindow.loadFile(path.join(__dirname, 'offline.html')).catch(() => {});
    });
  });
}

app.whenReady().then(() => {
  store = new Store({
    defaults: {
      serverUrl: '',
      printer: '',
      printer2: '',
      printer3: '',
      printer4: '',
      printer5: ''
    }
  });

  if (app.dock) {
    try {
      app.dock.setIcon(path.join(__dirname, '..', 'assets', 'icon.icns'));
    } catch {}
  }

  createWindow();

  app.on('activate', function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', function () {
  if (process.platform !== 'darwin') app.quit();
});

ipcMain.handle('config:getSettings', async () => {
  const printerName = await resolvePrinterName();

  return {
    serverUrl: store.get('serverUrl'),
    printer: printerName,
    printer2: store.get('printer2', ''),
    printer3: store.get('printer3', ''),
    printer4: store.get('printer4', ''),
    printer5: store.get('printer5', ''),
    appVersion: app.getVersion()
  };
});

ipcMain.handle('config:saveSettings', async (_event, payload) => {
  const url = payload?.serverUrl;

  if (!isValidHttpUrl(url)) {
    return { ok: false, message: 'Neplatna adresa servera.' };
  }

  store.set('serverUrl', url);
  if (typeof payload.printer === 'string') store.set('printer', payload.printer);
  if (typeof payload.printer2 === 'string') store.set('printer2', payload.printer2);
  if (typeof payload.printer3 === 'string') store.set('printer3', payload.printer3);
  if (typeof payload.printer4 === 'string') store.set('printer4', payload.printer4);
  if (typeof payload.printer5 === 'string') store.set('printer5', payload.printer5);

  const targetUrl = url.replace(/\/$/, '') + '/resido/';
  await mainWindow.loadURL(targetUrl).catch(async () => {
    await mainWindow.loadFile(path.join(__dirname, 'offline.html'));
  });

  return { ok: true };
});

ipcMain.handle('app:reloadTarget', async () => {
  loadConfiguredUrl();
  return { ok: true };
});

ipcMain.handle('app:openSettings', async () => {
  openSettingsScreen();
  return { ok: true };
});

const PX_PER_MM = 96 / 25.4;
const MIN_PAGE_HEIGHT_MICRONS = 50 * 1000;
const MAX_PAGE_HEIGHT_MICRONS = 2000 * 1000;
const PAGE_HEIGHT_BUFFER_MM = 3;
const FALLBACK_PAGE_HEIGHT_MICRONS = 1000000;

function parseMmValue(rawValue) {
  const match = /([\d.]+)\s*mm/.exec(String(rawValue || ''));

  if (!match) {
    return 0;
  }

  const mm = parseFloat(match[1]);

  return Number.isFinite(mm) && mm > 0 ? mm : 0;
}

// Roll printers cut the paper on every page break, so a receipt taller than
// one page comes out physically split. Measure the rendered content under
// print-media emulation and size the page to fit the whole receipt.
async function measurePrintLayout(webContents) {
  let emulated = false;

  try {
    webContents.debugger.attach('1.3');
    await webContents.debugger.sendCommand('Emulation.setEmulatedMedia', { media: 'print' });
    emulated = true;
  } catch {}

  try {
    const layout = await webContents.executeJavaScript(`(() => {
      const rootStyle = getComputedStyle(document.documentElement);
      const widthVar = rootStyle.getPropertyValue('--receipt-width') || rootStyle.getPropertyValue('--bon-width');
      const heightPx = Math.max(
        document.documentElement.scrollHeight,
        document.body ? document.body.scrollHeight : 0
      );

      return { widthVar: String(widthVar || '').trim(), heightPx };
    })()`, true);

    return {
      widthMm: parseMmValue(layout.widthVar),
      heightPx: Number.isFinite(layout.heightPx) && layout.heightPx > 0 ? layout.heightPx : 0
    };
  } catch {
    return { widthMm: 0, heightPx: 0 };
  } finally {
    if (emulated) {
      try { webContents.debugger.detach(); } catch {}
    }
  }
}

// Receipt pages advertise how many copies to print (the duplicate-receipt
// setting) via a <meta name="print-copies"> tag. Each copy goes out as a
// separate print job so roll printers cut between copies. Pages without the
// tag (bons, older server versions) print once.
async function readPrintCopies(webContents) {
  try {
    const copies = await webContents.executeJavaScript(`(() => {
      const meta = document.querySelector('meta[name="print-copies"]');
      return meta ? parseInt(meta.content, 10) : 1;
    })()`, true);

    return Number.isFinite(copies) && copies > 1 ? Math.min(copies, 5) : 1;
  } catch {
    return 1;
  }
}

async function printUrlSilently(url, printerName, requirePrinter) {
  if (requirePrinter && !printerName) {
    return { ok: false };
  }

  let loadUrl = url;
  let paperWidthMm = 0;
  try {
    const parsed = new URL(url);
    const pw = parseInt(parsed.searchParams.get('paperWidth') || '', 10);
    if (pw > 0) paperWidthMm = pw;
    parsed.searchParams.delete('autoprint');
    loadUrl = parsed.toString();
  } catch {}

  return await new Promise((resolve) => {
    const printWin = new BrowserWindow({
      show: false,
      width: 800,
      height: 600,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true
      }
    });

    let finished = false;
    const finish = (result) => {
      if (finished) {
        return;
      }

      finished = true;

      if (!printWin.isDestroyed()) {
        printWin.destroy();
      }

      resolve(result);
    };

    printWin.webContents.once('did-fail-load', () => {
      finish({ ok: false });
    });

    printWin.webContents.once('did-finish-load', async () => {
      // scaleFactor 100 keeps Chromium from fit-scaling the page onto the
      // driver's paper when the driver ignores our custom pageSize width -
      // scaled output shows up as content overflowing the printable width
      // (right edge cut, long lines wrapped to the left margin).
      const options = printerName
        ? { silent: true, deviceName: printerName, printBackground: true, landscape: false, scaleFactor: 100 }
        : { silent: true, printBackground: true, landscape: false, scaleFactor: 100 };

      const layout = await measurePrintLayout(printWin.webContents);
      const widthMm = paperWidthMm > 0 ? paperWidthMm : layout.widthMm;

      if (widthMm > 0) {
        const contentMicrons = layout.heightPx > 0
          ? Math.ceil(layout.heightPx / PX_PER_MM + PAGE_HEIGHT_BUFFER_MM) * 1000
          : FALLBACK_PAGE_HEIGHT_MICRONS;

        options.margins = { marginType: 'none' };
        options.pageSize = {
          width: widthMm * 1000,
          height: Math.min(MAX_PAGE_HEIGHT_MICRONS, Math.max(MIN_PAGE_HEIGHT_MICRONS, contentMicrons))
        };
      }

      const copies = await readPrintCopies(printWin.webContents);

      if (printWin.isDestroyed()) {
        finish({ ok: false });
        return;
      }

      const printNextCopy = (remaining) => {
        if (printWin.isDestroyed()) {
          finish({ ok: false });
          return;
        }

        printWin.webContents.print(options, (success) => {
          if (!success || remaining <= 1) {
            finish({ ok: success });
            return;
          }

          printNextCopy(remaining - 1);
        });
      };

      printNextCopy(copies);
    });

    printWin.loadURL(loadUrl).catch(() => {
      finish({ ok: false });
    });
  });
}

ipcMain.handle('print:silent:bon', async (_event, { url }) => {
  return printUrlSilently(url, await resolvePrinter2Name(), true);
});

ipcMain.handle('print:silent:bon2', async (_event, { url }) => {
  return printUrlSilently(url, await resolvePrinter3Name(), true);
});

ipcMain.handle('print:silent:bon3', async (_event, { url }) => {
  return printUrlSilently(url, await resolvePrinter4Name(), true);
});

ipcMain.handle('print:silent:bon4', async (_event, { url }) => {
  return printUrlSilently(url, await resolvePrinter5Name(), true);
});

ipcMain.handle('printers:list', async () => {
  const printers = await listAvailablePrinters();

  return printers.map(p => ({ name: p.name, isDefault: p.isDefault }));
});

ipcMain.handle('print:silent', async (_event, { url }) => {
  return printUrlSilently(url, await resolvePrinterName(), false);
});
EOF

cat > "$root/src/preload.js" <<'EOF'
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('reservationClient', {
  getSettings: () => ipcRenderer.invoke('config:getSettings'),
  saveSettings: (payload) => ipcRenderer.invoke('config:saveSettings', payload),
  reloadTarget: () => ipcRenderer.invoke('app:reloadTarget'),
  openSettings: () => ipcRenderer.invoke('app:openSettings'),
  listPrinters: () => ipcRenderer.invoke('printers:list'),
  printSilent: (url) => ipcRenderer.invoke('print:silent', { url }),
  printSilentBon: (url) => ipcRenderer.invoke('print:silent:bon', { url }),
  printSilentBonTwo: (url) => ipcRenderer.invoke('print:silent:bon2', { url }),
  printSilentBonThree: (url) => ipcRenderer.invoke('print:silent:bon3', { url }),
  printSilentBonFour: (url) => ipcRenderer.invoke('print:silent:bon4', { url })
});
EOF

cat > "$root/src/offline.html" <<'EOF'
<!DOCTYPE html>
<html lang="sk">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>APP_NAME_PLACEHOLDER</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, Arial, sans-serif;
      background: #0f172a;
      color: #e2e8f0;
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
    }
    .card {
      width: min(580px, calc(100vw - 32px));
      background: #111827;
      border: 1px solid #334155;
      border-radius: 16px;
      padding: 24px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.35);
    }
    h1 {
      margin-top: 0;
      font-size: 28px;
    }
    p {
      line-height: 1.5;
      color: #cbd5e1;
    }
    label {
      display: block;
      margin-bottom: 8px;
      font-weight: bold;
    }
    input {
      width: 100%;
      box-sizing: border-box;
      padding: 12px 14px;
      border-radius: 10px;
      border: 1px solid #475569;
      background: #0b1220;
      color: #e2e8f0;
      margin-bottom: 14px;
    }
    .row {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      align-items: center;
    }
    button {
      border: 0;
      border-radius: 10px;
      padding: 12px 16px;
      cursor: pointer;
      font-weight: bold;
    }
    .primary {
      background: #2563eb;
      color: white;
    }
    .secondary {
      background: #334155;
      color: white;
    }
    #status {
      margin-top: 14px;
      min-height: 24px;
      color: #93c5fd;
    }
    select {
      width: 100%;
      box-sizing: border-box;
      padding: 12px 14px;
      border-radius: 10px;
      border: 1px solid #475569;
      background: #0b1220;
      color: #e2e8f0;
      margin-bottom: 14px;
      appearance: none;
    }
    .section-title {
      font-size: 13px;
      font-weight: bold;
      color: #94a3b8;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin: 18px 0 10px;
      border-top: 1px solid #1e293b;
      padding-top: 14px;
    }
    .hint {
      margin-top: 12px;
      font-size: 14px;
      color: #94a3b8;
    }
    .summary {
      margin-bottom: 14px;
      padding: 12px 14px;
      border: 1px solid #334155;
      border-radius: 10px;
      background: #0b1220;
      color: #cbd5e1;
      line-height: 1.5;
    }
    code {
      background: #0b1220;
      padding: 2px 6px;
      border-radius: 6px;
    }
  </style>
</head>
<body>
  <div class="card">
    <h1>APP_NAME_PLACEHOLDER</h1>
    <p>Desktop klient pre manazment. Zadaj adresu servera a uloz nastavenia.</p>

    <label for="serverUrl">Adresa servera</label>
    <input id="serverUrl" type="text" placeholder="http://192.168.x.x" />

    <div class="section-title">Tlacenie blocikov</div>

    <div class="summary" id="printerSummary">Aktivna tlaciaren: nacitavam...</div>

    <label for="printer">Tlaciaren 1 pre blociky</label>
    <select id="printer"><option value="">— pouzit systemovu predvolenu tlaciaren —</option></select>

    <label for="printer2">Bonovacka 1</label>
    <select id="printer2"><option value="">— nepouzivat —</option></select>

    <label for="printer3">Bonovacka 2</label>
    <select id="printer3"><option value="">— nepouzivat —</option></select>

    <label for="printer4">Bonovacka 3</label>
    <select id="printer4"><option value="">— nepouzivat —</option></select>

    <label for="printer5">Bonovacka 4</label>
    <select id="printer5"><option value="">— nepouzivat —</option></select>

    <div class="row">
      <button class="secondary" id="loadPrintersBtn">Nacitat tlaciarne</button>
    </div>

    <div class="row" style="margin-top:14px">
      <button class="primary" id="saveBtn">Ulozit a pripojit</button>
      <button class="secondary" id="retryBtn">Skusit znova</button>
    </div>

    <div id="status"></div>

    <div class="hint">
      Klavesova skratka <code>Cmd+R</code> obnovi pripojenie, <code>Cmd+O</code> kedykolvek otvori tuto obrazovku Nastaveni.
    </div>
    <div class="hint" id="installedVersion">Nainstalovana verzia Resido klienta: nacitavam...</div>
  </div>

  <script>
    const input = document.getElementById('serverUrl');
    const selPrinter = document.getElementById('printer');
    const selPrinter2 = document.getElementById('printer2');
    const selPrinter3 = document.getElementById('printer3');
    const selPrinter4 = document.getElementById('printer4');
    const selPrinter5 = document.getElementById('printer5');
    const status = document.getElementById('status');
    const saveBtn = document.getElementById('saveBtn');
    const retryBtn = document.getElementById('retryBtn');
    const loadPrintersBtn = document.getElementById('loadPrintersBtn');
    const printerSummary = document.getElementById('printerSummary');
    const installedVersion = document.getElementById('installedVersion');

    function renderPrinterSummary(printers, saved) {
      const defaultPrinter = printers.find((printer) => printer.isDefault);
      const activePrinter = saved || (defaultPrinter ? defaultPrinter.name : '');
      const defaultPrinterLabel = defaultPrinter ? defaultPrinter.name : 'nenajdena';
      const activePrinterLabel = activePrinter || 'systemova predvolena';

      printerSummary.textContent = `Aktivna tlaciaren: ${activePrinterLabel} | Systemova predvolena: ${defaultPrinterLabel}`;
    }

    function populatePrinters(el, printers, saved, noAutoDefault) {
      while (el.options.length > 1) el.remove(1);
      printers.forEach(p => {
        const opt = document.createElement('option');
        opt.value = p.name;
        opt.textContent = p.name + (p.isDefault ? ' (predvolena)' : '');
        if (p.name === saved) opt.selected = true;
        el.appendChild(opt);
      });
      if (!saved && !noAutoDefault) {
        const def = printers.find(p => p.isDefault);
        if (def) el.value = def.name;
      }
    }

    async function init() {
      const settings = await window.reservationClient.getSettings();
      input.value = settings.serverUrl || '';
      const printers = await window.reservationClient.listPrinters();
      populatePrinters(selPrinter, printers, settings.printer || '');
      populatePrinters(selPrinter2, printers, settings.printer2 || '', true);
      populatePrinters(selPrinter3, printers, settings.printer3 || '', true);
      populatePrinters(selPrinter4, printers, settings.printer4 || '', true);
      populatePrinters(selPrinter5, printers, settings.printer5 || '', true);
      renderPrinterSummary(printers, settings.printer || '');
      installedVersion.textContent = `Nainstalovana verzia Resido klienta: ${settings.appVersion || 'neznama'}`;
    }

    loadPrintersBtn.addEventListener('click', async () => {
      loadPrintersBtn.textContent = 'Nacitavam...';
      const printers = await window.reservationClient.listPrinters();
      const settings = await window.reservationClient.getSettings();
      populatePrinters(selPrinter, printers, settings.printer || '');
      populatePrinters(selPrinter2, printers, settings.printer2 || '', true);
      populatePrinters(selPrinter3, printers, settings.printer3 || '', true);
      populatePrinters(selPrinter4, printers, settings.printer4 || '', true);
      populatePrinters(selPrinter5, printers, settings.printer5 || '', true);
      renderPrinterSummary(printers, settings.printer || '');
      loadPrintersBtn.textContent = 'Nacitat tlaciarne';
    });

    saveBtn.addEventListener('click', async () => {
      status.textContent = 'Pripajam...';
      const result = await window.reservationClient.saveSettings({
        serverUrl: input.value.trim(),
        printer: selPrinter.value,
        printer2: selPrinter2.value,
        printer3: selPrinter3.value,
        printer4: selPrinter4.value,
        printer5: selPrinter5.value
      });
      const printers = await window.reservationClient.listPrinters();
      const settings = await window.reservationClient.getSettings();
      populatePrinters(selPrinter, printers, settings.printer || '');
      populatePrinters(selPrinter2, printers, settings.printer2 || '', true);
      populatePrinters(selPrinter3, printers, settings.printer3 || '', true);
      populatePrinters(selPrinter4, printers, settings.printer4 || '', true);
      populatePrinters(selPrinter5, printers, settings.printer5 || '', true);
      renderPrinterSummary(printers, settings.printer || '');
      status.textContent = result.ok ? 'Ulozene.' : (result.message || 'Nepodarilo sa ulozit.');
    });

    retryBtn.addEventListener('click', async () => {
      status.textContent = 'Obnovujem...';
      await window.reservationClient.reloadTarget();
      status.textContent = 'Hotovo.';
    });

    init();
  </script>
</body>
</html>
EOF
sed -i '' "s/APP_NAME_PLACEHOLDER/$app_name/g" "$root/src/offline.html"

cat > "$root/README.md" <<'EOF'
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
seba nekontroluje ani neaplikuje aktualizacie (na rozdiel od Windows klienta
v `windows_app_script/`). Ziadny `electron-updater`, ziadne tlacidlo
"Skontrolovat aktualizacie". Novu verziu treba nainstalovat rucne (stiahnut
novy `.dmg` z residomac.vorntech.sk, nahradit appku v `/Applications`).

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

## Predvolene nastavenie

Aplikacia sa pripaja na adresu nakonfigurovanu v nastaveniach (obrazovka sa
zobrazi automaticky, kym adresa servera nie je nastavena, alebo cez tlacidlo
"Nastavenia" v pravom hornom rohu).
EOF
sed -i '' "s/APP_NAME_PLACEHOLDER/$app_name/g" "$root/README.md"

echo "Hotovo. Projekt $app_name bol vytvoreny v: $root"
