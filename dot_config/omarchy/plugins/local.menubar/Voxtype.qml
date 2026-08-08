import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Widget de dictee vocale : un micro dans la barre, une waveform qui se deplie
// a cote des que voxtype ecoute. Il remplace l'OSD flottant livre avec voxtype,
// dont la carte se pose au milieu de l'ecran.
//
// Le widget s'efface entierement quand voxtype n'est pas installe : `Row`
// ignore les enfants invisibles, y compris pour l'espacement, donc l'ilot se
// referme sans laisser de trou.
//
// Les composants QML fournis par voxtype (`voxtype-shared/AudioBridge.qml`,
// `StateReader.qml`) font deja ce travail, mais les importer lierait le
// chargement du widget a la presence d'un dossier hors du plugin : voxtype
// desinstalle, l'import echoue et c'est toute la barre qui tombe. Le protocole
// tient en quelques lignes, on le relit ici.
BarWidget {
  id: root
  moduleName: "local.menubar.voxtype"

  readonly property int islandSize: bar && bar.islandSize !== undefined ? bar.islandSize : barSize
  readonly property int islandRadius: bar && bar.islandRadius !== undefined ? bar.islandRadius : Style.cornerRadius

  // Une seule courbe pour tout ce qui se deplie ou s'allume dans la barre.
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

  // Le panneau arrive du bord occupe par la barre, et grandit depuis ce bord.
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

  // --- Presence de voxtype ---------------------------------------------------
  // Le pont audio est un binaire distinct du daemon : les deux doivent etre la
  // pour que le widget ait quoi que ce soit a montrer.

  property bool installed: false

  Process {
    running: true
    command: ["bash", "-lc",
              "command -v voxtype >/dev/null && command -v voxtype-audio-bridge >/dev/null && echo yes || echo no"]
    stdout: SplitParser {
      onRead: function(line) { root.installed = String(line).trim() === "yes" }
    }
  }

  // --- Etat du daemon --------------------------------------------------------
  // Le daemon reecrit ce fichier a chaque transition : idle, recording,
  // streaming, transcribing. FileView le relit a chaque changement.

  property string daemonState: "idle"

  readonly property string statePath: {
    var runtimeDir = Quickshell.env("XDG_RUNTIME_DIR")
    if (runtimeDir && runtimeDir.length > 0) return runtimeDir + "/voxtype/state"

    var uid = Quickshell.env("UID")
    return "/run/user/" + (uid && uid.length > 0 ? uid : "1000") + "/voxtype/state"
  }

  readonly property bool listening: daemonState === "recording" || daemonState === "streaming"
  readonly property bool busy: listening || daemonState === "transcribing"

  FileView {
    path: root.statePath
    watchChanges: true
    printErrors: false

    onLoaded: root.daemonState = String(text() || "idle").trim()
    // Daemon arrete : le fichier disparait, l'etat retombe au repos plutot que
    // de rester bloque sur la derniere valeur lue.
    onLoadFailed: root.daemonState = "idle"
    onFileChanged: reload()
  }

  // --- Reglages du daemon ----------------------------------------------------
  // Moteur, peripherique et backend ne bougent qu'a la reconfiguration : un
  // releve a l'ouverture du panneau suffit, inutile de suivre le flux.

  property string model: ""
  property string device: ""
  property string backend: ""

  Process {
    id: infoProc

    command: ["voxtype", "status", "--extended", "--format", "json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var info
        try {
          info = JSON.parse(String(text || "").trim())
        } catch (e) {
          return
        }

        root.model = String(info.model || "")
        root.device = String(info.device || "")
        root.backend = String(info.backend || "")
      }
    }
  }

  function refreshInfo() {
    if (installed && !infoProc.running) infoProc.running = true
  }

  onInstalledChanged: refreshInfo()

  // --- Pont audio ------------------------------------------------------------
  // `voxtype-audio-bridge` lit le socket du daemon et emet une ligne JSON par
  // trame, a 100 Hz : {"peak":0.42,"rms":0.18,"vad":1,"ts_ms":1234567}.
  //
  // Il ne tourne que pendant la dictee. L'OSD natif le garde ouvert en
  // permanence ; ici un processus de plus au repos ne se justifie pas, le
  // socket etant deja la quand le pont se connecte.

  function handleBridgeLine(line) {
    var trimmed = String(line || "").trim()
    if (trimmed.length === 0) return

    var frame
    try {
      frame = JSON.parse(trimmed)
    } catch (e) {
      // Le pont ecrit parfois une ligne de log sur sa sortie standard. La
      // laisser passer vaut mieux que de faire tomber le widget.
      return
    }

    if (frame.status !== undefined) return
    if (typeof frame.peak !== "number") return

    root.pushSample(frame.peak, Number(frame.ts_ms || 0))
  }

  Process {
    id: bridge

    running: root.installed && root.busy
    command: ["voxtype-audio-bridge"]
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { root.handleBridgeLine(line) }
    }
  }

  // --- Waveform --------------------------------------------------------------
  // Le pont emet cent trames par seconde, la barre n'a la place que d'une
  // quinzaine de colonnes : chacune couvre donc une tranche de temps et retient
  // la crete de la tranche. Prendre la crete plutot que la moyenne garde les
  // attaques de voix visibles — moyenner les aplatirait en un trait continu.

  readonly property real windowSecs: 3.0
  readonly property int columnWidth: Math.max(2, Style.space(3))
  readonly property int waveLength: Style.space(46)
  readonly property int columns: Math.max(6, Math.floor(waveLength / columnWidth))
  readonly property real columnMs: windowSecs * 1000 / columns
  // Les cretes d'une voix au micro plafonnent vers 0.1–0.3 de la pleine
  // echelle : sans gain, la waveform resterait un trait plat au centre. Meme
  // valeur que l'OSD natif.
  readonly property real waveGain: 10.0

  property var samples: []
  property real pendingPeak: 0
  property real columnStartMs: 0

  function pushSample(value, tsMs) {
    if (value > pendingPeak) pendingPeak = value
    if (columnStartMs === 0) columnStartMs = tsMs

    if (tsMs - columnStartMs < columnMs) return

    // Reaffectation en bloc : muter un tableau en place ne notifie pas les
    // bindings qui en dependent.
    var next = samples.slice()
    next.push(pendingPeak)
    while (next.length > columns) next.shift()

    samples = next
    pendingPeak = 0
    columnStartMs = tsMs
    waveCanvas.requestPaint()
  }

  function resetWave() {
    samples = []
    pendingPeak = 0
    columnStartMs = 0
    waveCanvas.requestPaint()
  }

  // Le repli se joue avant l'effacement : vider le tampon tout de suite
  // laisserait une piste vide se refermer au lieu de la waveform elle-meme.
  Timer {
    id: clearTimer
    interval: root.revealDuration
    onTriggered: root.resetWave()
  }

  onBusyChanged: {
    if (busy) {
      clearTimer.stop()
      resetWave()
    } else {
      clearTimer.restart()
    }
  }

  // --- Glyphes ---------------------------------------------------------------
  // Memes codepoints que l'indicateur natif d'omarchy et que l'OSD de voxtype.

  readonly property string glyphMic: "󰍬"
  readonly property string glyphStreaming: "󰜟"
  readonly property string glyphTranscribing: "󰔟"

  readonly property string currentGlyph: {
    if (daemonState === "transcribing") return glyphTranscribing
    if (daemonState === "streaming") return glyphStreaming
    return glyphMic
  }

  readonly property string stateLabel: {
    if (daemonState === "recording") return "Recording"
    if (daemonState === "streaming") return "Streaming"
    if (daemonState === "transcribing") return "Transcribing"
    return "Idle"
  }

  // --- Actions ---------------------------------------------------------------

  function toggleRecording() {
    if (bar) bar.run("voxtype record toggle")
  }

  function openSettings() {
    if (bar) bar.run("omarchy-voxtype-config")
  }

  // --- Ouverture du panneau --------------------------------------------------

  property bool opened: false

  function open() {
    if (!installed) return

    opened = true
    refreshInfo()
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

  readonly property bool primaryInstance: {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screens = Quickshell.screens
    return !!window && screens.length > 0 && window.screen === screens[0]
  }

  // Pilotable depuis un raccourci, comme les autres widgets de la barre :
  //   omarchy-shell menubar.voxtype toggle
  IpcHandler {
    enabled: root.primaryInstance
    target: "menubar.voxtype"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function record(): void { root.toggleRecording() }
  }

  // --- Occupation de la barre ------------------------------------------------
  // Le micro reste dans l'ilot en permanence : c'est lui qui rend le panneau
  // atteignable, et la dictee se declenche assez rarement pour qu'un widget
  // apparaissant puis disparaissant fasse sursauter ses voisins a chaque fois.
  // Seule la waveform se deplie, comme la jauge du volume juste a cote.

  readonly property bool shown: installed
  readonly property bool waveAvailable: !vertical

  readonly property int buttonSize: vertical
    ? islandSize
    : Math.max(Style.space(24), islandRadius * 2)
  readonly property int fullExtent: buttonSize + (waveAvailable && busy ? waveLength + Style.space(6) : 0)

  // Non `readonly` : un Behavior ne peut pas s'attacher a une propriete en
  // lecture seule, alors que c'est ce binding qu'il doit animer.
  property int extent: shown ? fullExtent : 0

  Behavior on extent {
    NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
  }

  visible: extent > 0
  implicitWidth: vertical ? islandSize : extent
  implicitHeight: vertical ? extent : islandSize

  // Halo de survol cale sur le bouton seul : la waveform garde le fond de
  // l'ilot. Meme rayon que l'ilot, et non la moitie de la hauteur, que Qt
  // rabattrait plus court que l'ilot qui l'entoure.
  //
  // Il est fils direct du widget, et non du cadre qui clippe la waveform : ce
  // clip lui couperait le debordement de `haloInset` et le ferait paraitre plus
  // petit et moins large que les halos voisins.
  // Il epouse le bouton par ancrage plutot qu'en refaisant son calcul de
  // taille : deux geometries ecrites separement finissent toujours par diverger.
  Rectangle {
    anchors.fill: button
    anchors.leftMargin: -root.haloInsetX
    anchors.rightMargin: -root.haloInsetX
    anchors.topMargin: -root.haloInsetY
    anchors.bottomMargin: -root.haloInsetY
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
    text: root.currentGlyph
    // Le micro s'allume pendant que voxtype ecoute : c'est le seul etat que la
    // barre doit pouvoir signaler d'un coup d'oeil.
    active: root.listening
    tooltipText: root.stateLabel
    fixedWidth: root.buttonSize
    fixedHeight: root.islandSize
    // Pas de `rightExtraMargin` ici : le recul de deux pixels que portent les
    // widgets voisins corrige le bearing de leur propre glyphe, pas celui du
    // micro, qui tombe deja centre dans son bouton.
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.toggleRecording()
      else root.toggle()
    }
  }

  // La piste garde sa longueur pendant que le cadre se replie : la waveform
  // disparait en glissant sous le bord plutot qu'en se comprimant. Sur une barre
  // verticale elle n'a pas la place de defiler, le widget se reduit alors a son
  // glyphe, qui porte l'accent pendant la dictee.
  Item {
    x: root.buttonSize
    width: Math.max(0, root.extent - root.buttonSize)
    height: root.islandSize
    visible: root.waveAvailable
    clip: true

    Canvas {
      id: waveCanvas

      x: Style.space(3)
      width: root.waveLength
      height: root.islandSize - Style.space(8)
      anchors.verticalCenter: parent.verticalCenter

      onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)

        var values = root.samples
        if (!values || values.length === 0) return

        var middle = height / 2
        var maxHalf = middle - 1
        var slot = width / root.columns
        // Colonnes vides a gauche tant que le tampon n'est pas plein, pour que
        // la trame la plus recente reste collee au bord droit.
        var offset = root.columns - values.length

        ctx.strokeStyle = root.accentColor
        ctx.lineWidth = Math.max(1, slot - 1)
        ctx.lineCap = "butt"
        ctx.beginPath()

        for (var i = 0; i < values.length; i++) {
          var x = (offset + i) * slot + slot / 2
          var half = Math.min(maxHalf, values[i] * maxHalf * root.waveGain)
          // Une trame silencieuse ne doit pas disparaitre : le trait mediant
          // montre que la piste tourne et que le micro est bien ouvert.
          if (half < 0.5) half = 0.5
          ctx.moveTo(x, middle - half)
          ctx.lineTo(x, middle + half)
        }

        ctx.stroke()
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
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: root.toggleRecording()

      ScrollView {
        id: scrollArea

        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: content.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        // Deploiement : le contenu glisse depuis le bord occupe par la barre et
        // se resserre legerement, pendant que la carte fait son propre fondu. Le
        // decalage se fait par transform, `anchors.fill` possedant deja x/y.
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

                text: root.currentGlyph
                color: root.listening ? root.accentColor : root.foregroundColor
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
                  text: "Voxtype"
                  color: root.foregroundColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: root.stateLabel.toUpperCase()
                  color: root.listening ? root.accentColor : root.mutedColor
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

          // ---- Moteur ----
          PanelIsland {

            SectionHeader { text: "ENGINE" }

            DetailRow {
              label: "Model"
              value: root.model !== "" ? root.model : "—"
            }

            DetailRow {
              label: "Backend"
              value: root.backend !== "" ? root.backend : "—"
            }

            DetailRow {
              label: "Device"
              value: root.device !== "" ? root.device : "—"
            }
          }

          // ---- Actions ----
          PanelIsland {

            ActionRow {
              glyph: root.glyphMic
              label: root.listening ? "Arreter la dictee" : "Demarrer la dictee"
              highlighted: root.listening
              onActivated: root.toggleRecording()
            }

            ActionRow {
              glyph: "󰒓"
              label: "Configurer voxtype"
              onActivated: {
                root.close()
                root.openSettings()
              }
            }
          }
        }
      }
    }
  }

  // --- Composants internes ---------------------------------------------------

  // Ilot de section : meme vocabulaire que les ilots de la barre, transpose sur
  // le fond opaque de la carte.
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
      width: parent.width - Style.space(140)
      anchors.left: parent.left
      anchors.leftMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: detailRow.value
      color: root.foregroundColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      width: Style.space(136)
      horizontalAlignment: Text.AlignRight
      anchors.right: parent.right
      anchors.rightMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Ligne d'action : glyphe puis intitule, surlignee au survol comme les lignes
  // de peripherique des autres panneaux.
  component ActionRow: CursorSurface {
    id: actionRow

    property string glyph: ""
    property string label: ""
    property bool highlighted: false

    signal activated()

    width: parent.width
    height: Style.space(30)
    foreground: root.foregroundColor
    accent: root.accentColor
    hasCursor: actionHover.hovered
    current: actionRow.highlighted

    HoverHandler { id: actionHover }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: actionRow.activated()
    }

    Row {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: actionRow.glyph
        color: actionRow.highlighted ? root.accentColor : root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        width: Style.space(20)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: actionRow.label
        color: actionRow.highlighted ? root.accentColor : root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: actionRow.highlighted
        elide: Text.ElideRight
        width: parent.width - Style.space(36)
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
