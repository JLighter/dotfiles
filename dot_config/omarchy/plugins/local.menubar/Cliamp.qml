import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui
import "CliampModel.js" as Model

// Widget cliamp : le spectre en direct dans la barre, et au clic un panneau
// avec le morceau, les controles et les favoris radio.
//
// Quatre canaux, chacun pour ce qu'il fait de mieux :
//   - MPRIS (org.mpris.MediaPlayer2.cliamp) pour l'etat et le transport : il
//     pousse ses changements, aucun sondage necessaire ;
//   - le socket de commande, tenu ouvert, pour ce que MPRIS ne dit pas : le
//     volume en dB, l'album, la position dans la file, le mode de repetition ;
//   - `cliamp visstream`, un flux NDJSON d'une frame par ligne, pour le
//     spectre ;
//   - la CLI, pour les mutations : elles sont rares, declenchees par un clic,
//     et l'interface en ligne de commande est la seule stable — le schema des
//     requetes du socket, lui, n'est pas documente.
//
// Le widget reste dans la barre meme sans cliamp : le spectre retombe a plat
// et le bouton de lecture du panneau demarre alors le lecteur. Il fonctionne
// aussi sans MPRIS — une seconde instance de cliamp perd le nom D-Bus mais
// garde son socket, et le panneau reste alors pilotable.
//
// La logique de lecture des formats vit dans CliampModel.js, testee par
// `node --test tests/`.
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

  readonly property string cliampDir: Quickshell.env("HOME") + "/.config/cliamp"

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

  readonly property bool hasMpris: player !== null

  // --- Socket de commande ----------------------------------------------------
  // Une connexion tenue ouverte remplace trois `Process` par sondage : le
  // `test -S` qui cherchait le socket, le `cliamp status` toutes les deux
  // secondes, et le `printf … | socat` qui lisait la file.
  //
  // Elle repare surtout une confusion : `test -S` ne distingue pas un socket
  // vivant d'un socket laisse derriere lui par un cliamp mort. Le widget
  // croyait alors le lecteur present et relancait `visstream` dans le vide
  // toutes les deux secondes. Une connexion, elle, est refusee.

  property var playerStatus: Model.emptyStatus()
  property bool socketPresent: false
  property string ipcBuffer: ""

  Socket {
    id: ipc

    path: root.cliampDir + "/cliamp.sock"

    parser: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { root.onIpcLine(line) }
    }

    onConnectionStateChanged: {
      // Peu frequent, et ce widget s'est revele assez difficile a diagnostiquer
      // pour que la trace vaille son cout dans le log du shell.
      console.log("local.menubar.cliamp: socket", ipc.connected ? "connecte" : "deconnecte")

      if (ipc.connected) {
        root.ipcBuffer = ""
        root.requestStatus()
      }
    }

    // Ni une deconnexion ni une erreur ne prouvent quoi que ce soit : le schema
    // des requetes n'etant pas documente, on ne sait pas si cliamp garde la
    // connexion ouverte ou la referme apres chaque reponse — et un « peer
    // closed » ne se distingue d'un « connection refused » que par un code
    // d'erreur sur lequel on ne veut pas parier. C'est le chien de garde
    // ci-dessous qui tranche, sur le seul fait qui compte : une reponse
    // recente, ou non.
  }

  // Une seule cadence pour les trois timers ci-dessous. Ils se repondent, et
  // les desynchroniser coute cher : un chien de garde plus court que l'intervalle
  // de sondage ne peut jamais gagner — il declare cliamp perdu entre deux
  // statuts, tue `visstream`, la reconnexion le relance, et le spectre de la
  // barre passe son temps a mourir et renaitre.
  readonly property int pollInterval: opened ? 2000 : 10000

  // Trois sondages sans reponse et cliamp est declare parti. Conclure sur une
  // seule deconnexion ferait clignoter le spectre a chaque cycle si cliamp
  // referme apres sa reponse.
  property int missedStatus: 0

  Timer {
    interval: root.pollInterval
    running: true
    repeat: true
    onTriggered: {
      if (!root.socketPresent) return

      root.missedStatus += 1
      if (root.missedStatus >= 3) root.onIpcLost()
    }
  }

  function onIpcLost() {
    socketPresent = false
    ipcBuffer = ""
    // On garde le dernier statut connu : l'affichage se gouverne a `available`,
    // et l'effacer ne ferait que vider le panneau d'un coup pour rien.
    ipc.connected = false
  }

  // cliamp repond en JSON indente : le decoupage sur « \n » ne rend que des
  // morceaux, qu'on accumule jusqu'a tenir un objet complet.
  function onIpcLine(line) {
    ipcBuffer += line

    if (!Model.isCompleteJson(ipcBuffer)) {
      // Garde-fou : une reponse qui ne se referme jamais ne doit pas faire
      // enfler le tampon indefiniment.
      if (ipcBuffer.length > 65536) ipcBuffer = ""
      return
    }

    var parsed = Model.parseStatus(ipcBuffer)
    ipcBuffer = ""
    if (parsed) root.applyStatus(parsed)
  }

  function applyStatus(parsed) {
    playerStatus = parsed

    // Une reponse est la seule preuve que cliamp est bien la, derriere ce
    // socket, et pas seulement un fichier laisse par un processus mort.
    socketPresent = true
    missedStatus = 0

    // Station cliquee avant que cliamp ne soit joignable : elle attendait ce
    // moment precis.
    if (pendingStationUrl !== "") {
      var wanted = pendingStationUrl
      pendingStationUrl = ""
      sendStation(wanted)
    }

    // Le volume ne remonte que d'ici : MPRIS l'exprime en amplitude relative au
    // maximum de cliamp (1.0 vaut +6 dB), pas en dB. On ne l'ecrase pas tant
    // qu'un reglage est en attente d'envoi, sinon la molette recule.
    if (parsed.hasVolume && isNaN(pendingVolumeDb)) volumeDb = parsed.volume

    // Sans MPRIS, le statut est la seule source de position.
    if (!hasMpris) livePosition = parsed.position

    if (opened && !nextProc.running) nextProc.running = true
  }

  function requestStatus() {
    if (!ipc.connected) return

    ipc.write('{"cmd":"status"}\n')
    ipc.flush()
  }

  // Tant que la connexion est ouverte, on redemande le statut ; si cliamp la
  // ferme apres chaque reponse, c'est le timer de reconnexion ci-dessous qui
  // prend le relais. Les deux ensemble marchent quel que soit le comportement
  // du serveur.
  Timer {
    interval: root.opened ? 2000 : 10000
    running: ipc.connected
    repeat: true
    onTriggered: root.requestStatus()
  }

  Timer {
    interval: root.opened ? 2000 : 10000
    running: !ipc.connected
    repeat: true
    triggeredOnStart: true
    onTriggered: ipc.connected = true
  }

  // Apres une commande, le statut a change mais le tour de sondage est loin :
  // on redemande plus tot pour que le panneau suive le clic.
  Timer {
    id: refreshSoon

    interval: 400
    repeat: false
    onTriggered: root.requestStatus()
  }

  // --- Etat de lecture -------------------------------------------------------
  // MPRIS d'abord : il pousse ses changements et le titre suit la piste sans
  // delai. Le statut prend le relais quand le nom D-Bus n'est pas la.

  readonly property bool available: hasMpris || socketPresent
  readonly property bool playing: hasMpris ? player.isPlaying : playerStatus.playing
  readonly property string trackTitle: hasMpris ? String(player.trackTitle || "") : playerStatus.title
  readonly property string trackArtist: hasMpris ? String(player.trackArtist || "") : playerStatus.artist
  readonly property string trackAlbum: playerStatus.album
  readonly property real trackLength: hasMpris && player.lengthSupported && player.length > 0
    ? player.length
    : playerStatus.duration
  readonly property string streamUrl: {
    if (hasMpris && player.metadata) {
      var url = String(player.metadata["xesam:url"] || "")
      if (url !== "") return url
    }
    return playerStatus.path
  }

  // Une piste se scrute des qu'elle a une duree. Le drapeau `stream` ne sert a
  // rien : cliamp le met aussi a vrai pour les pistes de bibliotheque servies
  // en HTTP, qui elles se scrutent tres bien.
  readonly property bool seekable: trackLength > 0

  readonly property string favoriteName: Model.favoriteNameFor(favorites, streamUrl || trackTitle)
  readonly property string displayTitle: Model.displayTitle(trackTitle, favoriteName)

  property real livePosition: 0

  Timer {
    interval: 500
    running: root.available && root.playing && root.opened
    repeat: true
    // Sans MPRIS personne ne pousse la position : on l'avance nous-memes entre
    // deux statuts, qui la recalent.
    onTriggered: root.livePosition = root.hasMpris ? root.player.position : root.livePosition + 0.5
  }

  Connections {
    target: root.player
    enabled: root.hasMpris

    function onPositionChanged() { root.livePosition = root.player.position }
    function onTrackTitleChanged() {
      root.livePosition = 0
      // La piste a change : le statut et la piste suivante sont perimes.
      refreshSoon.restart()
    }
  }

  // --- Piste suivante --------------------------------------------------------
  // `next-track` est un plugin Lua de cliamp, en lecture seule et sans
  // permission. S'il n'est pas installe — ou pas approuve par
  // `cliamp plugins trust next-track` — l'appel echoue et la ligne disparait
  // simplement du panneau.

  property var nextTrack: null

  Process {
    id: nextProc

    command: ["cliamp", "plugins", "call", "next-track", "next"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.nextTrack = Model.parseNext(text)
    }
  }

  // --- Spectre ---------------------------------------------------------------
  // `cliamp visstream` emet un objet JSON par ligne. Les frames en erreur sont
  // ignorees : c'est ce que renvoie cliamp lance en mode daemon, ou la
  // visualisation n'est pas calculee. Le spectre reste alors vide et sa zone se
  // replie.

  property var bands: []
  property string visualizerMode: ""

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
      onRead: function(line) {
        var frame = Model.parseBandFrame(line)
        if (!frame) return
        if (frame.bands) root.bands = frame.bands
        if (frame.visualizer) root.visualizerMode = frame.visualizer
      }
    }

    // `visstream` doit vivre tant que cliamp vit. S'il rend la main, c'est un
    // fait a connaitre : le spectre se fige sans autre signe exterieur.
    onExited: function(exitCode) {
      console.warn("local.menubar.cliamp: visstream s'est arrete, code", exitCode)
      root.bands = []
    }
  }

  // Le flux tourne des que la connexion est etablie — pas des que le statut a
  // fait son aller-retour. Les deux sont independants : le spectre n'a besoin
  // de rien d'autre que d'un cliamp joignable, et le lier a l'analyse du statut
  // le rendait otage d'un maillon qui ne le concerne pas.
  //
  // Une connexion reussie reste un bien meilleur test que l'ancien `test -S` :
  // un socket laisse par un cliamp mort refuse la connexion.
  readonly property bool spectrumWanted: ipc.connected

  onSpectrumWantedChanged: {
    if (spectrumWanted) bandStream.running = true
    else {
      bandStream.running = false
      bands = []
    }
  }

  Timer {
    interval: 2000
    running: root.spectrumWanted && !bandStream.running
    repeat: true
    onTriggered: bandStream.running = true
  }

  // --- Commandes -------------------------------------------------------------
  // Une file, pas un verrou : l'ancien code refusait toute commande pendant
  // qu'une autre tournait, et une molette un peu vive perdait ses crans en
  // route. Ici rien ne se perd, tout attend son tour.

  property var commandQueue: []

  Process {
    id: commandProc

    // Sans ceci, une commande qui echoue ne laisse aucune trace nulle part.
    // C'est ce qui a masque un cliamp demarre sans IPC : chaque clic repondait
    // « cliamp is not running » dans le vide, et le panneau restait muet.
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") console.warn("local.menubar.cliamp:", message)
      }
    }

    onExited: root.dequeueCommand()
  }

  function runCommand(args) {
    // Plafond : si cliamp se fige, la file ne doit pas enfler sans fin. Trente
    // deux commandes en attente, c'est deja bien au-dela de ce qu'un humain
    // empile en cliquant.
    if (commandQueue.length >= 32) return

    commandQueue = commandQueue.concat([args])
    dequeueCommand()
  }

  function dequeueCommand() {
    if (commandProc.running || commandQueue.length === 0) return

    var next = commandQueue[0]
    commandQueue = commandQueue.slice(1)
    commandProc.command = ["cliamp"].concat(next)
    commandProc.running = true
    refreshSoon.restart()
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
    if (hasMpris) player.togglePlaying()
    else runCommand(["toggle"])
  }

  function goPrevious() {
    if (hasMpris) player.previous()
    else if (available) runCommand(["prev"])
  }

  function goNext() {
    if (hasMpris) player.next()
    else if (available) runCommand(["next"])
  }

  // `cliamp seek` prend une position absolue en secondes.
  function seek(seconds) {
    if (!seekable) return

    var target = Math.max(0, Math.min(trackLength, seconds))
    livePosition = target
    runCommand(["seek", String(Math.round(target))])
  }

  // --- Volume ----------------------------------------------------------------
  // En dB, borne comme cliamp lui-meme. On ne passe pas par MPRIS : son volume
  // est une amplitude relative au maximum de cliamp — 1.0 y vaut +6 dB — et non
  // une echelle en dB.
  //
  // Les crans de molette sont regroupes : l'affichage suit le doigt, mais un
  // seul `cliamp volume` part une fois le geste retombe.

  readonly property real minVolumeDb: -30
  readonly property real maxVolumeDb: 6
  property real volumeDb: 0
  property real pendingVolumeDb: NaN

  Timer {
    id: volumeFlush

    interval: 80
    repeat: false
    onTriggered: root.flushVolume()
  }

  function setVolume(db) {
    var clamped = Math.max(minVolumeDb, Math.min(maxVolumeDb, db))
    volumeDb = clamped
    pendingVolumeDb = clamped
    volumeFlush.restart()
  }

  function flushVolume() {
    if (isNaN(pendingVolumeDb)) return

    var target = pendingVolumeDb
    pendingVolumeDb = NaN
    runCommand(["volume", String(Math.round(target))])
  }

  // --- Favoris radio ---------------------------------------------------------

  property var favorites: []

  FileView {
    path: root.cliampDir + "/radio_favorites.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.favorites = Model.parseFavorites(text())
    onLoadFailed: root.favorites = []
  }

  // Jouer une station demande un saut a un index de la file, que la CLI de
  // cliamp n'expose pas : elle sait empiler et avancer d'un cran, rien de plus.
  // L'ancien code empilait puis enchainait N `cliamp next` dans un sous-shell.
  //
  // `cliamp.queue.jump(index)` existe en revanche cote Lua, d'ou le plugin
  // omarchy-radio.lua qui fait le saut en une fois — et qui reutilise l'entree
  // deja presente au lieu d'empiler un doublon a chaque clic.
  //
  // Cliquer une station alors que cliamp n'est pas la ne doit pas rester sans
  // effet : les favoris s'affichent depuis le TOML, donc le panneau a l'air
  // vivant meme lecteur eteint, et le clic partait dans le vide. On demarre
  // alors cliamp et on garde la station sous le coude jusqu'a ce que le socket
  // reponde.
  property string pendingStationUrl: ""

  function playStation(station) {
    if (!station || !station.url) return

    var url = String(station.url)

    // On n'attend pas notre propre socket : `cliamp plugins call` ouvre sa
    // connexion a lui. Le conditionner a `socketPresent` imposait un premier
    // clic pour rien, le temps qu'un aller-retour de statut aboutisse.
    if (available || ipc.connected) {
      sendStation(url)
      return
    }

    // Cliamp vraiment absent : on le demarre et la station attend son arrivee.
    pendingStationUrl = url
    launchPlayer()
  }

  function sendStation(url) {
    runCommand(["plugins", "call", "omarchy-radio", "station", url])
  }

  // --- Ouverture -------------------------------------------------------------

  property bool opened: false

  function open() {
    opened = true
    requestStatus()
    if (socketPresent && !nextProc.running) nextProc.running = true
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
  readonly property string glyphShuffle: "󰒟"
  readonly property string glyphRepeat: "󰑖"

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
      // L'encre de l'antenne ne remplit pas sa boite symetriquement : elle
      // penche d'un pixel vers la droite. On decale la boite d'autant, a
      // l'echelle du theme comme le bearing qu'elle corrige.
      x: -Style.spaceReal(1)
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

                // L'album ne vient que du statut : MPRIS ne le publie pas.
                Text {
                  text: root.trackAlbum
                  visible: text !== ""
                  color: root.mutedColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
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

                      // Sans lissage, le spectre scintille a 20 images/s.
                      Behavior on height {
                        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                      }
                    }
                  }
                }
              }
            }

            // Progression, seulement quand la piste a une duree : un flux radio
            // n'en a pas. La barre est cliquable — la zone sensible fait toute
            // la hauteur de la ligne, pas les quatre pixels du trait.
            Item {
              width: parent.width
              implicitHeight: Style.space(16)
              visible: root.seekable

              Text {
                id: positionLabel

                text: Model.formatTime(root.livePosition) + " / " + Model.formatTime(root.trackLength)
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }

              Item {
                id: seekArea

                width: parent.width - Style.space(80)
                height: parent.height
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  id: seekTrack

                  width: parent.width
                  height: Math.max(3, Style.space(4))
                  radius: height / 2
                  color: root.bar ? Style.selectedFillFor(root.bar.foreground, Color.accent) : Color.muted
                  anchors.verticalCenter: parent.verticalCenter

                  Rectangle {
                    width: parent.width * (root.trackLength > 0
                      ? Math.min(1, root.livePosition / root.trackLength)
                      : 0)
                    height: parent.height
                    radius: parent.radius
                    color: root.accentColor
                  }
                }

                // Repere au survol : sans lui, rien ne dit que le trait se
                // clique.
                Rectangle {
                  width: Style.space(3)
                  height: seekTrack.height * 2.5
                  radius: width / 2
                  color: root.accentColor
                  visible: seekHover.hovered
                  x: Math.max(0, Math.min(seekArea.width - width, seekHover.point.position.x - width / 2))
                  anchors.verticalCenter: parent.verticalCenter
                }

                HoverHandler { id: seekHover }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function(mouse) {
                    var ratio = Math.max(0, Math.min(1, mouse.x / width))
                    root.seek(ratio * root.trackLength)
                  }
                }
              }
            }

            // ---- A suivre ----
            // Absente en lecture aleatoire, en fin de file, et quand le plugin
            // next-track n'est pas installe ou pas approuve.
            Item {
              width: parent.width
              implicitHeight: nextLabel.implicitHeight
              visible: root.nextTrack !== null

              Text {
                id: nextLabel

                text: root.nextTrack
                  ? "UP NEXT · " + (root.nextTrack.artist
                      ? root.nextTrack.artist + " — " + root.nextTrack.title
                      : root.nextTrack.title)
                  : ""
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 0.6
                elide: Text.ElideRight
                width: parent.width
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
                actionEnabled: root.hasMpris ? root.player.canGoPrevious : root.available
                onActivated: root.goPrevious()
              }

              TransportButton {
                glyph: root.playing ? root.glyphPause : root.glyphPlay
                highlighted: true
                // Toujours actif : sans cliamp, ce bouton le demarre.
                actionEnabled: !root.hasMpris || root.player.canTogglePlaying
                onActivated: root.primaryAction()
              }

              TransportButton {
                glyph: root.glyphNext
                actionEnabled: root.hasMpris ? root.player.canGoNext : root.available
                onActivated: root.goNext()
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

            // Modes de lecture : le statut les connait, MPRIS non. Purement
            // indicatif — ils se changent depuis cliamp.
            Item {
              width: parent.width
              implicitHeight: modesLabel.implicitHeight
              visible: root.socketPresent && (root.playerStatus.shuffle
                || String(root.playerStatus.repeatMode).toLowerCase() !== "off"
                || root.playerStatus.total > 0)

              Text {
                id: modesLabel

                text: {
                  var parts = []
                  if (root.playerStatus.shuffle) parts.push(root.glyphShuffle + " SHUFFLE")
                  var mode = String(root.playerStatus.repeatMode)
                  if (mode.toLowerCase() !== "off") parts.push(root.glyphRepeat + " " + mode.toUpperCase())
                  if (root.playerStatus.total > 0 && root.playerStatus.index >= 0)
                    parts.push((root.playerStatus.index + 1) + " / " + root.playerStatus.total)
                  return parts.join("   ")
                }
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 0.6
                elide: Text.ElideRight
                width: parent.width
              }
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
      && String(root.streamUrl) === String(station.url)

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
        text: Model.stationSubtitle(stationRow.station)
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
