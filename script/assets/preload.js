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
