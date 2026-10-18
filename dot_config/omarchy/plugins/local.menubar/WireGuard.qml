import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "WireGuardModel.js" as Model

// Tunnels WireGuard geres par NetworkManager. La pastille passe en accent des
// qu'un tunnel est actif ; le panneau donne la main tunnel par tunnel, montre
// le trafic de la derniere minute et importe un .conf.
//
// Tout ce qui parle a NetworkManager ou touche une cle passe par
// `wireguard-backend.py` : la QML ne voit que des noms, des etats et des
// compteurs. Le calcul du debit et la detection des coupures vivent dans
// `WireGuardModel.js`, teste a part.
//
// Inspire de omarchy-wireguard (VirtualDataPro, MIT).
BarWidget {
  id: root
  moduleName: "local.menubar.wireguard"

  readonly property string backend:
    decodeURIComponent(String(Qt.resolvedUrl("wireguard-backend.py")).replace(/^file:\/\//, ""))

  readonly property int islandSize: bar && bar.islandSize !== undefined ? bar.islandSize : barSize
  readonly property int islandRadius: bar && bar.islandRadius !== undefined ? bar.islandRadius : Style.cornerRadius

  readonly property int revealDuration: bar && bar.revealDuration !== undefined ? bar.revealDuration : 180
  readonly property int revealEasing: Easing.OutCubic

  readonly property color accentColor: bar ? bar.accent : Commons.Color.accent
  readonly property real accentFillOpacity: bar && bar.accentFillOpacity !== undefined ? bar.accentFillOpacity : 0.18
  readonly property color foregroundColor: bar ? bar.foreground : Commons.Color.foreground
  readonly property color mutedColor: Qt.darker(foregroundColor, 1.4)
  readonly property color urgentColor: bar && bar.urgent !== undefined ? bar.urgent : Commons.Color.urgent
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

  // --- Releve ----------------------------------------------------------------

  // Vrai des le premier releve reussi : sans NetworkManager joignable, la
  // pastille n'a rien a offrir et se retire de la barre.
  property bool available: false
  property bool failed: false
  property var profiles: []
  // Releve precedent, pour reperer ce qui est tombe entre deux passages.
  // `null` tant qu'aucun releve n'a abouti : le premier ne notifie rien.
  property var previousProfiles: null
  // uuid -> true pour les coupures voulues : down depuis le panneau, ou
  // victimes d'une bascule de full tunnel. Vide apres chaque releve.
  property var expectedDrops: ({})
  // uuid -> dernier point de mesure, et uuid -> fenetre d'une minute.
  property var lastSamples: ({})
  property var history: ({})

  readonly property var activeNames: Model.activeNames(profiles)
  readonly property bool anyActive: activeNames.length > 0

  function refresh() {
    if (statusReader.running || worker.running) return
    statusReader.running = true
  }

  function ingest(data) {
    var list = data.profiles || []
    var time = Number(data.time || 0)

    var lost = Model.dropped(previousProfiles, list, expectedDrops)
    for (var i = 0; i < lost.length; i++) notifyDrop(lost[i].name)

    var samples = {}
    var windows = {}
    for (var j = 0; j < list.length; j++) {
      var uuid = list[j].uuid
      var point = Model.sample(lastSamples[uuid] || null, list[j], time)
      samples[uuid] = point
      windows[uuid] = Model.pushWindow(history[uuid], point)
    }

    lastSamples = samples
    history = windows
    expectedDrops = ({})
    previousProfiles = list
    profiles = list
    available = true
    failed = false

    if (!selectedProfile && list.length > 0) selected = list[0].uuid
  }

  function notifyDrop(name) {
    Quickshell.execDetached(["notify-send", "--app-name=WireGuard", "--urgency=critical", "--",
      "Tunnel WireGuard coupe", name + " n'est plus actif."])
  }

  Process {
    id: statusReader

    command: ["python3", "-I", "-B", root.backend, "status"]
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    onExited: function(exitCode) {
      var data = null
      try {
        data = JSON.parse(String(statusOutput.text || "").trim())
      } catch (e) {
        data = null
      }

      // Un releve rate n'est pas une coupure : on garde le precedent tel quel
      // pour que la comparaison reprenne au releve suivant.
      if (exitCode === 0 && data && Array.isArray(data.profiles)) root.ingest(data)
      else root.failed = true

      if (root.pendingAction) {
        var next = root.pendingAction
        root.pendingAction = null
        root.startAction(next.op, next.uuid, next.payload)
      }
    }
  }

  // Deux secondes tant qu'un tunnel tourne ou que le panneau est ouvert : c'est
  // le pas du graphe et le delai de detection d'une coupure. Dix sinon.
  Timer {
    interval: root.anyActive || root.opened ? 2000 : 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // --- Actions ---------------------------------------------------------------

  property var pendingAction: null
  property string actionError: ""
  property string actionInfo: ""
  readonly property bool busy: worker.running || pendingAction !== null

  // Le releve et les actions ne se chevauchent jamais : une action demandee
  // pendant un releve attend la fin de celui-ci.
  function run(op, uuid, payload) {
    if (busy) return
    actionError = ""
    actionInfo = ""
    if (statusReader.running) {
      pendingAction = { op: op, uuid: uuid, payload: payload }
      return
    }
    startAction(op, uuid, payload)
  }

  function startAction(op, uuid, payload) {
    if (op === "down") markExpected([uuid])

    var argv = ["python3", "-I", "-B", root.backend, op]
    if (uuid) argv.push(uuid)
    worker.payload = payload ? JSON.stringify(payload) : ""
    worker.lastOp = op
    worker.command = argv
    worker.running = true
  }

  function markExpected(uuids) {
    var next = {}
    for (var key in expectedDrops) next[key] = expectedDrops[key]
    for (var i = 0; i < uuids.length; i++) next[uuids[i]] = true
    expectedDrops = next
  }

  function toggleTunnel(profile) {
    if (!profile) return
    run(Model.isUp(profile.state) ? "down" : "up", profile.uuid)
  }

  // --- Renommer --------------------------------------------------------------

  // uuid du tunnel en cours de renommage, vide sinon. Tant qu'il est pose, la
  // frappe va au champ et non aux raccourcis du panneau.
  property string renaming: ""
  property string renameText: ""

  function startRename(profile) {
    if (!profile || busy) return
    cancelDelete()
    selected = profile.uuid
    renameText = profile.name
    renaming = profile.uuid
  }

  function commitRename() {
    var uuid = renaming
    var name = renameText.trim()
    renaming = ""
    if (uuid === "" || name === "") return
    var current = null
    for (var i = 0; i < profiles.length; i++) if (profiles[i].uuid === uuid) current = profiles[i]
    if (current && current.name === name) return
    run("rename", uuid, { name: name })
  }

  function cancelRename() {
    renaming = ""
  }

  // --- Supprimer -------------------------------------------------------------

  // Irreversible : la cle privee part avec le profil. Le premier geste arme la
  // suppression, un second dans les 4 s la confirme ; Echap ou l'attente
  // desarment.
  property string confirmingDelete: ""

  Timer {
    id: deleteDisarm

    interval: 4000
    repeat: false
    onTriggered: root.confirmingDelete = ""
  }

  function askDelete(profile) {
    if (!profile || busy) return
    cancelRename()
    selected = profile.uuid
    if (confirmingDelete === profile.uuid) {
      cancelDelete()
      run("delete", profile.uuid)
      return
    }
    confirmingDelete = profile.uuid
    deleteDisarm.restart()
  }

  function cancelDelete() {
    deleteDisarm.stop()
    confirmingDelete = ""
  }

  Process {
    id: worker

    // Le .conf choisi part sur stdin, jamais en argument : rien de ce qui
    // touche aux cles ne doit apparaitre dans la liste des processus.
    property string payload: ""
    property string lastOp: ""

    stdinEnabled: true
    stdout: StdioCollector { id: workerOutput; waitForEnd: true }
    onStarted: {
      if (payload !== "") write(payload + "\n")
      payload = ""
    }
    onExited: function(exitCode) {
      var data = null
      try {
        data = JSON.parse(String(workerOutput.text || "").trim())
      } catch (e) {
        data = null
      }

      // Les tunnels coupes par la bascule le sont volontairement, que
      // l'activation qui suit ait reussi ou non.
      if (data && Array.isArray(data.stopped)) root.markExpected(data.stopped)

      if (exitCode !== 0) {
        root.actionError = data && data.error ? String(data.error) : "Action impossible"
      } else if (data && data.uuid) {
        root.selected = data.uuid
        root.actionInfo = "Tunnel importe, desactive"
      } else if (lastOp === "rename") {
        root.actionInfo = "Tunnel renomme"
      } else if (lastOp === "delete") {
        root.actionInfo = "Tunnel supprime"
      }

      // Au tour suivant de la boucle : dans ce gestionnaire, le processus peut
      // encore se dire en cours et `refresh()` ne ferait rien.
      Qt.callLater(root.refresh)
    }
  }

  // --- Import ----------------------------------------------------------------

  // Le selecteur tourne dans son propre processus. Le FileDialog de
  // QtQuick.Dialogs ouvrait, via le theme de plateforme gtk3, un dialogue GTK
  // natif dans le processus du shell, et le faisait avorter dans GLib. Ici un
  // selecteur qui plante n'emporte que lui.
  Process {
    id: picker

    command: ["zenity", "--file-selection", "--title=Importer un tunnel WireGuard",
      "--file-filter=Configuration WireGuard (*.conf) | *.conf", "--file-filter=Tous les fichiers | *"]
    stdout: StdioCollector { id: pickerOutput; waitForEnd: true }
    onExited: function(exitCode) {
      // zenity rend 1 sur Annuler : rien a importer, ce n'est pas une erreur.
      var path = String(pickerOutput.text || "").replace(/\n$/, "")
      root.open()
      if (exitCode !== 0 || path === "") return

      var file = path.substring(path.lastIndexOf("/") + 1)
      root.run("add", "", { path: path, name: file.replace(/\.conf$/i, "") })
    }
  }

  function importTunnel() {
    if (busy || picker.running) return
    picker.running = true
  }

  // --- Ouverture -------------------------------------------------------------

  property bool opened: false
  // Le tunnel montre dans le graphe. L'uuid, pas l'index : la liste se
  // retrie a chaque releve.
  property string selected: ""

  readonly property var selectedProfile: {
    for (var i = 0; i < profiles.length; i++) if (profiles[i].uuid === selected) return profiles[i]
    return null
  }
  readonly property var selectedHistory: selectedProfile ? (history[selectedProfile.uuid] || []) : []
  readonly property var selectedPoint: selectedHistory.length > 0 ? selectedHistory[selectedHistory.length - 1] : null

  function open() {
    opened = true
    refresh()
  }

  function close() {
    opened = false
    actionInfo = ""
    cancelRename()
    cancelDelete()
  }

  function toggle() {
    opened ? close() : open()
  }

  function closeForPopoutSwitch() {
    close()
  }

  function moveSelection(step) {
    if (profiles.length === 0) return

    var index = 0
    for (var i = 0; i < profiles.length; i++) if (profiles[i].uuid === selected) index = i

    var next = index + (step > 0 ? 1 : -1)
    if (next < 0) next = profiles.length - 1
    if (next >= profiles.length) next = 0
    selected = profiles[next].uuid
  }

  readonly property bool primaryInstance: {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screens = Quickshell.screens
    return !!window && screens.length > 0 && window.screen === screens[0]
  }

  IpcHandler {
    enabled: root.primaryInstance
    target: "menubar.wireguard"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
  }

  // --- Bouton de barre -------------------------------------------------------

  // nf-md-shield_lock, en echappement : hors du plan de base, le caractere ne
  // survit pas toujours a un copier-coller.
  readonly property string glyph: "󰒃"

  readonly property int glyphWidth: Style.space(15)
  readonly property int contentGap: Style.space(5)
  readonly property bool detailRevealed: widgetHover.hovered || opened

  readonly property string detailText: {
    if (failed) return "injoignable"
    if (activeNames.length === 1) return "actif"
    if (activeNames.length > 1) return activeNames.length + " actifs"
    return "inactif"
  }

  property int detailExtent: detailRevealed ? detailLabel.implicitWidth + contentGap : 0

  Behavior on detailExtent {
    NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
  }

  visible: available

  implicitWidth: contentGap + glyphWidth + detailExtent + contentGap
  implicitHeight: islandSize

  HoverHandler {
    id: widgetHover

    onHoveredChanged: {
      if (!root.bar || root.opened) return
      if (hovered) root.bar.showTooltip(root, root.summary())
      else root.bar.hideTooltip(root)
    }
  }

  function summary() {
    if (failed) return "NetworkManager injoignable"
    if (profiles.length === 0) return "Aucun tunnel WireGuard"
    if (!anyActive) return "Aucun tunnel actif"
    return "Actif : " + activeNames.join(", ")
  }

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -root.haloInsetX
    anchors.rightMargin: -root.haloInsetX
    anchors.topMargin: -root.haloInsetY
    anchors.bottomMargin: -root.haloInsetY
    radius: root.islandRadius
    color: root.failed ? root.urgentColor : root.accentColor
    opacity: (root.anyActive || root.detailRevealed || root.failed) ? root.accentFillOpacity : 0

    Behavior on opacity {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }
  }

  Text {
    x: root.contentGap
    width: root.glyphWidth
    text: root.glyph
    color: root.failed ? root.urgentColor : (root.anyActive ? root.accentColor : root.mutedColor)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    anchors.verticalCenter: parent.verticalCenter

    Behavior on color {
      ColorAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }
  }

  Item {
    x: root.contentGap + root.glyphWidth
    width: root.detailExtent
    height: parent.height
    clip: true

    Text {
      id: detailLabel

      x: root.contentGap
      text: root.detailText
      color: root.foregroundColor
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
      if (mouse.button === Qt.RightButton) root.refresh()
      else root.toggle()
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
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      // Le champ de renommage garde la frappe pour lui.
      blocked: root.renaming !== ""
      onCloseRequested: {
        if (root.confirmingDelete !== "") root.cancelDelete()
        else root.close()
      }
      onMoveRequested: function(dx, dy) {
        if (dy === 0) return
        root.cancelDelete()
        root.moveSelection(dy)
      }
      onActivateRequested: root.toggleTunnel(root.selectedProfile)
      onDeleteRequested: root.askDelete(root.selectedProfile)
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
        else if (text === "i" || text === "I") root.importTunnel()
        else if (text === "n" || text === "N") root.startRename(root.selectedProfile)
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

          // ---- En-tete ----
          PanelIsland {

            Item {
              width: parent.width
              implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

              Text {
                id: heroIcon

                text: root.glyph
                color: root.anyActive ? root.accentColor : root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                id: heroLabels

                anchors.left: heroIcon.right
                anchors.leftMargin: Style.space(16)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(2)

                Text {
                  text: {
                    var count = root.activeNames.length
                    if (count === 0) return "Aucun tunnel actif"
                    return count + " tunnel" + (count > 1 ? "s actifs" : " actif")
                  }
                  color: root.foregroundColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: {
                    if (root.actionError !== "") return root.actionError
                    if (root.failed) return "NETWORKMANAGER INJOIGNABLE"
                    if (root.busy) return "EN COURS..."
                    if (root.actionInfo !== "") return root.actionInfo.toUpperCase()
                    return root.anyActive ? root.activeNames.join(", ").toUpperCase() : "WIREGUARD"
                  }
                  textFormat: Text.PlainText
                  color: root.actionError !== "" || root.failed ? root.urgentColor : root.mutedColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1.2
                  wrapMode: root.actionError !== "" ? Text.WordWrap : Text.NoWrap
                  elide: root.actionError !== "" ? Text.ElideNone : Text.ElideRight
                  width: parent.width
                }
              }
            }
          }

          // ---- Tunnels ----
          PanelIsland {

            SectionHeader {
              text: "TUNNELS"
              value: root.profiles.length > 0 ? String(root.profiles.length) : ""
            }

            Text {
              width: parent.width
              visible: root.profiles.length === 0
              text: "Aucun tunnel WireGuard dans NetworkManager"
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Repeater {
              model: root.profiles

              TunnelRow {
                required property var modelData

                width: parent.width
                profile: modelData
              }
            }
          }

          // ---- Trafic du tunnel vise ----
          PanelIsland {
            visible: !!root.selectedProfile

            SectionHeader {
              text: "TRAFIC"
              value: root.selectedPoint && root.selectedProfile && Model.isUp(root.selectedProfile.state)
                ? "↓ " + Model.formatRate(root.selectedPoint.down) + "   ↑ " + Model.formatRate(root.selectedPoint.up)
                : ""
            }

            TrafficGraph {
              width: parent.width
              height: Style.space(72)
              points: root.selectedHistory
              live: !!root.selectedProfile && Model.isUp(root.selectedProfile.state)
            }
          }

          // ---- Import ----
          PanelIsland {

            CursorSurface {
              width: parent.width
              height: Style.space(30)
              hasCursor: importHover.hovered
              foreground: root.foregroundColor
              accent: root.accentColor
              opacity: root.busy ? 0.5 : 1

              HoverHandler { id: importHover }

              MouseArea {
                anchors.fill: parent
                cursorShape: root.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: root.importTunnel()
              }

              Text {
                text: "Importer un .conf..."
                color: root.accentColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                text: "I"
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
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
      elide: Text.ElideRight
      width: Math.min(implicitWidth, parent.width * 0.65)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Un tunnel : son nom, son etat, son interrupteur. Cliquer la ligne la vise
  // pour le graphe ; l'interrupteur, lui, active ou coupe.
  component TunnelRow: Item {
    id: tunnelRow

    required property var profile

    readonly property bool isSelected: root.selected === profile.uuid
    readonly property bool up: Model.isUp(profile.state)
    readonly property bool renaming: root.renaming === profile.uuid
    readonly property bool confirming: root.confirmingDelete === profile.uuid

    // Suit son contenu : le champ de renommage est plus haut que les deux
    // lignes de texte qu'il remplace, et deborderait sur la ligne voisine.
    implicitHeight: Math.max(Style.space(34), rowInfo.implicitHeight + Style.space(8))

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.selected = tunnelRow.profile.uuid
    }

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: -Style.space(4)
      anchors.rightMargin: -Style.space(4)
      radius: Style.cornerRadius
      color: root.accentColor
      opacity: tunnelRow.isSelected ? root.accentFillOpacity * 0.7 : 0

      Behavior on opacity {
        NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
      }
    }

    Column {
      id: rowInfo

      anchors.left: parent.left
      anchors.leftMargin: Style.space(4)
      anchors.right: rowTools.visible ? rowTools.left : rowSwitch.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(1)

      // Le nom vient du .conf ou de NetworkManager : texte brut, jamais
      // interprete comme du balisage.
      Text {
        width: parent.width
        visible: !tunnelRow.renaming
        text: tunnelRow.profile.name
        textFormat: Text.PlainText
        color: tunnelRow.up ? root.foregroundColor : root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }

      TextField {
        width: parent.width
        visible: tunnelRow.renaming
        text: root.renameText
        foreground: root.foregroundColor
        accent: root.accentColor
        onTextChanged: root.renameText = text
        Keys.onReturnPressed: root.commitRename()
        Keys.onEnterPressed: root.commitRename()
        Keys.onEscapePressed: root.cancelRename()

        // Le champ prend le focus des qu'il apparait, sinon la frappe part
        // dans le gestionnaire de touches du panneau.
        onVisibleChanged: if (visible) forceActiveFocus()
      }

      Text {
        width: parent.width
        visible: !tunnelRow.renaming
        text: {
          var state = tunnelRow.profile.state
          if (state === "activated") return tunnelRow.profile.device !== "" ? "actif - " + tunnelRow.profile.device : "actif"
          if (state === "activating") return "connexion..."
          if (state === "deactivating") return "deconnexion..."
          return "inactif"
        }
        textFormat: Text.PlainText
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    // Renommer et supprimer n'apparaissent que sur la ligne visee : la liste
    // reste lisible, et le geste destructeur ne tombe jamais sous un clic de
    // passage.
    Row {
      id: rowTools

      anchors.right: rowSwitch.left
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      // Assez d'air pour que la zone de clic elargie d'une icone ne morde pas
      // sur sa voisine : la corbeille ne doit jamais se prendre pour l'autre.
      spacing: Style.space(12)
      visible: tunnelRow.isSelected && !tunnelRow.renaming

      RowTool {
        visible: !tunnelRow.confirming
        glyph: "󰏫"
        hint: "Renommer (N)"
        onActivated: root.startRename(tunnelRow.profile)
      }

      RowTool {
        visible: !tunnelRow.confirming
        glyph: "󰩺"
        hint: "Supprimer (Suppr)"
        onActivated: root.askDelete(tunnelRow.profile)
      }

      // Armee par le premier clic sur la corbeille : le second, ici, supprime.
      Rectangle {
        visible: tunnelRow.confirming
        width: confirmLabel.implicitWidth + Style.space(12)
        height: Style.space(22)
        radius: Style.cornerRadius
        color: Qt.rgba(root.urgentColor.r, root.urgentColor.g, root.urgentColor.b, 0.22)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          id: confirmLabel

          anchors.centerIn: parent
          text: "Supprimer ?"
          color: root.urgentColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.askDelete(tunnelRow.profile)
        }
      }
    }

    ToggleSwitch {
      id: rowSwitch

      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      checked: tunnelRow.up
      busy: root.busy
      hasCursor: tunnelRow.isSelected && root.opened
      foreground: root.foregroundColor
      accent: root.accentColor
      onToggled: root.toggleTunnel(tunnelRow.profile)
    }
  }

  // Petit bouton glyphe d'une ligne de tunnel, avec son infobulle.
  component RowTool: Text {
    id: rowTool

    property string glyph: ""
    property string hint: ""

    signal activated()

    text: glyph
    color: toolHover.hovered ? root.accentColor : root.mutedColor
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    opacity: root.busy ? 0.4 : 1

    HoverHandler {
      id: toolHover

      onHoveredChanged: {
        if (!root.bar) return
        if (hovered) root.bar.showTooltip(rowTool, rowTool.hint)
        else root.bar.hideTooltip(rowTool)
      }
    }

    MouseArea {
      anchors.fill: parent
      anchors.margins: -Style.space(4)
      cursorShape: Qt.PointingHandCursor
      onClicked: rowTool.activated()
    }
  }

  // Debit descendant en accent, montant en sourdine, sur une fenetre fixe de
  // 30 points : la courbe pousse depuis la droite et la minute reste lisible
  // meme quand le releve vient de commencer.
  component TrafficGraph: Item {
    id: graph

    property var points: []
    property bool live: false

    onPointsChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()

    Canvas {
      id: canvas

      anchors.fill: parent
      visible: graph.live

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()

        var values = graph.points || []
        var slots = Model.WINDOW_SIZE
        var peak = 1024
        for (var i = 0; i < values.length; i++) peak = Math.max(peak, values[i].down, values[i].up)

        ctx.strokeStyle = root.mutedColor
        ctx.globalAlpha = 0.25
        ctx.lineWidth = 1
        for (var g = 1; g <= 3; g++) {
          var y = Math.round(height * g / 4) + 0.5
          ctx.beginPath()
          ctx.moveTo(0, y)
          ctx.lineTo(width, y)
          ctx.stroke()
        }
        ctx.globalAlpha = 1

        if (values.length < 2) return

        function trace(key, color) {
          ctx.strokeStyle = color
          ctx.lineWidth = 2
          ctx.lineJoin = "round"
          ctx.beginPath()
          for (var k = 0; k < values.length; k++) {
            var x = width * (slots - values.length + k) / (slots - 1)
            var level = height - 1 - (height - 2) * values[k][key] / peak
            if (k === 0) ctx.moveTo(x, level)
            else ctx.lineTo(x, level)
          }
          ctx.stroke()
        }

        trace("up", root.mutedColor)
        trace("down", root.accentColor)
      }
    }

    Text {
      anchors.centerIn: parent
      visible: !graph.live
      text: "Active le tunnel pour voir son trafic"
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
