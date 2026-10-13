import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Widget de charge systeme : CPU et memoire dans la barre, tableau de bord au clic.
//
// Le bouton de barre est celui de la menubar (puce, mesures au survol, halo
// d'accent). Le panneau reprend celui de omarchy-system-monitor (Harshith
// Chennupati, MIT, voir NOTICE ; Panel.qml au commit 71599f7) : en-tete hote, tuiles CPU /
// memoire / temperature, tuiles GPU, historique deux minutes, charge par coeur,
// debit disque, capacite, bouton btop. Ecarts a l'amont : GPU NVIDIA
// via nvidia-smi (l'amont ne le lit pas), pas de capteurs ni de ventilateurs
// Apple Silicon, pas de mode d'affichage de barre a faire tourner, tuiles en
// ilots sans lisere comme le reste de la menubar, et section reseau deplacee
// dans le widget Network (ilot NET).
//
// La collecte vit dans SystemMetrics.qml, la logique pure dans SystemMetrics.js.
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

  // Teintes du panneau. L'accent porte les mesures, sa version assombrie la
  // seconde serie d'un graphe ; l'avertissement est un melange accent/urgent,
  // la palette n'ayant pas de role « warning » propre.
  readonly property color urgentColor: Color.urgent
  readonly property color secondaryColor: Qt.darker(accentColor, 1.5)
  readonly property color warningColor: Qt.tint(accentColor, Qt.rgba(urgentColor.r, urgentColor.g, urgentColor.b, 0.6))
  readonly property color trackColor: Qt.rgba(foregroundColor.r, foregroundColor.g, foregroundColor.b, 0.12)
  readonly property color chartGrid: Qt.rgba(foregroundColor.r, foregroundColor.g, foregroundColor.b, 0.18)

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

  // --- Seuils ----------------------------------------------------------------

  // Bouton de barre : au-dela, la puce et ses mesures passent en accent.
  readonly property int alertThreshold: 80

  // Le GPU a son propre seuil thermique : une carte a 100 % de charge pendant un
  // rendu est normale, une carte a 80 °C ne l'est pas. Les deux conditions comptent.
  readonly property int gpuTempAlertThreshold: 80

  // Panneau : jauges en avertissement puis en critique, comme l'amont.
  readonly property real warningThreshold: 80
  readonly property real criticalThreshold: 95

  // Une temperature n'occupe qu'une bande utile : 57 °C dessine comme 57 % d'une
  // jauge ferait passer une puce froide pour a moitie chargee. L'echelle part de 30.
  readonly property real temperatureFloor: 30
  readonly property real temperatureCeiling: 100

  // --- Mesures ---------------------------------------------------------------

  SystemMetrics {
    id: metrics
    panelOpen: root.opened
  }

  readonly property bool hasGpuUsage: metrics.gpuPercent >= 0
  readonly property bool hasGpuTemperature: metrics.gpuTemperature >= 0
  readonly property bool hasGpuVram: metrics.gpuVramTotal > 0 && metrics.gpuVramUsed >= 0
  readonly property bool hasGpu: hasGpuUsage || hasGpuTemperature
  readonly property int gpuTileCount: (hasGpuUsage ? 1 : 0) + (hasGpuTemperature ? 1 : 0) + (hasGpuVram ? 1 : 0)

  readonly property real gpuVramPercent: hasGpuVram
    ? Math.max(0, Math.min(100, metrics.gpuVramUsed * 100 / metrics.gpuVramTotal))
    : -1

  readonly property bool gpuAlert: metrics.gpuPercent >= alertThreshold
    || metrics.gpuTemperature >= gpuTempAlertThreshold

  // --- Formatage -------------------------------------------------------------

  function percent(value) {
    return isFinite(value) && value >= 0 ? Math.round(value) + "%" : "—"
  }

  function formatBytes(value) {
    var amount = Number(value)
    if (!isFinite(amount) || amount < 0) return "—"
    var units = ["B", "KiB", "MiB", "GiB", "TiB"]
    var index = 0
    while (amount >= 1024 && index < units.length - 1) {
      amount /= 1024
      index++
    }
    var digits = index >= 3 ? 1 : (amount >= 100 ? 0 : 1)
    return amount.toFixed(digits) + " " + units[index]
  }

  // « 3.6 / 7.3 GiB » : une seule unite pour la paire, qui reste assez courte
  // pour une tuile d'un tiers de panneau.
  function formatPair(used, total) {
    var totalBytes = Number(total)
    if (!isFinite(totalBytes) || totalBytes <= 0) return "—"
    var units = ["B", "KiB", "MiB", "GiB", "TiB"]
    var index = 0
    var scale = 1
    while (totalBytes / scale >= 1024 && index < units.length - 1) {
      scale *= 1024
      index++
    }
    var digits = index >= 3 ? 1 : 0
    return (Number(used) / scale).toFixed(digits) + " / " + (totalBytes / scale).toFixed(digits) + " " + units[index]
  }

  function formatRate(value) {
    return isFinite(value) && value >= 0 ? formatBytes(value) + "/s" : "—"
  }

  function formatUptime(seconds) {
    var totalMinutes = Math.floor(Number(seconds) / 60)
    if (!isFinite(totalMinutes) || totalMinutes < 0) return "—"
    var days = Math.floor(totalMinutes / 1440)
    var hours = Math.floor((totalMinutes % 1440) / 60)
    var minutes = totalMinutes % 60
    if (days > 0) return days + "d " + hours + "h"
    if (hours > 0) return hours + "h " + minutes + "m"
    return minutes + "m"
  }

  function loadText() {
    function one(value) { return value >= 0 ? value.toFixed(2) : "—" }
    return one(metrics.loadOne) + " / " + one(metrics.loadFive) + " / " + one(metrics.loadFifteen)
  }

  function temperatureText(value) {
    return value >= 0 ? Math.round(value) + "°C" : "—"
  }

  function temperatureDetail(value) {
    if (value < 0) return "Unavailable"
    return value >= 85 ? "Warm" : "Normal"
  }

  function temperatureBandMeter(value) {
    if (!isFinite(value) || value < 0) return -1
    var span = temperatureCeiling - temperatureFloor
    return Math.max(0, Math.min(100, (value - temperatureFloor) * 100 / span))
  }

  function levelColor(value, warn, crit) {
    if (!isFinite(value) || value < 0) return root.mutedColor
    if (value >= crit) return root.urgentColor
    if (value >= warn) return root.warningColor
    return root.accentColor
  }

  // Row ignore les enfants invisibles : le diviseur est le nombre de tuiles
  // que cette carte sait remplir.
  function gpuTileWidth(rowWidth, spacing) {
    var count = Math.max(1, gpuTileCount)
    return (rowWidth - spacing * (count - 1)) / count
  }

  // nvme0n1 → nvme0, mmcblk0 → mmc0 ; sda et consorts sont deja courts.
  function shortDiskName(name) {
    var text = String(name || "")
    var nvme = text.match(/^nvme(\d+)n\d+$/)
    if (nvme) return "nvme" + nvme[1]
    var mmc = text.match(/^mmcblk(\d+)$/)
    if (mmc) return "mmc" + mmc[1]
    return text
  }

  // La ligne donne un debit cumule : passe le premier disque, les noms ne
  // disent plus rien, on les resume en un compte.
  function diskLabelText() {
    var devices = metrics.diskDevices
    if (!devices || devices.length === 0) return "DISK"
    if (devices.length === 1) return "DISK · " + shortDiskName(devices[0])
    return "DISK · " + shortDiskName(devices[0]) + " +" + (devices.length - 1)
  }

  function mountBasename(mount) {
    var segments = String(mount).split("/")
    return segments[segments.length - 1] || String(mount)
  }

  // Dernier segment du chemin (/mnt/data → « data ») ; chemin complet quand
  // deux montages partagent ce segment.
  function mountLabel(mount) {
    var target = String(mount)
    var base = mountBasename(target)
    var mounts = metrics.extraFilesystems
    for (var i = 0; i < mounts.length; i++) {
      var other = String(mounts[i].mount)
      if (other !== target && mountBasename(other) === base) return target
    }
    return base
  }

  // Glyphes Nerd Font, verifies presents dans JetBrainsMono.
  readonly property string glyphCpu: "󰻠"
  // RAM et VRAM cote a cote dans la barre : quatre formes distinctes pour
  // quatre mesures (puce CPU, barrette RAM, carte GPU, carte memoire VRAM),
  // sinon rien ne dit quel pourcentage est lequel. Verifies au rendu a la
  // taille de la barre : la puce « memory » (U+F035B) se confond avec la puce CPU.
  readonly property string glyphMemory: ""
  readonly property string glyphVram: "󰑹"
  readonly property string glyphGpu: "󰢮"

  // --- Ouverture -------------------------------------------------------------

  property bool opened: false

  function open() {
    opened = true
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

  function launchBtop() {
    if (bar) bar.run("omarchy-launch-or-focus-tui btop")
    close()
  }

  // Curseur clavier sur le bouton btop, seul element actionnable du panneau.
  property bool cursorActive: false

  onOpenedChanged: if (opened) cursorActive = false

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
    function refresh(): string { metrics.sample(); return "ok" }
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

  // L'ensemble passe en accent des qu'une des mesures s'emballe.
  readonly property color readingColor: metrics.cpuPercent >= alertThreshold
      || metrics.memoryPercent >= alertThreshold
      || gpuAlert
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

      // Le premier pourcentage n'a pas de glyphe : il revient a la puce centree
      // dans l'ilot, a gauche. Les suivants portent le leur.
      text: {
        var reading = Math.round(Math.max(0, metrics.cpuPercent)) + "%"
          // La barrette deborde sa cellule : une espace de plus la detache du nombre.
          + "  " + root.glyphMemory + "  " + Math.round(Math.max(0, metrics.memoryPercent)) + "%"

        if (root.hasGpuUsage) {
          reading += "  " + root.glyphGpu + " " + Math.round(metrics.gpuPercent) + "%"
          if (root.hasGpuVram) reading += "  " + root.glyphVram + " " + Math.round(root.gpuVramPercent) + "%"
        }

        return reading
      }

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
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight,
                                             Style.space(760 + metrics.extraFilesystems.length * 40))

    PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) { root.cursorActive = true }
      onActivateRequested: if (root.cursorActive) root.launchBtop()
      onTextKey: function(text) {
        if (text === "r" || text === "R") metrics.sample()
        else if (text === "b" || text === "B") root.launchBtop()
      }

      ScrollView {
        id: scrollArea

        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

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
          id: panelColumn

          width: scrollArea.availableWidth
          spacing: Style.space(9)

          // ---- En-tete : hote, uptime, charge ----
          PanelHero {
            width: parent.width
            title: metrics.hostname !== "" ? metrics.hostname : "System"
            meta: "Up " + root.formatUptime(metrics.uptimeSeconds) + " · Load " + root.loadText()
            foreground: root.foregroundColor
            fontFamily: root.fontFamily

            iconComponent: Component {
              Text {
                text: root.glyphCpu
                color: root.foregroundColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }

            trailingControl: Component {
              PanelActionButton {
                iconText: "󰑐"
                tooltipText: "Refresh (R)"
                foreground: root.foregroundColor
                hoverColor: root.accentColor
                fontFamily: root.fontFamily
                onClicked: metrics.sample()
              }
            }
          }

          PanelSeparator { foreground: root.foregroundColor }

          // ---- Mesures principales ----
          Row {
            width: parent.width
            spacing: Style.space(8)

            StatTile {
              width: (parent.width - parent.spacing * 2) / 3
              title: "CPU"
              value: root.percent(metrics.cpuPercent)
              detail: metrics.perCore.length > 0 ? metrics.perCore.length + " threads" : "—"
              meter: metrics.cpuPercent
              meterColor: root.levelColor(metrics.cpuPercent, root.warningThreshold, root.criticalThreshold)
              alarming: metrics.cpuPercent >= root.criticalThreshold
            }

            StatTile {
              width: (parent.width - parent.spacing * 2) / 3
              title: "MEMORY"
              value: root.percent(metrics.memoryPercent)
              detail: root.formatPair(metrics.memoryUsed, metrics.memoryTotal)
              meter: metrics.memoryPercent
              meterColor: root.levelColor(metrics.memoryPercent, root.warningThreshold, root.criticalThreshold)
              alarming: metrics.memoryPercent >= root.criticalThreshold
            }

            StatTile {
              width: (parent.width - parent.spacing * 2) / 3
              title: "TEMP"
              value: root.temperatureText(metrics.cpuTemperature)
              detail: root.temperatureDetail(metrics.cpuTemperature)
              meter: root.temperatureBandMeter(metrics.cpuTemperature)
              meterColor: root.levelColor(metrics.cpuTemperature, 85, 95)
              alarming: metrics.cpuTemperature >= 95
            }
          }

          // ---- GPU ----
          // Masque sans carte lisible : la disposition retombe sur trois tuiles.
          Row {
            width: parent.width
            spacing: Style.space(8)
            visible: root.hasGpu

            StatTile {
              visible: root.hasGpuUsage
              width: root.gpuTileWidth(parent.width, parent.spacing)
              title: "GPU"
              value: root.percent(metrics.gpuPercent)
              detail: root.hasGpuVram ? root.formatBytes(metrics.gpuVramTotal) + " VRAM" : "—"
              meter: metrics.gpuPercent
              meterColor: root.levelColor(metrics.gpuPercent, root.warningThreshold, root.criticalThreshold)
              alarming: metrics.gpuPercent >= root.criticalThreshold
            }

            StatTile {
              visible: root.hasGpuTemperature
              width: root.gpuTileWidth(parent.width, parent.spacing)
              title: "GPU TEMP"
              value: root.temperatureText(metrics.gpuTemperature)
              detail: root.temperatureDetail(metrics.gpuTemperature)
              meter: root.temperatureBandMeter(metrics.gpuTemperature)
              meterColor: root.levelColor(metrics.gpuTemperature, 85, 95)
              alarming: metrics.gpuTemperature >= 95
            }

            StatTile {
              visible: root.hasGpuVram
              width: root.gpuTileWidth(parent.width, parent.spacing)
              title: "VRAM"
              value: root.percent(root.gpuVramPercent)
              detail: root.formatPair(metrics.gpuVramUsed, metrics.gpuVramTotal)
              meter: root.gpuVramPercent
              meterColor: root.levelColor(root.gpuVramPercent, root.warningThreshold, root.criticalThreshold)
              alarming: root.gpuVramPercent >= root.criticalThreshold
            }
          }

          PanelSeparator { foreground: root.foregroundColor }

          // ---- Historique CPU, memoire, GPU ----
          Column {
            width: parent.width
            spacing: Style.space(6)

            SectionHeading {
              title: root.hasGpuUsage ? "CPU, MEMORY & GPU" : "CPU & MEMORY"
              value: "2 MIN"
            }

            Item {
              width: parent.width
              height: Style.space(70)

              SystemSparkline {
                anchors.fill: parent
                points: metrics.cpuHistory
                lineColor: root.accentColor
                fillColor: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
                gridColor: root.chartGrid
                gridLevels: [0.25, 0.5, 0.75]
                fixedMaximum: 100
              }

              SystemSparkline {
                anchors.fill: parent
                points: metrics.memoryHistory
                lineColor: root.secondaryColor
                fillColor: "transparent"
                dashed: true
                lineWidth: 1.2
                fixedMaximum: 100
              }

              SystemSparkline {
                anchors.fill: parent
                visible: root.hasGpuUsage
                points: metrics.gpuHistory
                lineColor: root.warningColor
                fillColor: "transparent"
                lineWidth: 1.2
                fixedMaximum: 100
              }

              // L'echelle est fixee a 100 % : le dire, sinon une machine au
              // repos ressemble a une boite vide.
              Text {
                anchors.left: parent.left
                anchors.top: parent.top
                text: "100%"
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Row {
                anchors.top: parent.top
                anchors.right: parent.right
                spacing: Style.space(8)
                LegendDot { colorValue: root.accentColor; label: "CPU" }
                LegendDot { colorValue: root.secondaryColor; label: "RAM" }
                LegendDot { visible: root.hasGpuUsage; colorValue: root.warningColor; label: "GPU" }
              }
            }
          }

          PanelSeparator { foreground: root.foregroundColor }

          // ---- Charge par coeur ----
          Column {
            width: parent.width
            spacing: Style.space(6)
            visible: metrics.perCore.length > 0

            SectionHeading {
              title: "CORES"
              value: metrics.perCore.length + " threads · peak " + root.percent(metrics.coreMaximum)
            }

            Row {
              id: coreStrip

              width: parent.width
              height: Style.space(18)
              spacing: Style.space(3)

              readonly property real cellWidth: metrics.perCore.length > 0
                ? (width - spacing * (metrics.perCore.length - 1)) / metrics.perCore.length
                : 0
              // Les nombres ne tiennent qu'au-dessus de quatre caracteres environ ;
              // en dessous, la teinte porte seule la mesure.
              readonly property bool showValues: cellWidth >= Style.space(30)

              Repeater {
                model: metrics.perCore

                Rectangle {
                  id: coreCell
                  required property var modelData

                  readonly property real load: Math.max(0, Math.min(100, modelData.percent)) / 100

                  width: coreStrip.cellWidth
                  height: coreStrip.height
                  radius: Style.cornerRadius
                  color: root.trackColor

                  // Une teinte plutot qu'une barre : un coeur a 5 % dessine en
                  // barre fait un trait d'un pixel qui passe pour un artefact.
                  Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: root.levelColor(coreCell.modelData.percent, root.warningThreshold, root.criticalThreshold)
                    opacity: 0.12 + 0.68 * coreCell.load
                  }

                  Text {
                    anchors.centerIn: parent
                    visible: coreStrip.showValues
                    text: root.percent(coreCell.modelData.percent)
                    color: root.foregroundColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foregroundColor }

          // ---- Disque ----
          // Une ligne de lecture : son historique est le moins regarde du
          // panneau. Le debit reseau vit dans le widget Network.
          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              implicitHeight: Math.max(diskName.implicitHeight, diskRates.implicitHeight)

              PanelSectionHeader {
                id: diskName

                text: root.diskLabelText()
                foreground: root.foregroundColor
                fontFamily: root.fontFamily
                elide: Text.ElideRight
                anchors.left: parent.left
                anchors.right: diskRates.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }

              Row {
                id: diskRates

                spacing: Style.space(14)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                RateLabel {
                  glyph: "W"
                  glyphColor: root.accentColor
                  value: metrics.diskWriteBps
                }

                RateLabel {
                  glyph: "R"
                  glyphColor: root.secondaryColor
                  value: metrics.diskReadBps
                }
              }
            }
          }

          PanelSeparator { foreground: root.foregroundColor }

          // ---- Capacite ----
          Column {
            width: parent.width
            spacing: Style.space(6)

            SectionHeading { title: "CAPACITY" }

            CapacityRow {
              label: "Root filesystem"
              value: root.formatPair(metrics.filesystemUsed, metrics.filesystemTotal)
              percentValue: metrics.filesystemPercent
            }

            CapacityRow {
              visible: metrics.swapTotal > 0
              label: "Swap"
              value: root.formatPair(metrics.swapUsed, metrics.swapTotal)
              percentValue: metrics.swapPercent
            }

            Repeater {
              model: metrics.extraFilesystems

              CapacityRow {
                required property var modelData

                label: root.mountLabel(modelData.mount)
                value: root.formatPair(modelData.used, modelData.total)
                percentValue: modelData.percent
              }
            }
          }

          PanelSeparator { foreground: root.foregroundColor }

          // ---- Action ----
          Button {
            id: btopButton

            width: parent.width
            iconText: "󰆍"
            text: "Open btop"
            tooltipText: "Open btop (B)"
            bordered: true
            foreground: root.foregroundColor
            accent: root.accentColor
            fontFamily: root.fontFamily
            fontSize: Style.font.bodySmall
            iconSize: Style.font.icon
            hasCursor: root.cursorActive
            onHovered: function(isHovered) { if (isHovered) root.cursorActive = true }
            onClicked: root.launchBtop()
          }
        }
      }
    }
  }

  // --- Composants internes ---------------------------------------------------

  // Intitule a gauche, resume vivant a droite.
  component SectionHeading: Item {
    property string title: ""
    property string value: ""

    width: parent ? parent.width : 0
    implicitHeight: Math.max(headingText.implicitHeight, valueText.implicitHeight)

    PanelSectionHeader {
      id: headingText

      text: title
      textFormat: Text.PlainText
      foreground: root.foregroundColor
      fontFamily: root.fontFamily
      elide: Text.ElideRight
      anchors.left: parent.left
      anchors.right: valueText.visible ? valueText.left : parent.right
      anchors.rightMargin: valueText.visible ? Style.space(8) : 0
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: valueText

      text: value
      visible: text !== ""
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      elide: Text.ElideRight
      width: Math.min(implicitWidth, parent.width * 0.62)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignRight
    }
  }

  component Meter: Rectangle {
    id: meter

    property real value: -1
    property real maximum: 100
    property color fillColor: root.accentColor

    height: Style.space(3)
    radius: height / 2
    color: root.trackColor

    Rectangle {
      width: meter.width * Math.max(0, Math.min(1, meter.value / meter.maximum))
      height: meter.height
      radius: meter.radius
      color: meter.fillColor

      Behavior on width {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }
    }
  }

  // Ilot sans lisere, comme le reste de la menubar.
  component StatTile: Rectangle {
    id: tile

    property string title: ""
    property string value: "—"
    property string detail: ""
    property real meter: -1
    property color meterColor: root.accentColor
    property bool alarming: false

    height: Style.space(80)
    radius: Style.cornerRadius
    color: root.islandFill

    Column {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(9)
      spacing: Style.space(2)

      Text {
        text: tile.title
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.2
      }

      Text {
        text: tile.value
        color: tile.alarming ? root.urgentColor : root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Text {
        width: parent.width
        text: tile.detail
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    Meter {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(9)
      value: tile.meter
      fillColor: tile.meterColor
    }
  }

  component LegendDot: Row {
    property color colorValue: "white"
    property string label: ""

    spacing: Style.space(4)

    Rectangle {
      width: Style.space(6)
      height: width
      radius: width / 2
      color: parent.colorValue
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: parent.label
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // La lettre porte la couleur de sa serie, comme les fleches du widget Network.
  component RateLabel: Row {
    id: rate

    property string glyph: ""
    property color glyphColor: root.accentColor
    property real value: -1

    spacing: Style.space(4)

    Text {
      text: rate.glyph
      color: rate.glyphColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }

    Text {
      text: root.formatRate(rate.value)
      color: root.foregroundColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  component CapacityRow: Column {
    id: capacity

    property string label: ""
    property string value: "—"
    property real percentValue: -1

    width: parent ? parent.width : 0
    spacing: Style.space(3)

    Item {
      width: parent.width
      implicitHeight: Math.max(capacityLabel.implicitHeight, capacityValue.implicitHeight)

      Text {
        id: capacityLabel

        text: capacity.label
        // Les chemins de montage viennent de df : format fige, pour que
        // Text.AutoText ne lise pas un chemin forge comme du texte riche.
        textFormat: Text.PlainText
        color: root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: capacityValue

        text: capacity.value
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Meter {
      width: parent.width
      value: capacity.percentValue
      fillColor: root.levelColor(capacity.percentValue, root.warningThreshold, root.criticalThreshold)
    }
  }
}
