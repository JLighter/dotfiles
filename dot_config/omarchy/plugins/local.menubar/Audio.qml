import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Widget audio autonome : icone de volume dans la barre, panneau complet au
// clic. Reimplementation de `omarchy.audio` — memes gestes et memes fonctions,
// sans dependre du plugin natif.
//
// Bouton : clic gauche ou milieu ouvre le panneau, clic droit coupe le son,
// molette ajuste le volume de 5 %.
// Panneau : volume et peripherique de sortie, volume et peripherique d'entree,
// mixeur par application.
BarWidget {
  id: root
  moduleName: "local.menubar.audio"

  readonly property int islandSize: bar && bar.islandSize !== undefined ? bar.islandSize : barSize

  // --- Etat PipeWire ---------------------------------------------------------

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []

  readonly property real outputVolume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool outputMuted: sink && sink.audio ? sink.audio.muted : false
  readonly property real inputVolume: source && source.audio ? source.audio.volume : 0
  readonly property bool inputMuted: source && source.audio ? source.audio.muted : false

  // Ne jamais lire node.properties sans passer par nodeProps : les proprietes
  // d'un node non lie sont invalides, et y toucher pendant qu'un flux de
  // capture apparait peut destabiliser le service Pipewire de Quickshell.
  function nodeProps(node) {
    return node && node.ready && node.properties ? node.properties : ({})
  }

  // Quickshell expose `type` differemment selon les versions ; un flux de
  // lecture publie de maniere constante `isSink: true`.
  function isPlaybackStream(node) {
    if (!node || !node.isStream) return false
    if (node.isSink === true) return true

    return String(node.type || "").indexOf("Output") !== -1
  }

  readonly property var candidateSinks: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && n.isSink && !n.isStream) list.push(n)
    }
    return list
  }

  // PipeWire publie aussi ses pilotes internes (Dummy-Driver, Freewheel-Driver)
  // et les ponts MIDI comme des nodes d'entree. Aucun ne porte d'audio : c'est
  // ce qui les distingue d'un vrai micro.
  function isAudioSource(node) {
    if (!node) return false
    if (node.audio) return true

    return String(node.type || "").indexOf("Source") !== -1
  }

  readonly property var candidateSources: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (!n || n.isSink || n.isStream || !isAudioSource(n)) continue
      // Chaque sortie publie un node `.monitor` qui reecoute ce qu'elle joue :
      // ce n'est pas un micro, il n'a rien a faire dans la liste d'entrees.
      var name = String(n.name || "")
      if (name === "quickshell" || name.indexOf(".monitor") !== -1) continue
      list.push(n)
    }
    return list
  }

  readonly property var candidateStreams: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && isPlaybackStream(n) && n.audio) list.push(n)
    }
    return list
  }

  // La sortie et l'entree courantes restent listees meme si PipeWire ne les
  // republie pas dans `nodes` a cet instant.
  readonly property var audioSinks: {
    var list = candidateSinks.slice()
    if (sink && list.indexOf(sink) < 0) list.unshift(sink)
    return list
  }

  readonly property var audioSources: {
    var list = candidateSources.slice()
    if (source && list.indexOf(source) < 0) list.unshift(source)
    return list
  }

  // Les Repeater sont alimentes par une copie, pas par le modele PipeWire en
  // direct : PipeWire peut retirer un node pendant que Quickshell diffuse le
  // signal de suppression, et reconstruire une liste depuis ce signal a deja
  // fait tomber le service. Le delai laisse la mutation se poser, et un
  // panneau ferme detache completement ses listes.
  property var displaySinks: []
  property var displaySources: []
  property var displayStreams: []

  function refreshDisplayModels() {
    if (!opened) return

    displaySinks = audioSinks.slice()
    displaySources = audioSources.slice()
    displayStreams = candidateStreams.slice()
    clampCursor()
  }

  function scheduleDisplayRefresh() {
    if (!opened) return

    displayRefreshTimer.restart()
  }

  onAudioSinksChanged: scheduleDisplayRefresh()
  onAudioSourcesChanged: scheduleDisplayRefresh()
  onCandidateStreamsChanged: scheduleDisplayRefresh()

  Timer {
    id: displayRefreshTimer
    interval: 75
    onTriggered: root.refreshDisplayModels()
  }

  // Sans tracker, un node ne publie ni son volume ni son etat muet : les
  // sliders resteraient figes a zero.
  PwObjectTracker { objects: root.candidateSinks }
  PwObjectTracker { objects: root.candidateSources }
  PwObjectTracker { objects: root.candidateStreams }

  // --- Actions ---------------------------------------------------------------

  function setOutputVolume(value) {
    if (sink && sink.audio) sink.audio.volume = Math.max(0, Math.min(1, value))
  }

  function setInputVolume(value) {
    if (source && source.audio) source.audio.volume = Math.max(0, Math.min(1, value))
  }

  function toggleOutputMute() {
    if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
  }

  function toggleInputMute() {
    if (source && source.audio) source.audio.muted = !source.audio.muted
  }

  function setStreamVolume(node, value) {
    if (node && node.audio) node.audio.volume = Math.max(0, Math.min(1.5, value))
  }

  function toggleStreamMute(node) {
    if (node && node.audio) node.audio.muted = !node.audio.muted
  }

  // Le choix est applique tout de suite dans Quickshell, puis persiste par le
  // helper Omarchy pour qu'il survive au redemarrage du shell.
  function setDefaultSink(node) {
    if (!node) return

    Pipewire.preferredDefaultAudioSink = node
    if (node.id !== undefined && node.name)
      Quickshell.execDetached(["omarchy-audio-output-set-default", String(node.id), String(node.name)])
  }

  function setDefaultSource(node) {
    if (!node) return

    Pipewire.preferredDefaultAudioSource = node
    if (node.id !== undefined && node.name)
      Quickshell.execDetached(["omarchy-audio-input-set-default", String(node.id), String(node.name)])
  }

  // --- Libelles et glyphes ---------------------------------------------------

  function deviceLabel(node) {
    if (!node) return "Unknown"

    var props = nodeProps(node)
    return String(node.nickname || node.description || props["node.description"] || node.name || "Unknown")
  }

  function streamLabel(node) {
    if (!node) return "Unknown"

    var props = nodeProps(node)
    return String(props["application.name"] || node.description || props["media.name"] || node.name || "Unknown")
  }

  // Glyphes Nerd Font, memes codepoints que le widget natif. Ils vivent dans
  // la zone privee Unicode : ils s'affichent en carre vide dans un editeur qui
  // n'a pas la police, mais le fichier est bien en UTF-8.
  readonly property string glyphMuted: ""
  readonly property string glyphVolumeLow: ""
  readonly property string glyphVolumeMid: ""
  readonly property string glyphVolumeHigh: ""
  readonly property string glyphHeadphones: "󰋋"
  readonly property string glyphSpeaker: "󰓃"
  readonly property string glyphBluetooth: "󰂯"
  readonly property string glyphDisplay: "󰍹"
  readonly property string glyphMic: "󰍬"
  readonly property string glyphMicMuted: "󰍭"
  readonly property string glyphStream: "󰕾"
  readonly property string glyphStreamMuted: "󰝟"

  function deviceBlob(node) {
    var props = nodeProps(node)
    return String([
      node.name, node.description, node.nickname,
      props["device.icon-name"] || "",
      props["device.product.name"] || ""
    ].join(" ")).toLowerCase()
  }

  function isHeadphones(node) {
    if (!node) return false

    var blob = deviceBlob(node)
    return blob.indexOf("headphone") !== -1 || blob.indexOf("headset") !== -1 || blob.indexOf("earbud") !== -1
  }

  function sinkGlyph(node) {
    if (!node) return glyphSpeaker
    if (isHeadphones(node)) return glyphHeadphones

    var blob = deviceBlob(node)
    if (blob.indexOf("bluetooth") !== -1) return glyphBluetooth
    if (blob.indexOf("hdmi") !== -1 || blob.indexOf("display") !== -1) return glyphDisplay
    return glyphSpeaker
  }

  function outputIcon() {
    if (!sink || !sink.audio) return glyphMuted
    if (outputMuted) return glyphMuted
    if (isHeadphones(sink)) return glyphHeadphones
    if (outputVolume >= 0.67) return glyphVolumeHigh
    if (outputVolume >= 0.34) return glyphVolumeMid
    if (outputVolume > 0) return glyphVolumeLow
    return glyphMuted
  }

  // --- Ouverture du panneau --------------------------------------------------

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

  // La barre appelle ceci quand un autre panneau prend la main.
  function closeForPopoutSwitch() {
    close()
  }

  // La barre est instanciee une fois par ecran : sans ce filtre, chaque copie
  // tenterait d'enregistrer la meme cible IPC et seule la premiere servirait,
  // sur un ecran choisi au hasard.
  readonly property bool primaryInstance: {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screens = Quickshell.screens
    return !!window && screens.length > 0 && window.screen === screens[0]
  }

  // Pilotable depuis un raccourci, comme le widget natif :
  //   omarchy-shell menubar.audio toggle
  IpcHandler {
    enabled: root.primaryInstance
    target: "menubar.audio"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  onOpenedChanged: {
    if (opened) {
      refreshDisplayModels()
      cursor = 0
      cursorActive = false
    } else {
      displayRefreshTimer.stop()
      displaySinks = []
      displaySources = []
      displayStreams = []
    }
  }

  // --- Curseur clavier -------------------------------------------------------
  // Les lignes navigables sont mises a plat dans un seul tableau : le curseur
  // est un simple index dedans, partage avec la souris pour qu'un seul element
  // soit surligne a la fois.

  property int cursor: 0
  property bool cursorActive: false

  readonly property var rows: {
    var list = [{ kind: "outputSlider", index: -1 }]
    for (var i = 0; i < displaySinks.length; i++) list.push({ kind: "sink", index: i })
    if (source) list.push({ kind: "inputSlider", index: -1 })
    for (var j = 0; j < displaySources.length; j++) list.push({ kind: "source", index: j })
    for (var k = 0; k < displayStreams.length; k++) list.push({ kind: "stream", index: k })
    return list
  }

  function rowAt(position) {
    return position >= 0 && position < rows.length ? rows[position] : null
  }

  function rowIndexOf(kind, index) {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].kind === kind && rows[i].index === index) return i
    }
    return -1
  }

  function clampCursor() {
    if (cursor >= rows.length) cursor = Math.max(0, rows.length - 1)
    if (cursor < 0) cursor = 0
  }

  function moveCursor(delta) {
    cursor = Math.max(0, Math.min(rows.length - 1, cursor + delta))
  }

  // Fleches horizontales : agit sur le volume de la ligne courante. Sur une
  // ligne de peripherique il n'y a rien a regler — bouger le volume general
  // depuis la surprendrait.
  function adjustCursorVolume(delta) {
    var row = rowAt(cursor)
    if (!row) return

    if (row.kind === "outputSlider") setOutputVolume(outputVolume + delta)
    else if (row.kind === "inputSlider") setInputVolume(inputVolume + delta)
    else if (row.kind === "stream") {
      var node = displayStreams[row.index]
      if (node && node.audio) setStreamVolume(node, node.audio.volume + delta)
    }
  }

  function activateCursor() {
    var row = rowAt(cursor)
    if (!row) return

    if (row.kind === "outputSlider") toggleOutputMute()
    else if (row.kind === "inputSlider") toggleInputMute()
    else if (row.kind === "sink") setDefaultSink(displaySinks[row.index])
    else if (row.kind === "source") setDefaultSource(displaySources[row.index])
    else if (row.kind === "stream") toggleStreamMute(displayStreams[row.index])
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

  WidgetButton {
    id: button

    bar: root.bar
    text: root.outputIcon()
    tooltipText: root.outputMuted ? "Muted" : "Volume " + Math.round(root.outputVolume * 100) + "%"
    fixedWidth: root.vertical ? root.islandSize : Style.space(24)
    fixedHeight: root.islandSize
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.toggleOutputMute()
      else root.toggle()
    }
    onWheelMoved: function(delta) {
      root.setOutputVolume(root.outputVolume + (delta > 0 ? 0.05 : -0.05))
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
      onMoveRequested: function(dx, dy) {
        // La premiere touche revele le curseur sans le deplacer.
        if (!root.cursorActive) {
          root.cursorActive = true
          return
        }
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.adjustCursorVolume(dx * 0.05)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTextKey: function(text) {
        if (text === "m" || text === "M") root.toggleOutputMute()
      }

      ScrollView {
        id: scrollArea

        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: content.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: content

          width: scrollArea.availableWidth
          spacing: Style.space(12)

          // ---- Sortie courante ----
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroIcon

              text: root.outputIcon()
              color: root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              opacity: root.outputMuted ? 0.5 : 1
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleOutputMute()
              }
            }

            Column {
              id: heroLabels

              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: "Audio"
                color: root.foregroundColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: root.outputMuted ? "MUTED" : root.deviceLabel(root.sink).toUpperCase()
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

          PanelSeparator { foreground: root.foregroundColor }

          // ---- Sortie : volume + peripheriques ----
          Column {
            width: parent.width
            spacing: Style.space(4)

            SectionHeader {
              text: "OUTPUT"
              value: Math.round((outputSlider.dragging ? outputSlider.liveValue : root.outputVolume) * 100) + "%"
              dimmed: root.outputMuted
            }

            CursorSurface {
              width: parent.width
              height: outputSlider.implicitHeight
              hasCursor: root.cursorActive && root.cursor === root.rowIndexOf("outputSlider", -1)
              foreground: root.foregroundColor
              outline: true

              HoverHandler {
                onHoveredChanged: if (hovered) root.pointCursorAt("outputSlider", -1)
              }

              PanelSlider {
                id: outputSlider

                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                value: root.outputVolume
                opacity: root.outputMuted ? 0.5 : 1
                enabled: !!root.sink
                onMoved: function(value) { root.setOutputVolume(value) }
              }
            }

            Repeater {
              model: root.displaySinks

              DeviceRow {
                required property var modelData
                required property int index

                width: content.width
                node: modelData
                rowKind: "sink"
                rowIndex: index
                glyph: root.sinkGlyph(modelData)
                selected: modelData === root.sink
                onActivated: root.setDefaultSink(modelData)
              }
            }
          }

          // ---- Entree : volume + peripheriques ----
          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: !!root.source || root.displaySources.length > 0

            SectionHeader {
              text: "INPUT"
              value: Math.round((inputSlider.dragging ? inputSlider.liveValue : root.inputVolume) * 100) + "%"
              dimmed: root.inputMuted
            }

            CursorSurface {
              width: parent.width
              height: inputSlider.implicitHeight
              visible: !!root.source
              hasCursor: root.cursorActive && root.cursor === root.rowIndexOf("inputSlider", -1)
              foreground: root.foregroundColor
              outline: true

              HoverHandler {
                onHoveredChanged: if (hovered) root.pointCursorAt("inputSlider", -1)
              }

              PanelSlider {
                id: inputSlider

                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                value: root.inputVolume
                opacity: root.inputMuted ? 0.5 : 1
                enabled: !!root.source
                onMoved: function(value) { root.setInputVolume(value) }
              }
            }

            Repeater {
              model: root.displaySources

              DeviceRow {
                required property var modelData
                required property int index

                width: content.width
                node: modelData
                rowKind: "source"
                rowIndex: index
                glyph: root.inputMuted && modelData === root.source ? root.glyphMicMuted : root.glyphMic
                selected: modelData === root.source
                onActivated: root.setDefaultSource(modelData)
              }
            }
          }

          // ---- Mixeur par application ----
          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: root.displayStreams.length > 0

            SectionHeader { text: "APPS" }

            Repeater {
              model: root.displayStreams

              StreamRow {
                required property var modelData
                required property int index

                width: content.width
                node: modelData
                rowIndex: index
              }
            }
          }
        }
      }
    }
  }

  // --- Couleurs et composants internes ---------------------------------------

  readonly property color foregroundColor: bar ? bar.foreground : Color.foreground
  readonly property color mutedColor: Qt.darker(foregroundColor, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // En-tete de section : intitule a gauche, valeur a droite.
  component SectionHeader: Item {
    id: sectionHeader

    property alias text: header.text
    property string value: ""
    property bool dimmed: false

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
      opacity: sectionHeader.dimmed ? 0.5 : 1
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Ligne de peripherique : glyphe, nom, pastille sur celui qui est actif.
  component DeviceRow: CursorSurface {
    id: deviceRow

    required property var node
    required property string rowKind
    required property int rowIndex
    property string glyph: ""
    property bool selected: false

    signal activated()

    height: Style.space(30)
    hasCursor: root.cursorActive && root.cursor === root.rowIndexOf(rowKind, rowIndex)
    current: selected
    foreground: root.foregroundColor

    HoverHandler {
      onHoveredChanged: if (hovered) root.pointCursorAt(deviceRow.rowKind, deviceRow.rowIndex)
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: deviceRow.activated()
    }

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: deviceRow.glyph
        color: root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        width: Style.space(20)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: root.deviceLabel(deviceRow.node)
        color: root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: deviceRow.selected
        elide: Text.ElideRight
        width: parent.width - Style.space(48)
        anchors.verticalCenter: parent.verticalCenter
      }

      Rectangle {
        width: Style.space(6)
        height: width
        radius: width / 2
        color: Color.accent
        visible: deviceRow.selected
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  // Ligne d'application : glyphe cliquable pour couper, nom, slider dedie.
  component StreamRow: CursorSurface {
    id: streamRow

    required property var node
    required property int rowIndex

    readonly property bool streamMuted: node && node.audio ? node.audio.muted : false
    readonly property real streamVolume: node && node.audio ? node.audio.volume : 0

    height: Style.space(46)
    hasCursor: root.cursorActive && root.cursor === root.rowIndexOf("stream", rowIndex)
    foreground: root.foregroundColor

    HoverHandler {
      onHoveredChanged: if (hovered) root.pointCursorAt("stream", streamRow.rowIndex)
    }

    Column {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      anchors.topMargin: Style.space(2)
      spacing: 0

      Row {
        width: parent.width
        height: Style.space(20)
        spacing: Style.space(8)

        Text {
          text: streamRow.streamMuted ? root.glyphStreamMuted : root.glyphStream
          color: root.foregroundColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.icon
          opacity: streamRow.streamMuted ? 0.5 : 1
          width: Style.space(20)
          horizontalAlignment: Text.AlignHCenter
          anchors.verticalCenter: parent.verticalCenter

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleStreamMute(streamRow.node)
          }
        }

        Text {
          text: root.streamLabel(streamRow.node)
          color: root.foregroundColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          width: parent.width - Style.space(76)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: Math.round((streamSlider.dragging ? streamSlider.liveValue : streamRow.streamVolume) * 100) + "%"
          color: root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          opacity: streamRow.streamMuted ? 0.5 : 1
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      PanelSlider {
        id: streamSlider

        bar: root.bar
        width: parent.width - Style.space(4)
        x: Style.space(2)
        // Les applications peuvent depasser 100 % sans toucher au volume general.
        maximum: 1.5
        value: streamRow.streamVolume
        opacity: streamRow.streamMuted ? 0.5 : 1
        onMoved: function(value) { root.setStreamVolume(streamRow.node, value) }
      }
    }
  }
}
