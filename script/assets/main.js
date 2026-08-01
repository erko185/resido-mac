const { app, BrowserWindow, ipcMain, shell, dialog } = require('electron');
const path = require('path');
const fs = require('fs');
const { execFile } = require('child_process');
const Store = require('electron-store');

let store;
let mainWindow;

// Print diagnostics ring buffer. console.log from the main process goes to
// stdout, which is invisible in an installed app - these lines are kept in
// memory, mirrored to a log file next to the settings, and shown in the
// settings screen so print problems can be diagnosed on site.
const PRINT_LOG_MAX_LINES = 40;
const printLogLines = [];

function printDiagnosticsEnabled() {
  // store is created on app ready; printing cannot happen before that, but be
  // defensive so a log call during startup can never throw.
  return Boolean(store && store.get('printDiagnostics', false));
}

function printLog(message) {
  const stamp = new Date().toLocaleTimeString('sk-SK');
  const line = `${stamp}  ${message}`;

  // Kept in memory unconditionally (cheap) so switching diagnostics on shows
  // context immediately; the log file and the settings-screen box are opt-in.
  printLogLines.push(line);
  if (printLogLines.length > PRINT_LOG_MAX_LINES) {
    printLogLines.shift();
  }

  if (!printDiagnosticsEnabled()) {
    return;
  }

  console.log(line);

  try {
    fs.appendFileSync(path.join(app.getPath('userData'), 'print-log.txt'), line + '\n');
  } catch {
    // Diagnostics must never break printing.
  }
}

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

// The receipt printer is picked explicitly, exactly like the bon printers -
// there is no "use the system default printer" mode: RAW ESC/POS has to
// address a named printer, and silently printing to whatever the system
// considers default was a common source of wrong-printer/wrong-width output.
async function resolvePrinterName() {
  const saved = store.get('printer', '');

  if (!saved) {
    return '';
  }

  const printers = await listAvailablePrinters();

  return printers.some(printer => printer.name === saved) ? saved : '';
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
      return;
    }

    // Hidden switch for print diagnostics (log file in the app's data folder
    // plus the log box in the settings screen). Off by default so operators
    // never see it; turn it on when a printing problem needs investigating.
    if (input.meta && input.shift && input.key.toLowerCase() === 'l') {
      event.preventDefault();

      const enabled = !printDiagnosticsEnabled();
      store.set('printDiagnostics', enabled);
      printLog(`Diagnostika tlace ${enabled ? 'zapnuta' : 'vypnuta'}.`);

      dialog.showMessageBox(mainWindow, {
        type: 'info',
        buttons: ['OK'],
        title: 'Diagnostika tlace',
        message: enabled
          ? 'Diagnostika tlace je ZAPNUTA. Log sa zobrazuje v Nastaveniach a zapisuje do print-log.txt.'
          : 'Diagnostika tlace je VYPNUTA.'
      }).catch(() => {});
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
      printer5: '',
      // Per-slot RAW ESC/POS mode: render the receipt to a raster and send
      // it straight to CUPS as RAW bytes (lp -o raw), bypassing the printer
      // driver entirely. Default ON because every printer this app is used
      // with is a thermal receipt printer, and their drivers ignore custom
      // page widths (shifted/clipped output). Turn it off for a regular
      // office/A4 printer.
      printerRaw: true,
      printer2Raw: true,
      printer3Raw: true,
      printer4Raw: true,
      printer5Raw: true,
      // Print diagnostics (log file + the box in the settings screen) are off
      // by default and toggled with Cmd+Shift+L - they exist for on-site
      // debugging, not for daily use.
      printDiagnostics: false
    }
  });

  // electron-store persists its defaults on first run, so installs created
  // before the RAW keys existed would keep any stored "false" values forever
  // and never pick up the new default. Flip them on once (marker keeps it a
  // one-time migration, so switching a slot back off stays respected).
  if (!store.get('rawDefaultsApplied', false)) {
    for (const key of ['printerRaw', 'printer2Raw', 'printer3Raw', 'printer4Raw', 'printer5Raw']) {
      store.set(key, true);
    }

    store.set('rawDefaultsApplied', true);
  }

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
    printerRaw: store.get('printerRaw', true),
    printer2Raw: store.get('printer2Raw', true),
    printer3Raw: store.get('printer3Raw', true),
    printer4Raw: store.get('printer4Raw', true),
    printer5Raw: store.get('printer5Raw', true),
    appVersion: app.getVersion(),
    // Shown in the settings screen so print problems are diagnosable on site
    // (main-process console output is invisible in an installed app).
    printDiagnostics: printDiagnosticsEnabled(),
    printLog: printDiagnosticsEnabled() ? printLogLines.slice(-12).join('\n') : ''
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
  if (typeof payload.printerRaw === 'boolean') store.set('printerRaw', payload.printerRaw);
  if (typeof payload.printer2Raw === 'boolean') store.set('printer2Raw', payload.printer2Raw);
  if (typeof payload.printer3Raw === 'boolean') store.set('printer3Raw', payload.printer3Raw);
  if (typeof payload.printer4Raw === 'boolean') store.set('printer4Raw', payload.printer4Raw);
  if (typeof payload.printer5Raw === 'boolean') store.set('printer5Raw', payload.printer5Raw);

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

// ---------------------------------------------------------------------------
// RAW ESC/POS printing - the same approach the Windows and Android clients
// use: load the receipt page off-screen, rasterize it at exactly the paper
// width (8 dots/mm at 203 dpi), encode as GS v 0 raster chunks and hand the
// bytes to CUPS as a raw job (lp -o raw). The printer driver is bypassed
// entirely, so its paper-size quirks (ignored custom widths -> shifted/
// clipped output) no longer matter.
// ---------------------------------------------------------------------------

const RAW_DOTS_PER_MM = 8;
// Feed pushed out before each cut so the printed end clears the
// head-to-cutter gap. Must stay <= 31mm (ESC J n caps at 255 dots).
const RAW_CUT_FEED_MM = 28;
const RAW_ZOOM = RAW_DOTS_PER_MM / (96 / 25.4); // ~2.1167 device px per CSS px
const RAW_DEFAULT_WIDTH_MM = 72;
const RAW_MIN_HEIGHT_DOTS = 50 * RAW_DOTS_PER_MM;
const RAW_MAX_HEIGHT_DOTS = 2000 * RAW_DOTS_PER_MM;

// RAW bytes reach the printer through CUPS: `lp -d <queue> -o raw` submits
// the payload untouched (no filters, no driver). Electron's printer names on
// macOS are the CUPS queue names, so the picked printer can be addressed
// directly - no helper binary needed, unlike the Windows client's
// raw-print.exe.
function sendRawToPrinter(printerName, payload) {
  const dataPath = path.join(
    app.getPath('temp'),
    'resido-raw-' + Date.now() + '-' + Math.random().toString(16).slice(2) + '.bin'
  );

  return new Promise((resolve) => {
    try {
      fs.writeFileSync(dataPath, payload);
    } catch (error) {
      printLog('RAW print failed: ' + error.message);
      resolve(false);
      return;
    }

    execFile('lp', ['-d', printerName, '-o', 'raw', dataPath], (error, _stdout, stderr) => {
      if (error) {
        printLog('RAW print (lp) failed: ' + String(stderr || error.message).trim());
      }

      try { fs.unlinkSync(dataPath); } catch {}

      resolve(!error);
    });
  });
}

// Bitmap (NativeImage) -> one printed copy as ESC/POS bytes, including
// trailing feed and cut. Mirrors the Android client's EscPosEncoder,
// including the 255-row chunk cap (cheap firmwares only honour yL).
function encodeEscPosRaster(image, targetWidthDots) {
  const resized = image.resize({ width: targetWidthDots, quality: 'best' });
  const size = resized.getSize();
  const bitmap = resized.toBitmap(); // BGRA
  const width = size.width;
  const height = size.height;
  const widthBytes = Math.ceil(width / 8);
  const rows = Buffer.alloc(widthBytes * height);
  let firstInkRow = -1;
  let lastInkRow = -1;
  let firstInkCol = width;
  let lastInkCol = -1;

  for (let y = 0; y < height; y++) {
    const rowOffset = y * widthBytes;
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      const luminance = (bitmap[i + 2] * 299 + bitmap[i + 1] * 587 + bitmap[i] * 114) / 1000;

      if (luminance < 160) {
        rows[rowOffset + (x >> 3)] |= 0x80 >> (x & 7);
        if (firstInkRow === -1) firstInkRow = y;
        lastInkRow = y;
        if (x < firstInkCol) firstInkCol = x;
        if (x > lastInkCol) lastInkCol = x;
      }
    }
  }

  // Logged so the on-site diagnostics show how much of the paper width the
  // content actually covers - a receipt narrower than the paper shows up here
  // as an inked span well below the raster width.
  const inkWidthDots = lastInkCol >= firstInkCol ? lastInkCol - firstInkCol + 1 : 0;
  printLog(
    `RAW raster: ${width}x${height} dots, ink cols ${firstInkCol}..${lastInkCol} ` +
    `(${(inkWidthDots / RAW_DOTS_PER_MM).toFixed(1)}mm of ${(width / RAW_DOTS_PER_MM).toFixed(1)}mm), ` +
    `ink rows ${firstInkRow}..${lastInkRow}`
  );

  const chunks = [Buffer.from([0x1b, 0x40])]; // ESC @ init

  // Print only the inked band - leading blank rows would just extend the
  // physical head-to-cutter gap every thermal receipt already starts with.
  const startRow = firstInkRow === -1 ? 0 : firstInkRow;
  const totalRows = lastInkRow + 1;

  for (let y = startRow; y < totalRows; y += 255) {
    const chunkRows = Math.min(255, totalRows - y);
    chunks.push(Buffer.from([
      0x1d, 0x76, 0x30, 0x00, // GS v 0 m=0
      widthBytes & 0xff, (widthBytes >> 8) & 0xff,
      chunkRows & 0xff, (chunkRows >> 8) & 0xff
    ]));
    chunks.push(rows.subarray(y * widthBytes, (y + chunkRows) * widthBytes));
  }

  // Feed past the cutter with ESC J (feed n dots) - dot-exact on every
  // firmware. ESC d n is line-spacing dependent (6 "lines" measured only
  // 15mm on an XP-80 clone and fell short of the CK710's head-to-cutter
  // distance - the bon tail then came out on top of the next slip), and
  // blank raster rows are skipped entirely by firmwares with a
  // remove-blank-lines paper-saving option, so neither reliably clears
  // the gap.
  const feedDots = RAW_CUT_FEED_MM * RAW_DOTS_PER_MM;
  printLog(`RAW feed before cut: ${RAW_CUT_FEED_MM}mm (ESC J ${feedDots})`);
  chunks.push(Buffer.from([0x1b, 0x4a, feedDots & 0xff])); // ESC J n
  chunks.push(Buffer.from([0x1d, 0x56, 0x00])); // GS V 0 full cut

  return Buffer.concat(chunks);
}

async function printUrlRawEscPos(url, printerName) {
  let loadUrl = url;
  let paperWidthMm = 0;
  try {
    const parsed = new URL(url);
    const pw = parseInt(parsed.searchParams.get('paperWidth') || '', 10);
    if (pw > 0) paperWidthMm = pw;
    parsed.searchParams.delete('autoprint');
    loadUrl = parsed.toString();
  } catch {}

  const initialWidthMm = paperWidthMm > 0 ? paperWidthMm : RAW_DEFAULT_WIDTH_MM;

  const win = new BrowserWindow({
    show: false,
    width: initialWidthMm * RAW_DOTS_PER_MM,
    height: 1200,
    frame: false,
    webPreferences: {
      // Off-screen rendering: the window size is not bound to the physical
      // screen, so the full receipt height can be captured in one shot.
      // NOTE: no zoomFactor here - Electron ignores it for offscreen
      // windows; the scale is applied via CSS transform after load instead.
      offscreen: true,
      nodeIntegration: false,
      contextIsolation: true
    }
  });
  win.webContents.setFrameRate(1);

  const finish = (ok) => {
    if (!win.isDestroyed()) {
      win.destroy();
    }

    return ok;
  };

  try {
    await win.loadURL(loadUrl);
  } catch {
    return finish(false);
  }

  try {
    for (let i = 0; i < 40; i++) {
      const ready = await win.webContents.executeJavaScript(`(() => {
        try {
          return document.readyState === 'complete'
            && (!document.fonts || document.fonts.status === 'loaded')
            && Array.from(document.images).every((img) => img.complete);
        } catch (e) {
          return document.readyState === 'complete';
        }
      })()`, true);

      if (ready) break;
      await new Promise((resolve) => setTimeout(resolve, 250));
    }

    // The page renders with screen media; copy every @media print rule body
    // into a regular <style> so the print stylesheet wins the cascade during
    // the capture (same trick as the Android client).
    await win.webContents.executeJavaScript(`(() => {
      if (window.__residoPrintCssApplied) return 'done';
      window.__residoPrintCssApplied = true;
      let css = '';
      for (const sheet of Array.from(document.styleSheets)) {
        let rules;
        try { rules = sheet.cssRules; } catch (e) { continue; }
        if (!rules) continue;
        for (const rule of Array.from(rules)) {
          if (rule.type === CSSRule.MEDIA_RULE
            && /(^|[^-\\w])print/.test(rule.media.mediaText)
            && !/not\\s+print/.test(rule.media.mediaText)) {
            for (const inner of Array.from(rule.cssRules)) {
              css += inner.cssText + '\\n';
            }
          }
        }
      }
      if (css) {
        const style = document.createElement('style');
        style.textContent = css;
        document.head.appendChild(style);
      }
      return 'done';
    })()`, true);

    const layout = await win.webContents.executeJavaScript(`(() => {
      const rootStyle = getComputedStyle(document.documentElement);
      const widthVar = rootStyle.getPropertyValue('--receipt-width')
        || rootStyle.getPropertyValue('--bon-width');
      const meta = document.querySelector('meta[name="print-copies"]');
      const copies = meta ? parseInt(meta.content, 10) : 1;
      return {
        widthVar: String(widthVar || '').trim(),
        copies: Number.isFinite(copies) ? copies : 1
      };
    })()`, true);

    const cssWidthMm = parseMmValue(layout.widthVar);
    const widthMm = paperWidthMm > 0
      ? paperWidthMm
      : (cssWidthMm > 0 ? cssWidthMm : RAW_DEFAULT_WIDTH_MM);
    const widthDots = Math.round(widthMm * RAW_DOTS_PER_MM);
    const widthCss = Math.round(widthMm * (96 / 25.4));

    // Lay the document out at exactly the paper width in CSS pixels and paint
    // it magnified into the wider window, so the raster comes out natively at
    // printer resolution. A CSS transform is used rather than `zoom` or
    // webContents.setZoomFactor: `zoom` on the root element is honoured
    // inconsistently across Chromium builds (on some it left the layout at the
    // full window width, so the receipt occupied only part of the paper), and
    // setZoomFactor leaks the zoom level to the main window (Chromium shares
    // per-origin zoom within a session).
    // The page zoom factor is shared per origin within a session, so a user
    // who zoomed the app window out (Cmd+-) would also shrink everything the
    // print window lays out - the receipt then covered only that fraction of
    // the paper. Compensate in the transform instead of forcing the zoom back
    // to 1, which would visibly reset the operator's own window zoom.
    const pageZoom = win.webContents.getZoomFactor() || 1;
    const renderScale = RAW_ZOOM / pageZoom;

    const applyLayoutJs = `(() => {
      const html = document.documentElement;
      html.style.setProperty('width', '${widthCss}px', 'important');
      html.style.setProperty('min-width', '${widthCss}px', 'important');
      html.style.setProperty('max-width', '${widthCss}px', 'important');
      html.style.setProperty('overflow', 'hidden', 'important');
      html.style.setProperty('transform-origin', 'top left', 'important');
      html.style.setProperty('transform', 'scale(${renderScale})', 'important');
      return html.getBoundingClientRect().width;
    })()`;

    win.setContentSize(widthDots, 1200);
    await win.webContents.executeJavaScript(applyLayoutJs, true);
    await new Promise((resolve) => setTimeout(resolve, 250));

    // Measured on the transformed element, so this is already in device
    // pixels (= printer dots). documentElement.scrollHeight cannot be used:
    // the overflow:hidden above makes it report the window height instead of
    // the content height.
    const contentHeightDevice = await win.webContents.executeJavaScript(`(() => {
      const body = document.body;
      if (!body) return 0;
      const rect = body.getBoundingClientRect();
      return Math.max(rect.bottom, rect.height);
    })()`, true);
    let heightDots = Math.ceil(contentHeightDevice * pageZoom) + 3 * RAW_DOTS_PER_MM;
    heightDots = Math.max(RAW_MIN_HEIGHT_DOTS, Math.min(RAW_MAX_HEIGHT_DOTS, heightDots));

    win.setContentSize(widthDots, heightDots);
    // Re-assert the layout: resizing the window re-runs the page's own layout
    // and some pages reset inline styles through their stylesheets.
    const laidOutCssWidth = await win.webContents.executeJavaScript(applyLayoutJs, true);
    await new Promise((resolve) => setTimeout(resolve, 300));

    const image = await win.webContents.capturePage();
    const captured = image.getSize();
    printLog(
      `RAW render: widthMm=${widthMm} widthDots=${widthDots} widthCss=${widthCss} ` +
      `pageZoom=${pageZoom} renderScale=${renderScale.toFixed(4)} ` +
      `laidOutCss=${laidOutCssWidth} contentHeightDevice=${contentHeightDevice} heightDots=${heightDots} ` +
      `captured=${captured.width}x${captured.height} cssWidthVar="${layout.widthVar}" paperWidthParam=${paperWidthMm}`
    );

    const copiesCount = Math.min(Math.max(parseInt(layout.copies, 10) || 1, 1), 5);
    const singleCopy = encodeEscPosRaster(image, widthDots);
    const payload = Buffer.concat(Array.from({ length: copiesCount }, () => singleCopy));

    const ok = await sendRawToPrinter(printerName, payload);

    return finish(ok);
  } catch (error) {
    printLog('RAW render failed: ' + error.message);
    return finish(false);
  }
}

async function printUrlSilently(url, printerName, requirePrinter, useRawEscPos) {
  if (requirePrinter && !printerName) {
    return { ok: false };
  }

  if (useRawEscPos) {
    if (printerName) {
      printLog('Print: RAW ESC/POS -> ' + printerName);
      return { ok: await printUrlRawEscPos(url, printerName) };
    }

    // No printer configured for this slot: fall through to the web fallback
    // rather than guessing a printer.
    printLog('Print: RAW zapnuty, ale slot nema nastavenu tlaciaren.');
    return { ok: false };
  }

  printLog('Print: CUPS driver -> ' + printerName);

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
  return printUrlSilently(url, await resolvePrinter2Name(), true, store.get('printer2Raw', true));
});

ipcMain.handle('print:silent:bon2', async (_event, { url }) => {
  return printUrlSilently(url, await resolvePrinter3Name(), true, store.get('printer3Raw', true));
});

ipcMain.handle('print:silent:bon3', async (_event, { url }) => {
  return printUrlSilently(url, await resolvePrinter4Name(), true, store.get('printer4Raw', true));
});

ipcMain.handle('print:silent:bon4', async (_event, { url }) => {
  return printUrlSilently(url, await resolvePrinter5Name(), true, store.get('printer5Raw', true));
});

ipcMain.handle('printers:list', async () => {
  const printers = await listAvailablePrinters();

  return printers.map(p => ({ name: p.name, isDefault: p.isDefault }));
});

ipcMain.handle('print:silent', async (_event, { url }) => {
  // requirePrinter: the receipt slot must be configured too (no implicit
  // system-default printing) - unconfigured means the web fallback opens the
  // receipt in a window instead of printing somewhere unexpected.
  return printUrlSilently(url, await resolvePrinterName(), true, store.get('printerRaw', true));
});
