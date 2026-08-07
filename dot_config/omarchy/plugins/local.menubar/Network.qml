import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.Commons
import qs.Ui

// Widget reseau autonome : etat de la connexion dans la barre, panneau au clic.
// Reimplementation de `omarchy.network` — memes gestes et memes fonctions, sans
// dependre du plugin natif.
//
// Bouton : clic gauche ou milieu ouvre le panneau, clic droit lance nmtui.
// Panneau : connexion courante, details du lien, choix du resolveur DNS et
// liste des reseaux Wi-Fi (scan, connexion, oubli).
//
// L'etat du lien vient de `omarchy-network-status`, le helper qu'utilise deja
// le widget natif ; le Wi-Fi passe par le service Networking de Quickshell.
BarWidget {
  id: root
  moduleName: "local.menubar.network"

  readonly property int islandSize: bar && bar.islandSize !== undefined ? bar.islandSize : barSize
  readonly property int islandRadius: bar && bar.islandRadius !== undefined ? bar.islandRadius : Style.cornerRadius

  readonly property int revealDuration: bar && bar.revealDuration !== undefined ? bar.revealDuration : 180
  readonly property int revealEasing: Easing.OutCubic

  readonly property color accentColor: bar ? bar.accent : Color.urgent
  readonly property real accentFillOpacity: bar && bar.accentFillOpacity !== undefined ? bar.accentFillOpacity : 0.18
  readonly property color foregroundColor: bar ? bar.foreground : Color.foreground
  readonly property color mutedColor: Qt.darker(foregroundColor, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color islandFill: Qt.rgba(foregroundColor.r, foregroundColor.g, foregroundColor.b, 0.06)

  readonly property string barPosition: bar ? bar.position : "top"
  readonly property int revealDistance: Style.space(12)
  readonly property int revealOffsetX: barPosition === "left"
    ? -revealDistance
    : (barPosition === "right" ? revealDistance : 0)
  readonly property int revealOffsetY: barPosition === "bottom"
    ? revealDistance
    : (barPosition === "top" ? -revealDistance : 0)
  readonly property int transformOriginForBar: {
    if (barPosition === "bottom") return Item.Bottom
    if (barPosition === "left") return Item.Left
    if (barPosition === "right") return Item.Right
    return Item.Top
  }

  // --- Etat du lien ----------------------------------------------------------
  // `omarchy-network-status --verbose` sort une paire cle/valeur par ligne :
  // iface, type, ip, prefix, gateway, speed, duplex, ssid, signal, rx_bytes,
  // tx_bytes, router_ping_ms, internet_ping_ms.

  property var info: ({})

  readonly property string linkType: String(info.type || "")
  readonly property bool online: linkType === "wifi" || linkType === "ethernet"
  readonly property string ipAddress: String(info.ip || "")
  readonly property string gateway: String(info.gateway || "")
  readonly property int signalStrength: Number(info.signal || 0)

  property string dnsProvider: ""

  // Debits : deltas entre deux releves. On garde l'instant du releve precedent
  // pour que le premier echantillon apres une ouverture ou un changement
  // d'interface ne fabrique pas un pic.
  property real prevRxBytes: 0
  property real prevTxBytes: 0
  property real prevSampleTime: 0
  property string prevIface: ""
  property real downloadRate: 0
  property real uploadRate: 0

  function parseKeyValue(raw) {
    var out = {}
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].split("\t")
      if (parts.length >= 2 && parts[0]) out[parts[0]] = parts[1]
    }
    return out
  }

  function updateDetails(raw) {
    var next = parseKeyValue(raw)
    var iface = String(next.iface || "")
    var now = Date.now() / 1000
    var rx = Number(next.rx_bytes || 0)
    var tx = Number(next.tx_bytes || 0)

    // Un changement d'interface repart de zero : comparer les compteurs de deux
    // cartes differentes donnerait un debit absurde.
    if (iface === prevIface && prevSampleTime > 0) {
      var elapsed = now - prevSampleTime
      if (elapsed > 0.2) {
        downloadRate = Math.max(0, (rx - prevRxBytes) / elapsed)
        uploadRate = Math.max(0, (tx - prevTxBytes) / elapsed)
      }
    } else {
      downloadRate = 0
      uploadRate = 0
    }

    prevIface = iface
    prevRxBytes = rx
    prevTxBytes = tx
    prevSampleTime = now
    info = next
  }

  function formatRate(bytesPerSec) {
    var value = Number(bytesPerSec || 0)
    if (value < 1024) return Math.round(value) + " B/s"
    if (value < 1024 * 1024) return (value / 1024).toFixed(value < 10240 ? 1 : 0) + " kB/s"
    return (value / (1024 * 1024)).toFixed(1) + " MB/s"
  }

  function formatPing(raw) {
    var value = Number(raw)
    if (!isFinite(value) || value <= 0) return "—"
    return value < 10 ? value.toFixed(1) + " ms" : Math.round(value) + " ms"
  }

  function formatLinkSpeed(raw) {
    var value = Number(raw)
    if (!isFinite(value) || value <= 0) return ""
    return value >= 1000 ? (value / 1000) + " Gb/s" : value + " Mb/s"
  }

  Process {
    id: detailsProc

    command: ["omarchy-network-status", "--verbose"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateDetails(text)
    }
  }

  Process {
    id: dnsProc

    command: ["omarchy-dns"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.dnsProvider = String(text || "").trim()
    }
  }

  Process { id: actionProc }

  // Releve rapide tant que le panneau est ouvert — les debits n'ont de sens
  // qu'affiches — et lent le reste du temps, juste pour tenir l'icone a jour.
  Timer {
    interval: root.opened ? 1500 : 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh(false)
  }

  function refresh(scanWifi) {
    if (!detailsProc.running) detailsProc.running = true
    if (!dnsProc.running) dnsProc.running = true

    if (wifiDevice) {
      if (scanWifi === true) {
        scanning = true
        wifiDevice.scannerEnabled = false
        scanRestart.restart()
      } else {
        wifiDevice.scannerEnabled = opened
      }
    }
  }

  // Le scanner ne relance une salve qu'en passant par un cycle desactive/active.
  Timer {
    id: scanRestart
    interval: 120
    onTriggered: {
      if (root.wifiDevice) root.wifiDevice.scannerEnabled = true
      scanStop.restart()
    }
  }

  Timer {
    id: scanStop
    interval: 4000
    onTriggered: root.scanning = false
  }

  // --- Wi-Fi -----------------------------------------------------------------

  readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
  readonly property var wifiDevice: findDevice(DeviceType.Wifi)
  readonly property var wifiNetworkObjects: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
  readonly property bool wifiAvailable: !!wifiDevice
  readonly property var connectedWifi: {
    var networks = wifiNetworkObjects
    for (var i = 0; i < networks.length; i++) {
      if (networks[i] && networks[i].connected) return networks[i]
    }
    return null
  }

  property bool scanning: false

  // Etat de l'action en cours : la ligne concernee affiche sa progression, et
  // les autres se desactivent pour ne pas empiler deux actions.
  property string actionSsid: ""
  property string actionKind: ""
  property string failureSsid: ""
  property string failureReason: ""
  readonly property bool busy: actionKind !== ""

  // Ligne dont le champ mot de passe est deploye. On la garde ouverte pendant
  // les rafraichissements pour ne pas escamoter la saisie en cours.
  property string passwordSsid: ""
  property string passwordText: ""

  function findDevice(type) {
    var devices = networkDevices
    for (var i = 0; i < devices.length; i++) {
      if (devices[i] && devices[i].type === type) return devices[i]
    }
    return null
  }

  // Les reseaux connus et les mieux captes d'abord ; la connexion active en tete.
  readonly property var wifiRows: {
    var rows = []
    var networks = wifiNetworkObjects
    for (var i = 0; i < networks.length; i++) {
      var net = networks[i]
      if (!net || !net.name) continue
      rows.push({
        ssid: String(net.name),
        network: net,
        connected: net.connected === true,
        known: net.known === true,
        strength: Number(net.signalStrength || 0),
        secured: net.security !== undefined && net.security !== WifiSecurityType.Open
      })
    }

    rows.sort(function(left, right) {
      if (left.connected !== right.connected) return left.connected ? -1 : 1
      if (left.known !== right.known) return left.known ? -1 : 1
      return right.strength - left.strength
    })
    return rows
  }

  function isProtected(row) {
    return !!row && row.secured
  }

  function runNetworkAction(kind, network, callback) {
    if (actionKind !== "" || !network) return

    actionSsid = String(network.name || "")
    actionKind = kind
    failureSsid = ""
    failureReason = ""
    callback(network)
    // Filet : si le signal de fin n'arrive jamais, la ligne resterait bloquee
    // sur « Connexion… ».
    actionTimeout.restart()
  }

  function clearNetworkAction() {
    actionTimeout.stop()
    if (actionKind === "connect") {
      passwordSsid = ""
      passwordText = ""
    }
    actionSsid = ""
    actionKind = ""
    refresh(false)
  }

  function failNetworkAction(ssid, reason) {
    actionTimeout.stop()
    failureSsid = ssid
    failureReason = reason
    actionSsid = ""
    actionKind = ""
  }

  Timer {
    id: actionTimeout
    interval: 20000
    onTriggered: root.failNetworkAction(root.actionSsid, "Timed out")
  }

  // Les objets reseau signalent leur aboutissement par leurs proprietes, pas
  // par un retour d'appel : on surveille celle qui correspond a l'action.
  Connections {
    target: root
    function onWifiRowsChanged() {
      if (root.actionKind === "") return

      for (var i = 0; i < root.wifiRows.length; i++) {
        var row = root.wifiRows[i]
        if (row.ssid !== root.actionSsid) continue

        var settling = row.network && row.network.stateChanging
        if (root.actionKind === "connect" && row.connected) root.clearNetworkAction()
        else if (root.actionKind === "disconnect" && !row.connected && !settling) root.clearNetworkAction()
        else if (root.actionKind === "forget" && !row.known && !settling) root.clearNetworkAction()
        return
      }

      // Le reseau a disparu de la liste : un oubli reussi le fait sortir.
      if (root.actionKind === "forget") root.clearNetworkAction()
    }
  }

  function connectRow(row) {
    if (!row) return

    if (row.known || !row.secured) {
      runNetworkAction("connect", row.network, function(net) { net.connect() })
      return
    }
    openPasswordPrompt(row.ssid)
  }

  function connectWithPassphrase(row, passphrase) {
    if (!row || !passphrase) return

    runNetworkAction("connect", row.network, function(net) { net.connectWithPsk(passphrase) })
  }

  function disconnectRow(row) {
    var network = row ? row.network : connectedWifi
    runNetworkAction("disconnect", network, function(net) { net.disconnect() })
  }

  function forgetRow(row) {
    if (!row) return

    runNetworkAction("forget", row.network, function(net) { net.forget() })
  }

  function openPasswordPrompt(ssid) {
    if (passwordSsid !== ssid) passwordText = ""
    passwordSsid = ssid
  }

  function closePasswordPrompt() {
    passwordSsid = ""
    passwordText = ""
  }

  // --- Test de debit ---------------------------------------------------------
  // `omarchy-network-speedtest <down|up>` sature le lien dans une direction et
  // emet un releve en Mbit/s par seconde jusqu'a ce qu'on l'arrete. On tient
  // chaque direction 5 s, puis on enchaine sur l'autre, en gardant le dernier
  // releve de chacune.

  property bool speedTestRunning: false
  property bool speedTestHasRun: false
  property string speedTestPhase: ""
  property string speedTestDownload: ""
  property string speedTestUpload: ""
  property string speedTestError: ""
  property string speedTestStderr: ""
  // Distingue l'arret volontaire en fin de phase d'un vrai echec du helper.
  property bool speedTestExpectedStop: false

  function runSpeedTest() {
    if (speedTestProc.running || !online) return

    speedTestError = ""
    speedTestDownload = ""
    speedTestUpload = ""
    speedTestHasRun = true
    speedTestRunning = true
    startSpeedTestPhase("down")
  }

  function startSpeedTestPhase(phase) {
    speedTestExpectedStop = false
    speedTestPhase = phase
    speedTestStderr = ""
    speedTestProc.command = ["omarchy-network-speedtest", phase]
    speedTestProc.running = true
    speedTestPhaseTimer.restart()
  }

  function stopSpeedTestPhase() {
    speedTestPhaseTimer.stop()
    if (speedTestProc.running) {
      speedTestExpectedStop = true
      speedTestProc.running = false
      return
    }
    finishSpeedTestPhase()
  }

  function finishSpeedTestPhase() {
    if (speedTestPhase === "down") {
      startSpeedTestPhase("up")
      return
    }

    speedTestPhase = ""
    speedTestRunning = false
    speedTestExpectedStop = false
  }

  function updateSpeedTestLine(line) {
    var value = parseFloat(line)
    if (!isFinite(value) || value < 0) return

    if (speedTestPhase === "down") speedTestDownload = String(value)
    else if (speedTestPhase === "up") speedTestUpload = String(value)
    speedTestError = ""
  }

  function formatMbps(raw) {
    if (!raw) return "—"

    var value = Number(raw)
    if (!isFinite(value) || value <= 0) return "—"
    return (value < 10 ? value.toFixed(1) : Math.round(value)) + " Mb/s"
  }

  Process {
    id: speedTestProc

    stdout: SplitParser {
      onRead: function(line) { root.updateSpeedTestLine(line) }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.speedTestStderr = String(text || "").trim()
    }
    onExited: function(exitCode) {
      speedTestPhaseTimer.stop()

      if (!root.speedTestExpectedStop && exitCode !== 0) {
        root.speedTestError = root.speedTestStderr || "Speed test failed"
        root.speedTestPhase = ""
        root.speedTestRunning = false
        return
      }

      root.speedTestExpectedStop = false
      root.finishSpeedTestPhase()
    }
  }

  Timer {
    id: speedTestPhaseTimer
    interval: 5000
    onTriggered: root.stopSpeedTestPhase()
  }

  // Le test sature volontairement le lien : le laisser courir apres la
  // fermeture du panneau gaspillerait de la bande passante sans rien afficher.
  function abortSpeedTest() {
    if (!speedTestRunning) return

    speedTestPhaseTimer.stop()
    speedTestPhase = ""
    speedTestRunning = false
    speedTestExpectedStop = true
    speedTestProc.running = false
  }

  // --- DNS -------------------------------------------------------------------

  readonly property var dnsProviders: ["DHCP", "Cloudflare", "Google", "Custom"]

  function setDns(provider) {
    if (!provider || actionProc.running) return

    // « Custom » demande une saisie : le helper s'en charge dans un terminal.
    if (provider === "Custom") {
      if (bar) bar.run("omarchy-launch-floating-terminal-with-presentation omarchy-dns " + Util.shellQuote(provider))
      close()
      return
    }

    actionProc.command = ["omarchy-dns", String(provider)]
    actionProc.running = true
    dnsProvider = provider
    close()
  }

  // --- Glyphes ---------------------------------------------------------------
  // Memes codepoints Nerd Font que le widget natif.

  readonly property var wifiGlyphs: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
  readonly property string glyphEthernet: "󰈀"
  readonly property string glyphOffline: "󰤮"
  readonly property string glyphLocked: "󰌾"
  readonly property string glyphFailed: "󰅙"

  function wifiGlyphFor(strength) {
    var index = Math.max(0, Math.min(4, Math.ceil(Number(strength || 0) / 20) - 1))
    return wifiGlyphs[index]
  }

  function connectionGlyph() {
    if (linkType === "wifi") return wifiGlyphFor(signalStrength)
    if (linkType === "ethernet") return glyphEthernet
    return glyphOffline
  }

  function connectionLabel() {
    if (linkType === "wifi") return String(info.ssid || "Wi-Fi")
    if (linkType === "ethernet") return "Wired"
    return "Offline"
  }

  // --- Ouverture -------------------------------------------------------------

  property bool opened: false

  function open() {
    opened = true
  }

  function close() {
    opened = false
    closePasswordPrompt()
  }

  function toggle() {
    opened ? close() : open()
  }

  function closeForPopoutSwitch() {
    close()
  }

  onOpenedChanged: {
    if (opened) {
      cursor = 0
      cursorActive = false
      refresh(true)
      return
    }

    // Le scan comme le test de debit consomment : on les coupe a la fermeture.
    if (wifiDevice) wifiDevice.scannerEnabled = false
    abortSpeedTest()
  }

  readonly property bool primaryInstance: {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screens = Quickshell.screens
    return !!window && screens.length > 0 && window.screen === screens[0]
  }

  IpcHandler {
    enabled: root.primaryInstance
    target: "menubar.network"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function speedtest(): void { root.open(); root.runSpeedTest() }
  }

  // --- Curseur clavier -------------------------------------------------------

  property int cursor: 0
  property bool cursorActive: false

  readonly property var rows: {
    var list = []
    if (online) list.push({ kind: "speed", index: 0 })
    for (var i = 0; i < dnsProviders.length; i++) list.push({ kind: "dns", index: i })
    for (var j = 0; j < wifiRows.length; j++) list.push({ kind: "wifi", index: j })
    return list
  }

  function rowIndexOf(kind, index) {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].kind === kind && rows[i].index === index) return i
    }
    return -1
  }

  function moveCursor(delta) {
    cursor = Math.max(0, Math.min(rows.length - 1, cursor + delta))
  }

  function activateCursor() {
    var row = cursor >= 0 && cursor < rows.length ? rows[cursor] : null
    if (!row) return

    if (row.kind === "speed") runSpeedTest()
    else if (row.kind === "dns") setDns(dnsProviders[row.index])
    else if (row.kind === "wifi") {
      var target = wifiRows[row.index]
      if (!target) return
      target.connected ? disconnectRow(target) : connectRow(target)
    }
  }

  function pointCursorAt(kind, index) {
    var position = rowIndexOf(kind, index)
    if (position < 0) return

    cursorActive = true
    cursor = position
  }

  // --- Bouton de barre -------------------------------------------------------

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Rectangle {
    x: button.x
    y: button.y
    width: button.width
    height: button.height
    radius: root.islandRadius
    color: root.accentColor
    opacity: button.tooltipHovered || root.opened ? root.accentFillOpacity : 0

    Behavior on opacity {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }
  }

  WidgetButton {
    id: button

    bar: root.bar
    text: root.connectionGlyph()
    tooltipText: root.online
      ? root.connectionLabel() + (root.ipAddress ? " · " + root.ipAddress : "")
      : "Offline"
    fixedWidth: root.vertical ? root.islandSize : Math.max(Style.space(24), root.islandRadius * 2)
    fixedHeight: root.islandSize
    // L'encre du glyphe ethernet ne remplit pas sa boite symetriquement : elle
    // penche de 1,5 px vers la droite. `rightExtraMargin` decale le label de la
    // moitie de sa valeur vers la gauche, ce qui le recentre dans l'ilot sans
    // toucher a la largeur, tenue par `fixedWidth`. La compensation suit
    // l'echelle du theme, comme le bearing qu'elle corrige.
    rightExtraMargin: 3
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) {
        if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation nmtui")
      } else {
        root.toggle()
      }
    }
  }

  // --- Panneau ---------------------------------------------------------------

  KeyboardPanel {
    id: panel

    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      // La saisie du mot de passe prend la main : on gele la navigation tant
      // qu'elle est ouverte.
      blocked: root.passwordSsid !== ""

      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) {
          root.cursorActive = true
          return
        }
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh(true)
      }

      ScrollView {
        id: scrollArea

        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: content.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        opacity: root.opened ? 1 : 0
        scale: root.opened ? 1 : 0.97
        transformOrigin: root.transformOriginForBar

        transform: Translate {
          x: root.opened ? 0 : root.revealOffsetX
          y: root.opened ? 0 : root.revealOffsetY

          Behavior on x { NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing } }
          Behavior on y { NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing } }
        }

        Behavior on opacity { NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing } }
        Behavior on scale { NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing } }

        Column {
          id: content

          width: scrollArea.availableWidth
          spacing: Style.space(12)

          // ---- Connexion courante ----
          PanelIsland {

            Item {
              width: parent.width
              implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

              Text {
                id: heroIcon

                text: root.connectionGlyph()
                color: root.online ? root.accentColor : root.foregroundColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                opacity: root.online ? 1 : 0.5
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                id: heroLabels

                anchors.left: heroIcon.right
                anchors.leftMargin: Style.space(14)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  text: root.connectionLabel()
                  color: root.foregroundColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: root.online
                    ? (root.ipAddress || "No address") + (root.formatLinkSpeed(root.info.speed) ? " · " + root.formatLinkSpeed(root.info.speed) : "")
                    : "NOT CONNECTED"
                  color: root.mutedColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1.2
                  elide: Text.ElideRight
                  width: parent.width
                }
              }
            }
          }

          // ---- Details du lien ----
          PanelIsland {
            visible: root.online

            SectionHeader { text: "LINK" }

            DetailRow { label: "Gateway"; value: root.gateway || "—" }
            DetailRow { label: "Download"; value: root.formatRate(root.downloadRate) }
            DetailRow { label: "Upload"; value: root.formatRate(root.uploadRate) }
            DetailRow { label: "Router"; value: root.formatPing(root.info.router_ping_ms) }
            DetailRow { label: "Internet"; value: root.formatPing(root.info.internet_ping_ms) }
          }

          // ---- Test de debit ----
          PanelIsland {
            id: speedIsland

            visible: root.online

            SectionHeader {
              text: "SPEED TEST"
              value: root.speedTestRunning
                ? (root.speedTestPhase === "down" ? "DOWNLOADING" : "UPLOADING")
                : ""
            }

            DetailRow {
              visible: root.speedTestHasRun
              label: "Download"
              value: root.formatMbps(root.speedTestDownload)
            }

            DetailRow {
              visible: root.speedTestHasRun
              label: "Upload"
              value: root.formatMbps(root.speedTestUpload)
            }

            Text {
              text: root.speedTestError
              visible: root.speedTestError !== ""
              color: root.accentColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
            }

            CursorSurface {
              width: parent.width
              height: Style.space(30)
              hasCursor: root.cursorActive && root.cursor === root.rowIndexOf("speed", 0)
              foreground: root.foregroundColor
              accent: root.accentColor

              HoverHandler {
                onHoveredChanged: if (hovered) root.pointCursorAt("speed", 0)
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: !root.speedTestRunning
                onClicked: root.runSpeedTest()
              }

              Text {
                text: root.speedTestRunning ? "Measuring…" : (root.speedTestHasRun ? "Run again" : "Run speed test")
                color: root.speedTestRunning ? root.accentColor : root.foregroundColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          // ---- Resolveur DNS ----
          PanelIsland {

            SectionHeader { text: "DNS"; value: root.dnsProvider }

            Repeater {
              model: root.dnsProviders

              DnsRow {
                required property var modelData
                required property int index

                width: parent.width
                provider: modelData
                rowIndex: index
              }
            }
          }

          // ---- Reseaux Wi-Fi ----
          PanelIsland {
            visible: root.wifiAvailable

            SectionHeader {
              text: "WI-FI"
              value: root.scanning ? "SCANNING" : ""
            }

            Repeater {
              model: root.wifiRows

              WifiRow {
                required property var modelData
                required property int index

                width: parent.width
                row: modelData
                rowIndex: index
              }
            }

            Text {
              text: root.scanning ? "Scanning…" : "No networks in range"
              visible: root.wifiRows.length === 0
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              width: parent.width
            }
          }
        }
      }
    }
  }

  // --- Composants internes ---------------------------------------------------

  component PanelIsland: Rectangle {
    default property alias content: holder.data
    property int padding: Style.space(10)

    width: parent.width
    implicitHeight: holder.implicitHeight + padding * 2
    radius: Style.cornerRadius
    color: root.islandFill

    Column {
      id: holder

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: parent.padding
      spacing: Style.space(4)
    }
  }

  component SectionHeader: Item {
    id: sectionHeader

    property alias text: header.text
    property string value: ""

    width: parent.width
    implicitHeight: Math.max(header.implicitHeight, valueLabel.implicitHeight)

    PanelSectionHeader {
      id: header

      foreground: root.foregroundColor
      fontFamily: root.fontFamily
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: valueLabel

      text: sectionHeader.value
      visible: text !== ""
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Ligne d'information : intitule a gauche, mesure a droite.
  component DetailRow: Item {
    id: detailRow

    property string label: ""
    property string value: ""

    width: parent.width
    implicitHeight: Style.space(20)

    Text {
      text: detailRow.label
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      anchors.left: parent.left
      anchors.leftMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: detailRow.value
      color: root.foregroundColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      anchors.right: parent.right
      anchors.rightMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  component DnsRow: CursorSurface {
    id: dnsRow

    required property string provider
    required property int rowIndex

    readonly property bool selected: root.dnsProvider === provider

    height: Style.space(28)
    hasCursor: root.cursorActive && root.cursor === root.rowIndexOf("dns", rowIndex)
    current: selected
    foreground: root.foregroundColor
    accent: root.accentColor

    HoverHandler {
      onHoveredChanged: if (hovered) root.pointCursorAt("dns", dnsRow.rowIndex)
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.setDns(dnsRow.provider)
    }

    Text {
      text: dnsRow.provider
      color: dnsRow.selected ? root.accentColor : root.foregroundColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: dnsRow.selected
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    Rectangle {
      width: Style.space(6)
      height: width
      radius: width / 2
      color: root.accentColor
      visible: dnsRow.selected
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Ligne de reseau Wi-Fi : force, nom, cadenas, et champ mot de passe deploye
  // pour un reseau protege encore inconnu.
  component WifiRow: CursorSurface {
    id: wifiRow

    required property var row
    required property int rowIndex

    readonly property bool prompting: root.passwordSsid === row.ssid
    readonly property bool acting: root.actionSsid === row.ssid && root.actionKind !== ""
    readonly property bool failed: root.failureSsid === row.ssid && root.failureReason !== ""

    height: prompting ? Style.space(64) : Style.space(30)
    hasCursor: root.cursorActive && root.cursor === root.rowIndexOf("wifi", rowIndex)
    current: row.connected
    foreground: root.foregroundColor
    accent: root.accentColor

    Behavior on height {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }

    HoverHandler {
      onHoveredChanged: if (hovered) root.pointCursorAt("wifi", wifiRow.rowIndex)
    }

    MouseArea {
      anchors.fill: parent
      anchors.bottomMargin: wifiRow.prompting ? Style.space(34) : 0
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      enabled: !root.busy || wifiRow.acting
      onClicked: function(mouse) {
        // Clic droit sur un reseau connu : on l'oublie.
        if (mouse.button === Qt.RightButton) {
          if (wifiRow.row.known) root.forgetRow(wifiRow.row)
          return
        }
        if (wifiRow.row.connected) root.disconnectRow(wifiRow.row)
        else root.connectRow(wifiRow.row)
      }
    }

    Row {
      id: wifiHeader

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      height: Style.space(30)
      spacing: Style.space(8)

      Text {
        text: root.wifiGlyphFor(wifiRow.row.strength)
        color: wifiRow.row.connected ? root.accentColor : root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        width: Style.space(20)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: wifiRow.row.ssid
        color: wifiRow.row.connected ? root.accentColor : root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: wifiRow.row.connected
        elide: Text.ElideRight
        width: parent.width - Style.space(72)
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: {
          if (wifiRow.acting) {
            if (root.actionKind === "connect") return "…"
            if (root.actionKind === "disconnect") return "…"
            return "…"
          }
          if (wifiRow.failed) return root.glyphFailed
          return root.isProtected(wifiRow.row) ? root.glyphLocked : ""
        }
        color: wifiRow.failed ? root.accentColor : root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.iconSmall
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    // Saisie de la phrase secrete, deployee sous la ligne.
    Row {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: wifiHeader.bottom
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      height: Style.space(30)
      spacing: Style.space(6)
      visible: wifiRow.prompting
      opacity: wifiRow.prompting ? 1 : 0

      Behavior on opacity {
        NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
      }

      TextField {
        id: passwordField

        width: parent.width - Style.space(76)
        text: root.passwordText
        password: true
        foreground: root.foregroundColor
        accent: root.accentColor
        anchors.verticalCenter: parent.verticalCenter
        onTextChanged: root.passwordText = text
        Keys.onReturnPressed: root.connectWithPassphrase(wifiRow.row, root.passwordText)
        Keys.onEnterPressed: root.connectWithPassphrase(wifiRow.row, root.passwordText)
        Keys.onEscapePressed: root.closePasswordPrompt()

        // Le champ prend le focus des qu'il apparait, sinon la frappe part
        // dans le gestionnaire de touches du panneau.
        onVisibleChanged: if (visible) forceActiveFocus()
      }

      Button {
        text: "Join"
        foreground: root.foregroundColor
        accent: root.accentColor
        anchors.verticalCenter: parent.verticalCenter
        onClicked: root.connectWithPassphrase(wifiRow.row, root.passwordText)
      }
    }
  }
}
