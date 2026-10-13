import QtQuick
import Quickshell
import Quickshell.Io
import "SystemMetrics.js" as Model

// Collecte du widget System : /proc et /sys lus directement par FileView, sans
// processus intermediaire. Seuls trois forks subsistent : la decouverte des
// sondes une fois au chargement, `df` une fois par minute panneau ouvert, et
// nvidia-smi a chaque releve, la carte NVIDIA n'exposant rien dans /sys.
//
// Porte de omarchy-system-monitor (Harshith Chennupati, MIT), Metrics.qml au
// commit 71599f7. Retires : capteurs Apple Silicon, ventilateurs et leur
// pilotage par sudo (materiel absent ici), lecture GPU par sysfs, debit reseau
// (le widget Network le mesure deja).
Item {
  id: root

  property bool panelOpen: false

  // Cadence relachee panneau ferme : la barre n'a besoin que d'une tendance.
  readonly property int closedRefreshMs: 5000
  readonly property int openRefreshMs: 2000

  readonly property string discoverScript: String(Qt.resolvedUrl("system_discover.sh")).replace(/^file:\/\//, "")

  property real cpuPercent: -1
  property var perCore: []
  property real memoryPercent: -1
  property double memoryUsed: 0
  property double memoryTotal: 0
  property real swapPercent: -1
  property double swapUsed: 0
  property double swapTotal: 0
  property real loadOne: -1
  property real loadFive: -1
  property real loadFifteen: -1
  property double uptimeSeconds: 0
  property real cpuTemperature: -1
  property real gpuPercent: -1
  property real gpuTemperature: -1
  property double gpuVramUsed: -1
  property double gpuVramTotal: -1
  property real diskReadBps: -1
  property real diskWriteBps: -1
  property real filesystemPercent: -1
  property double filesystemUsed: 0
  property double filesystemTotal: 0
  property var extraFilesystems: []
  property string hostname: ""
  property string cpuTempPath: ""
  property string gpuSmiPath: ""
  property var diskDevices: []
  property double lastFilesystemRefreshMs: 0

  property var cpuHistory: []
  property var memoryHistory: []
  property var gpuHistory: []

  readonly property real coreMaximum: Model.maximumPercent(perCore)

  property var cpuSnapshot: ({})
  property var diskSnapshot: null

  function sample() {
    statFile.reload()
    memoryFile.reload()
    loadFile.reload()
    uptimeFile.reload()
    diskFile.reload()
    if (cpuTempPath !== "") temperatureFile.reload()
    if (gpuSmiPath !== "" && !gpuProc.running) gpuProc.running = true

    var now = Date.now()
    if (panelOpen && !filesystemProc.running && now - lastFilesystemRefreshMs >= 60000) {
      lastFilesystemRefreshMs = now
      filesystemProc.running = true
    }
  }

  function handleCpu(raw) {
    var parsed = Model.parseCpu(raw, cpuSnapshot)
    cpuSnapshot = parsed.snapshot
    perCore = parsed.cores
    if (parsed.overall < 0) return
    cpuPercent = parsed.overall
    cpuHistory = Model.appendHistory(cpuHistory, Date.now(), cpuPercent)
  }

  function handleMemory(raw) {
    var parsed = Model.parseMemory(raw)
    memoryPercent = parsed.percent
    memoryUsed = parsed.used
    memoryTotal = parsed.total
    swapPercent = parsed.swapPercent
    swapUsed = parsed.swapUsed
    swapTotal = parsed.swapTotal
    memoryHistory = Model.appendHistory(memoryHistory, Date.now(), memoryPercent)
  }

  function handleLoad(raw) {
    var parsed = Model.parseLoad(raw)
    loadOne = parsed.one
    loadFive = parsed.five
    loadFifteen = parsed.fifteen
  }

  function handleDisk(raw) {
    var current = Model.parseDisk(raw, diskDevices)
    var now = Date.now()
    if (!current) {
      diskSnapshot = null
      diskReadBps = -1
      diskWriteBps = -1
      return
    }

    if (diskSnapshot) {
      var elapsed = (now - diskSnapshot.time) / 1000
      var readDelta = current.readBytes - diskSnapshot.readBytes
      var writeDelta = current.writeBytes - diskSnapshot.writeBytes
      // Au-dela de 30 s, l'ecart mesure une mise en veille, pas un debit.
      if (elapsed > 0 && elapsed < 30 && readDelta >= 0 && writeDelta >= 0) {
        diskReadBps = readDelta / elapsed
        diskWriteBps = writeDelta / elapsed
      }
    }
    diskSnapshot = { readBytes: current.readBytes, writeBytes: current.writeBytes, time: now }
  }

  // Un pilote qui tombe ou une sortie illisible : on efface plutot que de
  // laisser le dernier releve passer pour une mesure vive.
  function handleGpu(raw) {
    var parsed = Model.parseNvidiaGpu(raw)
    if (!parsed) {
      gpuPercent = -1
      gpuTemperature = -1
      gpuVramUsed = -1
      gpuVramTotal = -1
      return
    }
    gpuPercent = parsed.percent
    gpuTemperature = parsed.temperature
    gpuVramUsed = parsed.vramUsed
    gpuVramTotal = parsed.vramTotal
    if (gpuPercent >= 0) gpuHistory = Model.appendHistory(gpuHistory, Date.now(), gpuPercent)
  }

  onPanelOpenChanged: {
    sampleTimer.restart()
    sample()
  }

  Timer {
    id: sampleTimer
    interval: root.panelOpen ? root.openRefreshMs : root.closedRefreshMs
    repeat: true
    running: true
    onTriggered: root.sample()
  }

  FileView {
    id: statFile
    path: "/proc/stat"
    watchChanges: false
    printErrors: false
    onLoaded: root.handleCpu(text())
  }

  FileView {
    id: memoryFile
    path: "/proc/meminfo"
    watchChanges: false
    printErrors: false
    onLoaded: root.handleMemory(text())
  }

  FileView {
    id: loadFile
    path: "/proc/loadavg"
    watchChanges: false
    printErrors: false
    onLoaded: root.handleLoad(text())
  }

  FileView {
    id: uptimeFile
    path: "/proc/uptime"
    watchChanges: false
    printErrors: false
    onLoaded: root.uptimeSeconds = Model.parseUptime(text())
  }

  FileView {
    id: diskFile
    path: "/proc/diskstats"
    watchChanges: false
    printErrors: false
    onLoaded: root.handleDisk(text())
  }

  FileView {
    id: temperatureFile
    path: root.cpuTempPath
    watchChanges: false
    printErrors: false
    onLoaded: {
      var value = Number(String(text()).trim()) / 1000
      root.cpuTemperature = isFinite(value) && value > 0 ? value : -1
    }
    onLoadFailed: root.cpuTemperature = -1
  }

  FileView {
    path: "/etc/hostname"
    watchChanges: true
    printErrors: false
    onLoaded: root.hostname = String(text()).trim()
    onFileChanged: reload()
  }

  Process {
    id: gpuProc
    command: [
      root.gpuSmiPath,
      "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total",
      "--format=csv,noheader,nounits"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.handleGpu(text)
    }
  }

  Process {
    id: discoveryProc
    command: ["bash", root.discoverScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var discovered = Model.parseDiscovery(text)
        root.cpuTempPath = discovered.cpuTempPath
        root.gpuSmiPath = discovered.gpuSmiPath
        root.diskDevices = discovered.devices
        root.diskSnapshot = null
        if (root.cpuTempPath !== "") temperatureFile.reload()
        if (root.gpuSmiPath !== "" && !gpuProc.running) gpuProc.running = true
        diskFile.reload()
      }
    }
  }

  Process {
    id: filesystemProc
    // Systemes de fichiers locaux uniquement, avec leur type : le modele ecarte
    // les pseudo-montages et replie les sous-volumes. `-l` empeche un montage
    // reseau fige de bloquer df.
    command: ["df", "-P", "-k", "-l", "-T"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var all = Model.parseFilesystems(text)
        var extras = []
        for (var i = 0; i < all.length; i++) {
          if (all[i].mount === "/") {
            root.filesystemPercent = all[i].percent
            root.filesystemUsed = all[i].used
            root.filesystemTotal = all[i].total
          } else {
            extras.push(all[i])
          }
        }
        root.extraFilesystems = extras
      }
    }
  }

  Component.onCompleted: {
    discoveryProc.running = true
    sample()
  }
}
