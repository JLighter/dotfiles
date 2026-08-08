import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Widget de charge systeme : CPU et memoire dans la barre, detail au clic.
//
// Tout vient de `system_stats.sh`, pose a cote de ce fichier, qui rassemble en
// un seul appel ce que /proc et /sys exposent. Les compteurs CPU arrivent
// bruts : le pourcentage se calcule ici, par difference entre deux releves,
// car /proc/stat ne donne que des cumuls depuis le demarrage.
BarWidget {
  id: root
  moduleName: "local.menubar.system"

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
  readonly property int haloInsetX: bar && bar.islandPaddingX !== undefined ? bar.islandPaddingX : 0
  readonly property int haloInsetY: bar && bar.islandPaddingY !== undefined ? bar.islandPaddingY : 0

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

  // Au-dela de ce seuil, la mesure passe en accent.
  readonly property int alertThreshold: 80

  // --- Etat ------------------------------------------------------------------

  property real cpuPercent: 0
  property var corePercents: []
  property real memTotalKib: 0
  property real memUsedKib: 0
  property real swapTotalKib: 0
  property real swapUsedKib: 0
  property var loadAverages: []
  property real uptimeSeconds: 0
  property var temperatures: []
  property var topCpu: []
  property var topMem: []

  readonly property real memPercent: memTotalKib > 0 ? memUsedKib / memTotalKib * 100 : 0
  readonly property real swapPercent: swapTotalKib > 0 ? swapUsedKib / swapTotalKib * 100 : 0

  // Releve precedent, pour les differences de compteurs CPU.
  property real prevCpuIdle: -1
  property real prevCpuTotal: -1
  property var prevCores: ({})

  function ratioFromDelta(idle, total, previousIdle, previousTotal) {
    if (previousIdle < 0 || previousTotal < 0) return 0

    var totalDelta = total - previousTotal
    if (totalDelta <= 0) return 0

    var busy = totalDelta - (idle - previousIdle)
    return Math.max(0, Math.min(100, busy / totalDelta * 100))
  }

  function parseStats(raw) {
    var nextCores = []
    var nextCoreState = ({})
    var nextTemps = []
    var nextTopCpu = []
    var nextTopMem = []
    var lines = String(raw || "").split("\n")

    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].split("\t")
      var key = parts[0]

      if (key === "cpu" && parts.length >= 3) {
        var idle = Number(parts[1])
        var total = Number(parts[2])
        cpuPercent = ratioFromDelta(idle, total, prevCpuIdle, prevCpuTotal)
        prevCpuIdle = idle
        prevCpuTotal = total
      } else if (key === "core" && parts.length >= 4) {
        var coreName = parts[1]
        var coreIdle = Number(parts[2])
        var coreTotal = Number(parts[3])
        var previous = prevCores[coreName]
        nextCores.push(ratioFromDelta(coreIdle, coreTotal,
                                      previous ? previous.idle : -1,
                                      previous ? previous.total : -1))
        nextCoreState[coreName] = { idle: coreIdle, total: coreTotal }
      } else if (key === "mem" && parts.length >= 3) {
        memTotalKib = Number(parts[1])
        memUsedKib = Number(parts[2])
      } else if (key === "swap" && parts.length >= 3) {
        swapTotalKib = Number(parts[1])
        swapUsedKib = Number(parts[2])
      } else if (key === "load" && parts.length >= 4) {
        loadAverages = [parts[1], parts[2], parts[3]]
      } else if (key === "uptime" && parts.length >= 2) {
        uptimeSeconds = Number(parts[1])
      } else if (key === "temp" && parts.length >= 3) {
        nextTemps.push({ label: parts[1], celsius: Number(parts[2]) / 1000 })
      } else if (key === "topcpu" && parts.length >= 4) {
        nextTopCpu.push({ cpu: Number(parts[1]), mem: Number(parts[2]), name: parts[3] })
      } else if (key === "topmem" && parts.length >= 4) {
        nextTopMem.push({ cpu: Number(parts[1]), mem: Number(parts[2]), name: parts[3] })
      }
    }

    // Reaffectation en bloc : muter un tableau en place ne notifie pas les
    // bindings qui en dependent.
    corePercents = nextCores
    prevCores = nextCoreState
    temperatures = nextTemps
    topCpu = nextTopCpu
    topMem = nextTopMem
  }

  Process {
    id: statsProc

    readonly property string scriptPath: String(Qt.resolvedUrl("system_stats.sh")).replace(/^file:\/\//, "")

    command: ["bash", scriptPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStats(text)
    }
  }

  // Cadence resserree quand le panneau est ouvert, relachee sinon : la barre
  // n'a besoin que d'une tendance, et chaque releve forke awk et ps.
  Timer {
    interval: root.opened ? 1500 : 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statsProc.running) statsProc.running = true
  }

  // --- Formatage -------------------------------------------------------------

  function formatGib(kib) {
    var gib = Number(kib || 0) / 1048576
    return gib >= 10 ? gib.toFixed(0) + " GiB" : gib.toFixed(1) + " GiB"
  }

  function formatUptime(seconds) {
    var total = Math.max(0, Math.floor(Number(seconds || 0)))
    var days = Math.floor(total / 86400)
    var hours = Math.floor((total % 86400) / 3600)
    var minutes = Math.floor((total % 3600) / 60)

    if (days > 0) return days + " d " + hours + " h"
    if (hours > 0) return hours + " h " + minutes + " min"
    return minutes + " min"
  }

  function alertColorFor(percent) {
    return Number(percent || 0) >= root.alertThreshold ? root.accentColor : root.foregroundColor
  }

  // Glyphes Nerd Font, verifies presents dans JetBrainsMono.
  readonly property string glyphCpu: "󰻠"
  readonly property string glyphMemory: "󰍛"
  readonly property string glyphTemperature: "󰔏"
  readonly property string glyphLoad: "󰓅"

  // --- Ouverture -------------------------------------------------------------

  property bool opened: false

  function open() {
    opened = true
    if (!statsProc.running) statsProc.running = true
  }

  function close() {
    opened = false
  }

  function toggle() {
    opened ? close() : open()
  }

  function closeForPopoutSwitch() {
    close()
  }

  readonly property bool primaryInstance: {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screens = Quickshell.screens
    return !!window && screens.length > 0 && window.screen === screens[0]
  }

  IpcHandler {
    enabled: root.primaryInstance
    target: "menubar.system"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  // --- Bouton de barre -------------------------------------------------------

  // Au repos, seule la puce occupe la barre ; les mesures se deplient au
  // survol. Pas de tooltip : ce serait dire deux fois la meme chose.
  // Largeur impaire volontairement : l'ilot fait alors une largeur impaire lui
  // aussi, son centre tombe sur un pixel entier et le glyphe — 9 pixels d'encre
  // — s'y aligne exactement. Avec une largeur paire, le centrage tombe entre
  // deux pixels et laisse un demi-pixel d'ecart, d'un cote ou de l'autre.
  readonly property int glyphWidth: Style.space(15)
  readonly property int contentGap: Style.space(5)
  readonly property bool valuesRevealed: widgetHover.hovered || opened
  property int valuesExtent: valuesRevealed ? valuesLabel.implicitWidth + contentGap : 0

  Behavior on valuesExtent {
    NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
  }

  // L'ensemble passe en accent des qu'une des deux mesures s'emballe.
  readonly property color readingColor: cpuPercent >= alertThreshold || memPercent >= alertThreshold
    ? accentColor
    : foregroundColor

  implicitWidth: contentGap + glyphWidth + valuesExtent + contentGap
  implicitHeight: islandSize

  HoverHandler { id: widgetHover }

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -root.haloInsetX
    anchors.rightMargin: -root.haloInsetX
    anchors.topMargin: -root.haloInsetY
    anchors.bottomMargin: -root.haloInsetY
    radius: root.islandRadius
    color: root.accentColor
    opacity: root.valuesRevealed ? root.accentFillOpacity : 0

    Behavior on opacity {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }
  }

  Text {
    id: glyphLabel

    // L'encre de la puce ne remplit pas sa boite symetriquement : elle penche
    // vers la droite. On decale la boite d'autant, a l'echelle du theme comme
    // le bearing qu'elle corrige.
    x: root.contentGap - Style.spaceReal(1)
    width: root.glyphWidth
    text: root.glyphCpu
    color: root.readingColor
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    anchors.verticalCenter: parent.verticalCenter
  }

  // Les mesures glissent hors du cadre quand celui-ci se replie.
  Item {
    x: root.contentGap + root.glyphWidth
    width: root.valuesExtent
    height: parent.height
    clip: true

    Text {
      id: valuesLabel

      x: root.contentGap
      text: Math.round(root.cpuPercent) + "%  " + root.glyphMemory + " " + Math.round(root.memPercent) + "%"
      color: root.readingColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      renderType: Text.NativeRendering
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: button

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        if (root.bar) root.bar.run("omarchy-launch-or-focus-tui btop")
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
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(760))

    PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      onCloseRequested: root.close()

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

          // ---- En-tete ----
          PanelIsland {

            Item {
              width: parent.width
              implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

              Text {
                id: heroIcon

                text: root.glyphCpu
                color: root.alertColorFor(root.cpuPercent)
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
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
                  text: "System"
                  color: root.foregroundColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: "UP " + root.formatUptime(root.uptimeSeconds).toUpperCase()
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

          // ---- Processeur ----
          PanelIsland {

            SectionHeader {
              text: "CPU"
              value: Math.round(root.cpuPercent) + "%"
              alert: root.cpuPercent >= root.alertThreshold
            }

            Gauge { value: root.cpuPercent }

            DetailRow {
              label: "Load average"
              value: root.loadAverages.length === 3
                ? root.loadAverages[0] + "  " + root.loadAverages[1] + "  " + root.loadAverages[2]
                : "—"
            }

            DetailRow {
              label: "Cores"
              value: String(root.corePercents.length)
            }

            // Une colonne par coeur, hauteur proportionnelle a sa charge.
            Item {
              width: parent.width
              implicitHeight: Style.space(26)
              visible: root.corePercents.length > 0

              Row {
                id: coreRow

                anchors.fill: parent
                anchors.topMargin: Style.space(4)
                spacing: Style.space(2)

                readonly property int columnWidth: root.corePercents.length > 0
                  ? (width - spacing * (root.corePercents.length - 1)) / root.corePercents.length
                  : 0

                Repeater {
                  model: root.corePercents

                  Item {
                    required property var modelData

                    width: coreRow.columnWidth
                    height: coreRow.height

                    Rectangle {
                      anchors.bottom: parent.bottom
                      width: parent.width
                      height: Math.max(Style.space(2), parent.height * Math.max(0, Math.min(100, modelData)) / 100)
                      radius: Style.space(1)
                      color: modelData >= root.alertThreshold ? root.accentColor : root.foregroundColor
                      opacity: modelData >= root.alertThreshold ? 1 : 0.45

                      Behavior on height {
                        NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
                      }
                    }
                  }
                }
              }
            }
          }

          // ---- Memoire ----
          PanelIsland {

            SectionHeader {
              text: "MEMORY"
              value: Math.round(root.memPercent) + "%"
              alert: root.memPercent >= root.alertThreshold
            }

            Gauge { value: root.memPercent }

            DetailRow {
              label: "Used"
              value: root.formatGib(root.memUsedKib) + " / " + root.formatGib(root.memTotalKib)
            }

            DetailRow {
              label: "Swap"
              visible: root.swapTotalKib > 0
              value: root.formatGib(root.swapUsedKib) + " / " + root.formatGib(root.swapTotalKib)
            }
          }

          // ---- Temperatures ----
          PanelIsland {
            visible: root.temperatures.length > 0

            SectionHeader { text: "TEMPERATURES" }

            Repeater {
              model: root.temperatures

              DetailRow {
                required property var modelData

                width: parent.width
                label: modelData.label
                value: Math.round(modelData.celsius) + " °C"
              }
            }
          }

          // ---- Processus les plus gourmands ----
          PanelIsland {
            visible: root.topCpu.length > 0

            SectionHeader { text: "TOP CPU" }

            Repeater {
              model: root.topCpu

              DetailRow {
                required property var modelData

                width: parent.width
                label: modelData.name
                value: modelData.cpu.toFixed(1) + "%"
              }
            }
          }

          PanelIsland {
            visible: root.topMem.length > 0

            SectionHeader { text: "TOP MEMORY" }

            Repeater {
              model: root.topMem

              DetailRow {
                required property var modelData

                width: parent.width
                label: modelData.name
                value: modelData.mem.toFixed(1) + "%"
              }
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
    property bool alert: false

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
      color: sectionHeader.alert ? root.accentColor : root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  component DetailRow: Item {
    id: detailRow

    property string label: ""
    property string value: ""

    width: parent.width
    implicitHeight: Style.space(18)

    Text {
      text: detailRow.label
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      width: parent.width - Style.space(90)
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

  component Gauge: Rectangle {
    id: gauge

    property real value: 0

    width: parent.width - Style.space(4)
    x: Style.space(2)
    height: Math.max(3, Style.space(4))
    radius: height / 2
    color: root.bar ? Style.selectedFillFor(root.bar.foreground, Color.accent) : Color.muted

    Rectangle {
      width: parent.width * Math.max(0, Math.min(100, gauge.value)) / 100
      height: parent.height
      radius: parent.radius
      color: root.accentColor

      Behavior on width {
        NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
      }
    }
  }
}
