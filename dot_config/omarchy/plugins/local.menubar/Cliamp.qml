import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

// Widget cliamp : le spectre en direct dans la barre, et au clic un panneau
// avec le morceau, les controles et les favoris radio.
//
// Trois canaux, chacun pour ce qu'il fait de mieux :
//   - MPRIS (org.mpris.MediaPlayer2.cliamp) pour l'etat et le transport : il
//     pousse ses changements, aucun sondage necessaire ;
//   - `cliamp visstream`, un flux NDJSON d'une frame par ligne, pour le
//     spectre ;
//   - le socket de commande, via la CLI, pour le volume et les stations, que
//     MPRIS n'expose pas.
//
// Le widget reste dans la barre meme sans cliamp : le spectre retombe a plat
// et le bouton de lecture du panneau demarre alors le lecteur.
BarWidget {
  id: root
  moduleName: "local.menubar.cliamp"

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

  // --- Lecteur MPRIS ---------------------------------------------------------

  readonly property var player: {
    var players = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < players.length; i++) {
      var candidate = players[i]
      if (!candidate) continue
      // On vise cliamp et lui seul : les autres lecteurs de la session ne
      // doivent pas se retrouver pilotes par ce widget.
      if (String(candidate.dbusName || "").indexOf("cliamp") !== -1) return candidate
      if (String(candidate.identity || "").toLowerCase() === "cliamp") return candidate
    }
    return null
  }

  readonly property bool available: player !== null
  readonly property bool playing: available && player.isPlaying
  readonly property string trackTitle: available ? String(player.trackTitle || "") : ""
  readonly property string trackArtist: available ? String(player.trackArtist || "") : ""
  readonly property real trackLength: available && player.lengthSupported ? player.length : 0
  readonly property string streamUrl: available && player.metadata
    ? String(player.metadata["xesam:url"] || "")
    : ""

  // Nom du favori correspondant au flux en cours, s'il en fait partie.
  readonly property string favoriteName: {
    var url = streamUrl || trackTitle
    if (!url) return ""

    for (var i = 0; i < favorites.length; i++) {
      if (String(favorites[i].url || "") === url) return String(favorites[i].name || "")
    }
    return ""
  }

  // Tant qu'un flux n'a pas envoye ses metadonnees ICY, cliamp annonce son URL
  // comme titre. On lui substitue alors le nom de la station, faute de quoi la
  // barre afficherait « http://usa9.fastcast4u.com/proxy/… ».
  readonly property string displayTitle: {
    if (trackTitle !== "" && !/^https?:\/\//.test(trackTitle)) return trackTitle
    if (favoriteName !== "") return favoriteName
    return trackTitle !== "" ? "Radio" : ""
  }

  property real livePosition: 0

  Timer {
    interval: 500
    running: root.available && root.playing && root.opened
    repeat: true
    onTriggered: root.livePosition = root.player.position
  }

  Connections {
    target: root.player
    enabled: root.available
    function onPositionChanged() { root.livePosition = root.player.position }
    function onTrackTitleChanged() { root.livePosition = 0 }
  }

  function formatTime(seconds) {
    if (!isFinite(seconds) || seconds < 0) return "--:--"

    var total = Math.floor(seconds)
    var minutes = Math.floor(total / 60)
    var rest = total % 60
    return minutes + ":" + (rest < 10 ? "0" : "") + rest
  }

  // --- Spectre ---------------------------------------------------------------
  // `cliamp visstream` emet un objet JSON par ligne. Les frames en erreur
  // (`ok: false`) sont ignorees : c'est ce que renvoie cliamp lance en mode
  // daemon, ou la visualisation n'est pas calculee. Le spectre reste alors
  // vide et sa zone se replie.

  property var bands: []
  property string visualizerMode: ""

  function parseBandFrame(line) {
    if (!line) return

    try {
      var frame = JSON.parse(line)
      if (!frame || !frame.ok) return
      if (frame.bands) root.bands = frame.bands
      if (frame.visualizer) root.visualizerMode = String(frame.visualizer)
    } catch (e) {
      // Ligne tronquee : la suivante arrivera dans 1/30 s.
    }
  }

  Process {
    id: bandStream

    // 20 images par seconde : le spectre de la barre reste fluide a l'oeil et
    // c'est un tiers de trames en moins a analyser que les 30 par defaut.
    command: ["cliamp", "visstream", "--fps", "20"]
    // Pilote imperativement, et non par binding : le timer de relance doit
    // pouvoir le rallumer apres un redemarrage de cliamp.
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { root.parseBandFrame(line) }
    }
  }

  // --- Presence du socket ----------------------------------------------------
  // `visstream` parle au socket de cliamp, pas a MPRIS, et les deux ne vont pas
  // toujours ensemble : une seconde instance de cliamp perd le nom MPRIS mais
  // garde son socket, et un socket peut disparaitre sous une instance bien
  // vivante. C'est donc le socket, et lui seul, qui conditionne le flux — sinon
  // la relance forke `cliamp visstream` toutes les deux secondes dans le vide.

  property bool socketPresent: false

  Process {
    id: socketProbe

    command: ["test", "-S", Quickshell.env("HOME") + "/.config/cliamp/cliamp.sock"]
    onExited: function(exitCode) { root.socketPresent = exitCode === 0 }
  }

  function probeSocket() {
    if (!socketProbe.running) socketProbe.running = true
  }

  // Un socket ne se lit pas : FileView surveille le dossier qui le contient et
  // on resonde a chaque mouvement.
  FileView {
    path: Quickshell.env("HOME") + "/.config/cliamp"
    watchChanges: true
    printErrors: false
    onFileChanged: root.probeSocket()
  }

  // Filet, pour les cas ou la notification du dossier n'arrive pas.
  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.probeSocket()
  }

  // Le flux tourne des que le socket est la : le spectre vit dans la barre, pas
  // seulement dans le panneau.
  readonly property bool bandStreamWanted: socketPresent

  onBandStreamWantedChanged: {
    if (bandStreamWanted) bandStream.running = true
    else {
      bandStream.running = false
      bands = []
    }
  }

  Timer {
    interval: 2000
    running: root.bandStreamWanted && !bandStream.running
    repeat: true
    onTriggered: bandStream.running = true
  }

  // --- Commandes -------------------------------------------------------------
  // Le volume et le choix de station ne passent pas par MPRIS : on repasse par
  // la CLI, qui parle au socket de cliamp.

  Process { id: commandProc }

  function runCommand(args) {
    if (commandProc.running) return

    commandProc.command = ["cliamp"].concat(args)
    commandProc.running = true
  }

  // Demarre cliamp sans lui ouvrir de fenetre.
  //
  // Les deux voies evidentes echouent : en `--daemon`, cliamp ne calcule pas
  // ses bandes et `visstream` ne renvoie que des « bands timeout », donc pas de
  // spectre ; dans un terminal, il en ouvre un, ce qu'on ne veut pas. Ce qu'il
  // lui faut n'est pas une fenetre mais un terminal — `script` lui en fournit
  // un, un pseudo-terminal jete dans /dev/null : cliamp dessine son interface
  // dans le vide, sans que rien ne s'affiche, et calcule bien ses bandes.
  //
  // Le tout passe par un shell : `setsid` doit forker et rendre la main pour
  // que le lecteur survive au shell graphique, ce qu'un appel direct ne fait
  // pas.
  function launchPlayer() {
    Quickshell.execDetached(["bash", "-c",
      "setsid script -qfc 'cliamp --auto-play' /dev/null >/dev/null 2>&1 &"])
  }

  // Le bouton principal demarre le lecteur quand il est absent, et bascule
  // lecture/pause sinon.
  function primaryAction() {
    if (!available) {
      launchPlayer()
      return
    }
    player.togglePlaying()
  }

  // Volume en dB, borne comme cliamp lui-meme.
  readonly property real minVolumeDb: -30
  readonly property real maxVolumeDb: 6
  property real volumeDb: 0

  function setVolume(db) {
    var clamped = Math.max(minVolumeDb, Math.min(maxVolumeDb, db))
    volumeDb = clamped
    runCommand(["volume", String(Math.round(clamped))])
  }

  // --- Etat lu sur le socket -------------------------------------------------
  // MPRIS ne dit rien du volume ni de la position dans la file : un `status`
  // ponctuel comble le trou, uniquement panneau ouvert.

  property int queueIndex: -1
  property int queueTotal: 0

  Process {
    id: statusProc

    command: ["cliamp", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseStatus(text)
    }
  }

  function parseStatus(raw) {
    // `cliamp status` sort du texte lisible ; on y pioche ce qui manque a MPRIS.
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var match = lines[i].match(/^Volume:\s*(-?[0-9.]+)/)
      if (match) root.volumeDb = Number(match[1])
    }
  }

  Timer {
    interval: 2000
    running: root.opened && root.available
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!statusProc.running) statusProc.running = true
  }

  // --- Favoris radio ---------------------------------------------------------
  // `radio_favorites.toml` est un TOML minimal : des blocs [[station]] suivis
  // de `cle = "valeur"`. Pas de parseur TOML en QML, mais ce sous-ensemble se
  // lit sans risque.

  property var favorites: []

  function parseFavorites(content) {
    var stations = []
    var current = null
    var lines = String(content || "").split("\n")

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim()
      if (line === "[[station]]") {
        current = ({})
        stations.push(current)
        continue
      }
      if (!current || line === "" || line.charAt(0) === "#") continue

      var match = line.match(/^([A-Za-z0-9_]+)\s*=\s*(.*)$/)
      if (!match) continue

      var value = match[2].trim()
      // Retire les guillemets ; les nombres (bitrate) restent tels quels.
      if (value.length >= 2 && value.charAt(0) === '"' && value.charAt(value.length - 1) === '"')
        value = value.substring(1, value.length - 1)
      current[match[1]] = value
    }

    // Une station sans URL n'est pas jouable : autant ne pas l'afficher.
    favorites = stations.filter(function(station) { return !!station.url })
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/cliamp/radio_favorites.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parseFavorites(text())
    onLoadFailed: root.favorites = []
  }

  // Jouer une station demande deux temps : `queue` l'ajoute en fin de file,
  // puis il faut avancer jusqu'a elle — cliamp n'expose aucune commande pour
  // sauter directement a un index. Le nombre de sauts est connu : la piste
  // ajoutee est la derniere, donc `total - 1 - index` crans plus loin.
  property string pendingStationUrl: ""

  function playStation(station) {
    if (!station || !station.url || commandProc.running) return

    pendingStationUrl = String(station.url)
    queueProc.command = ["cliamp", "queue", pendingStationUrl]
    queueProc.running = true
  }

  Process {
    id: queueProc

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.pendingStationUrl = ""
        return
      }
      jumpStatusProc.running = true
    }
  }

  // Relit la file juste apres l'ajout pour savoir de combien avancer.
  Process {
    id: jumpStatusProc

    command: ["bash", "-c",
              "printf '%s\\n' '{\"cmd\":\"status\"}' | socat - UNIX-CONNECT:\"$HOME/.config/cliamp/cliamp.sock\""]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.jumpToQueued(text)
    }
  }

  function jumpToQueued(raw) {
    if (!pendingStationUrl) return

    var index = 0
    var total = 0
    try {
      var status = JSON.parse(String(raw || "{}"))
      index = Number(status.index || 0)
      total = Number(status.total || 0)
    } catch (e) {
      pendingStationUrl = ""
      return
    }

    var steps = total - 1 - index
    pendingStationUrl = ""
    if (steps <= 0) return

    // Les sauts partent d'un coup : enchaines sans pause, cliamp n'a pas le
    // temps de mettre en tampon les stations traversees.
    var script = ""
    for (var i = 0; i < steps; i++) script += "cliamp next >/dev/null 2>&1; "
    jumpProc.command = ["bash", "-c", script]
    jumpProc.running = true
  }

  Process { id: jumpProc }

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

  readonly property bool primaryInstance: {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screens = Quickshell.screens
    return !!window && screens.length > 0 && window.screen === screens[0]
  }

  IpcHandler {
    enabled: root.primaryInstance
    target: "menubar.cliamp"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    // Demarre cliamp s'il est absent, bascule lecture/pause sinon.
    function play(): void { root.primaryAction() }
  }

  // --- Glyphes ---------------------------------------------------------------

  readonly property string glyphNote: "󰝚"
  readonly property string glyphPlay: "󰐊"
  readonly property string glyphPause: "󰏤"
  readonly property string glyphPrevious: "󰒮"
  readonly property string glyphNext: "󰒭"
  readonly property string glyphRadio: "󰐹"

  // --- Bouton de barre -------------------------------------------------------

  // La barre montre l'un ou l'autre, jamais les deux : le spectre des que
  // quelque chose joue, sinon une antenne radio dont le libelle se deplie au
  // survol. Le widget reste en place meme sans cliamp — le panneau est alors
  // le seul endroit d'ou le demarrer.
  readonly property int contentGap: Style.space(6)
  readonly property int spectrumWidth: Style.space(52)
  readonly property int glyphWidth: Style.space(14)

  readonly property bool idle: !playing

  property int spectrumExtent: idle ? 0 : spectrumWidth
  property int glyphExtent: idle ? glyphWidth : 0
  property int labelExtent: idle && widgetHover.hovered ? idleLabel.implicitWidth + contentGap : 0

  Behavior on spectrumExtent {
    NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
  }
  Behavior on glyphExtent {
    NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
  }
  Behavior on labelExtent {
    NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
  }

  // Le spectre a besoin d'un modele meme a vide, sinon ses colonnes
  // disparaissent au lieu de retomber a plat pendant la transition.
  readonly property var displayBands: bands.length > 0 ? bands : [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

  implicitWidth: contentGap + glyphExtent + labelExtent + spectrumExtent + contentGap
  implicitHeight: islandSize

  // Pas de tooltip ici : rien ne doit surgir au survol du spectre. Le titre,
  // l'artiste et l'etat de lecture vivent dans le panneau.
  HoverHandler { id: widgetHover }

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -root.haloInsetX
    anchors.rightMargin: -root.haloInsetX
    anchors.topMargin: -root.haloInsetY
    anchors.bottomMargin: -root.haloInsetY
    radius: root.islandRadius
    color: root.accentColor
    opacity: widgetHover.hovered || root.opened ? root.accentFillOpacity : 0

    Behavior on opacity {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }
  }

  // Antenne radio et son libelle, quand rien ne joue.
  Item {
    x: root.contentGap
    width: root.glyphExtent
    height: parent.height
    clip: true
    opacity: root.idle ? 1 : 0

    Behavior on opacity {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }

    Text {
      width: root.glyphWidth
      text: root.glyphRadio
      color: root.available ? root.foregroundColor : root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      renderType: Text.NativeRendering
      horizontalAlignment: Text.AlignHCenter
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Item {
    x: root.contentGap + root.glyphExtent
    width: root.labelExtent
    height: parent.height
    clip: true

    Text {
      id: idleLabel

      x: root.contentGap
      text: "Radio"
      color: root.available ? root.foregroundColor : root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      renderType: Text.NativeRendering
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Item {
    id: barSpectrum

    x: root.contentGap + root.glyphExtent + root.labelExtent
    width: root.spectrumExtent
    height: parent.height
    clip: true

    readonly property int columnGap: Math.max(1, Style.space(1))
    readonly property real columnWidth: root.displayBands.length > 0
      ? (root.spectrumWidth - columnGap * (root.displayBands.length - 1)) / root.displayBands.length
      : 0
    // Hauteur utile : on garde un peu d'air en haut et en bas de l'ilot.
    readonly property real usableHeight: height - Style.space(10)

    Row {
      anchors.verticalCenter: parent.verticalCenter
      height: barSpectrum.usableHeight
      spacing: barSpectrum.columnGap

      Repeater {
        model: root.displayBands

        Item {
          required property var modelData

          width: barSpectrum.columnWidth
          height: barSpectrum.usableHeight

          Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Math.max(1, parent.height * Math.max(0, Math.min(1, modelData)))
            radius: width / 2
            // Estompe tant que rien ne joue : la ligne plate ne doit pas
            // ressembler a un spectre fige.
            color: root.playing ? root.accentColor : root.mutedColor
            opacity: root.available ? 1 : 0.5

            // Sans lissage, le spectre scintille a 20 images par seconde.
            Behavior on height {
              NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
            }
          }
        }
      }
    }
  }

  MouseArea {
    id: button

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.MiddleButton) root.primaryAction()
      else root.toggle()
    }
    onWheel: function(wheel) {
      root.setVolume(root.volumeDb + (wheel.angleDelta.y > 0 ? 1 : -1))
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
      onActivateRequested: root.primaryAction()
      onMoveRequested: function(dx, dy) {
        if (dx > 0) root.setVolume(root.volumeDb + 1)
        else if (dx < 0) root.setVolume(root.volumeDb - 1)
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

          // ---- Lecture en cours ----
          PanelIsland {

            Item {
              width: parent.width
              implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

              Text {
                id: heroIcon

                text: root.playing ? root.glyphNote : root.glyphPause
                color: root.playing ? root.accentColor : root.foregroundColor
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
                  text: root.available ? (root.displayTitle || "Nothing playing") : "cliamp not running"
                  color: root.foregroundColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: (root.trackArtist || (root.playing ? "PLAYING" : "PAUSED")).toUpperCase()
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

            // Spectre : une colonne par bande, remplie du bas.
            Item {
              width: parent.width
              implicitHeight: Style.space(34)
              visible: root.bands.length > 0

              Row {
                id: spectrum

                anchors.fill: parent
                anchors.topMargin: Style.space(6)
                spacing: Style.space(2)

                readonly property real columnWidth: root.bands.length > 0
                  ? (width - spacing * (root.bands.length - 1)) / root.bands.length
                  : 0

                Repeater {
                  model: root.bands

                  Item {
                    required property var modelData

                    width: spectrum.columnWidth
                    height: spectrum.height

                    Rectangle {
                      anchors.bottom: parent.bottom
                      width: parent.width
                      height: Math.max(Style.space(2), parent.height * Math.max(0, Math.min(1, modelData)))
                      radius: Style.space(1)
                      color: root.accentColor
                      opacity: 0.85

                      // Sans lissage, le spectre scintille a 30 images/s.
                      Behavior on height {
                        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                      }
                    }
                  }
                }
              }
            }

            // Progression, seulement quand la piste a une duree : un flux radio
            // n'en a pas.
            Item {
              width: parent.width
              implicitHeight: Style.space(16)
              visible: root.trackLength > 0

              Text {
                text: root.formatTime(root.livePosition) + " / " + root.formatTime(root.trackLength)
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }

              Rectangle {
                width: parent.width - Style.space(80)
                height: Math.max(3, Style.space(4))
                radius: height / 2
                color: root.bar ? Style.selectedFillFor(root.bar.foreground, Color.accent) : Color.muted
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  width: parent.width * (root.trackLength > 0 ? Math.min(1, root.livePosition / root.trackLength) : 0)
                  height: parent.height
                  radius: parent.radius
                  color: root.accentColor
                }
              }
            }
          }

          // ---- Transport ----
          PanelIsland {

            SectionHeader {
              text: "TRANSPORT"
              value: Math.round(root.volumeDb) + " dB"
            }

            Row {
              width: parent.width
              height: Style.space(30)
              spacing: Style.space(6)

              TransportButton {
                glyph: root.glyphPrevious
                actionEnabled: root.available && root.player.canGoPrevious
                onActivated: if (root.available) root.player.previous()
              }

              TransportButton {
                glyph: root.playing ? root.glyphPause : root.glyphPlay
                highlighted: true
                // Toujours actif : sans cliamp, ce bouton le demarre.
                actionEnabled: !root.available || root.player.canTogglePlaying
                onActivated: root.primaryAction()
              }

              TransportButton {
                glyph: root.glyphNext
                actionEnabled: root.available && root.player.canGoNext
                onActivated: if (root.available) root.player.next()
              }
            }

            // Volume en dB : l'echelle de cliamp, pas un pourcentage.
            PanelSlider {
              width: parent.width - Style.space(4)
              x: Style.space(2)
              bar: root.bar
              fillColor: root.accentColor
              knobColor: root.accentColor
              minimum: root.minVolumeDb
              maximum: root.maxVolumeDb
              step: 1
              integer: true
              value: root.volumeDb
              onMoved: function(value) { root.setVolume(value) }
            }
          }

          // ---- Favoris radio ----
          PanelIsland {
            visible: root.favorites.length > 0

            SectionHeader {
              text: "RADIO FAVORITES"
              value: String(root.favorites.length)
            }

            Repeater {
              model: root.favorites

              StationRow {
                required property var modelData

                width: parent.width
                station: modelData
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
      spacing: Style.space(6)
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

  // `enabled` et `current` appartiennent deja a Item et CursorSurface : les
  // redeclarer les masquerait, d'ou les noms propres a ces composants.
  component TransportButton: CursorSurface {
    id: transportButton

    property string glyph: ""
    property bool highlighted: false
    property bool actionEnabled: true

    signal activated()

    width: (parent.width - Style.space(12)) / 3
    height: parent.height
    foreground: root.foregroundColor
    accent: root.accentColor
    hasCursor: hover.hovered && transportButton.actionEnabled

    HoverHandler { id: hover }

    MouseArea {
      anchors.fill: parent
      enabled: transportButton.actionEnabled
      cursorShape: Qt.PointingHandCursor
      onClicked: transportButton.activated()
    }

    Text {
      anchors.centerIn: parent
      text: transportButton.glyph
      color: transportButton.highlighted ? root.accentColor : root.foregroundColor
      opacity: transportButton.actionEnabled ? 1 : 0.35
      font.family: root.fontFamily
      font.pixelSize: Style.font.icon
    }
  }

  component StationRow: CursorSurface {
    id: stationRow

    required property var station

    // La station jouee se reconnait a son URL, le titre affiche etant celui du
    // flux et non celui du favori.
    readonly property bool isCurrent: root.available
      && String(station.url || "") !== ""
      && String(root.player.metadata ? (root.player.metadata["xesam:url"] || "") : "") === String(station.url)

    width: parent.width
    height: Style.space(30)
    foreground: root.foregroundColor
    accent: root.accentColor
    current: stationRow.isCurrent
    hasCursor: stationHover.hovered

    HoverHandler { id: stationHover }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.playStation(stationRow.station)
    }

    Text {
      text: root.glyphRadio
      color: stationRow.isCurrent ? root.accentColor : root.foregroundColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.icon
      width: Style.space(20)
      horizontalAlignment: Text.AlignHCenter
      anchors.left: parent.left
      anchors.leftMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
    }

    Column {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(32)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0

      Text {
        text: String(stationRow.station.name || "Unnamed station")
        color: stationRow.isCurrent ? root.accentColor : root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: stationRow.isCurrent
        elide: Text.ElideRight
        width: parent.width
      }

      Text {
        text: {
          var parts = []
          if (stationRow.station.codec) parts.push(String(stationRow.station.codec))
          if (stationRow.station.bitrate) parts.push(String(stationRow.station.bitrate) + " kb/s")
          return parts.join(" · ")
        }
        visible: text !== ""
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        width: parent.width
      }
    }
  }
}
