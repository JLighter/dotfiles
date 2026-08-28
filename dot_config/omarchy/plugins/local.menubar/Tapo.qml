import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Ampoules TP-Link Tapo, pilotees en local (protocole KLAP, sans cloud).
// La pastille s'allume en accent des qu'une lampe est allumee ; le detail
// (combien sur combien, et a quel niveau) se deplie au survol, et le panneau
// donne la main lampe par lampe : allumage, intensite, teinte, blanc.
//
// Le releve vient de `tapo-ctl devices`, un binaire pose dans ~/.local/bin qui
// interroge les ampoules en parallele et rend un JSON par lampe. C'est la seule
// source du widget : l'etat agrege de la pastille en est derive, pour qu'il n'y
// ait jamais deux verites a reconcilier.
BarWidget {
  id: root
  moduleName: "local.menubar.tapo"

  // Resolu au demarrage plutot qu'ecrit en dur : le widget doit suivre le
  // dossier personnel de la machine, dont le nom change d'un poste a l'autre.
  readonly property string binary: Quickshell.env("HOME") + "/.local/bin/tapo-ctl"

  readonly property int islandSize: bar && bar.islandSize !== undefined ? bar.islandSize : barSize
  readonly property int islandRadius: bar && bar.islandRadius !== undefined ? bar.islandRadius : Style.cornerRadius

  readonly property int revealDuration: bar && bar.revealDuration !== undefined ? bar.revealDuration : 180
  readonly property int revealEasing: Easing.OutCubic

  readonly property color accentColor: bar ? bar.accent : Color.accent
  readonly property real accentFillOpacity: bar && bar.accentFillOpacity !== undefined ? bar.accentFillOpacity : 0.18
  readonly property color foregroundColor: bar ? bar.foreground : Color.foreground
  readonly property color mutedColor: Qt.darker(foregroundColor, 1.4)
  readonly property color urgentColor: bar && bar.urgent !== undefined ? bar.urgent : Color.urgent
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

  // --- Presence de tapo-ctl --------------------------------------------------
  // Bar.qml instancie ce widget en dur : le fichier est donc toujours la, meme
  // sur une machine sans domotique. C'est la presence du binaire qui decide si
  // la pastille occupe la barre, sinon un poste sans lampes afficherait un
  // "injoignable" rouge en permanence.

  property bool installed: false

  Process {
    running: true
    command: ["test", "-x", root.binary]
    onExited: function(exitCode) { root.installed = exitCode === 0 }
  }

  // La sonde repond apres le premier tour de timer : sans ce rattrapage, le
  // widget resterait vide une quinzaine de secondes au demarrage de la barre.
  onInstalledChanged: {
    if (!installed) return
    loadPalette()
    refresh()
  }

  // --- Releve ----------------------------------------------------------------

  property var lamps: []
  property bool failed: false
  property string failure: ""

  readonly property int totalCount: lamps.length
  readonly property int litCount: {
    var total = 0
    for (var i = 0; i < lamps.length; i++) if (lamps[i].on) total++
    return total
  }
  readonly property bool anyLit: litCount > 0
  // Tout allume ou tout eteint se lit d'un coup d'oeil ; l'etat mixte ne se
  // distingue que par le compte, sinon eteindre une lampe sur trois ne
  // changerait rien a la barre et le clic semblerait perdu.
  readonly property bool mixed: litCount > 0 && litCount < totalCount

  // Moyenne sur les seules lampes allumees : "a quel niveau eclaire ce qui
  // eclaire". Inclure les eteintes tirerait la valeur vers zero et rendrait
  // la molette illisible.
  readonly property int level: {
    var sum = 0
    var count = 0
    for (var i = 0; i < lamps.length; i++) {
      if (lamps[i].on && lamps[i].brightness !== null) {
        sum += lamps[i].brightness
        count++
      }
    }
    return count > 0 ? Math.round(sum / count) : 0
  }

  function applyState(raw) {
    var payload = String(raw || "").trim()
    if (payload === "") return

    try {
      var data = JSON.parse(payload)
      var list = data.devices || []
      var reachable = []
      var unreachable = []

      for (var i = 0; i < list.length; i++) {
        if (list[i].online) reachable.push(list[i])
        else unreachable.push(list[i].name)
      }

      lamps = reachable
      failed = reachable.length === 0
      failure = data.error
        ? String(data.error)
        : (unreachable.length > 0 ? unreachable.join(", ") + " injoignable(s)" : "")
    } catch (e) {
      failed = true
      failure = "Sortie illisible de tapo-ctl"
    }
  }

  // --- Palette du theme -------------------------------------------------------

  // Roles de couleur du theme Omarchy actif. Une lampe ne memorise pas une
  // teinte mais un ROLE ("blue") : c'est le bleu qui change avec le theme,
  // la lampe reste elle-meme d'un theme a l'autre.
  property var palette: ({})
  property var roles: []
  property var assigned: ({})
  property string themeName: ""

  Process {
    id: paletteReader

    command: [root.binary, "palette"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(String(text || "").trim())
          root.palette = data.colors || ({})
          root.roles = data.roles || []
          root.assigned = data.assigned || ({})
          root.themeName = data.theme || ""
        } catch (e) {
          root.roles = []
        }
      }
    }
  }

  function loadPalette() {
    if (!installed) return
    if (!paletteReader.running) paletteReader.running = true
  }

  Component.onCompleted: loadPalette()

  // Le singleton Color est reassigne a chaque changement de theme. S'y lier
  // vaut abonnement : pas de surveillance de fichier ni de sondage a ecrire,
  // et la pastille se repeint en meme temps que le reste du shell.
  readonly property color themeWitness: Color.accent

  onThemeWitnessChanged: {
    loadPalette()
    // Le hook theme-set applique deja la couleur aux lampes ; on relit apres
    // lui pour que le panneau montre l'etat reel et non celui d'avant.
    themeSettle.restart()
  }

  Timer {
    id: themeSettle

    interval: 2500
    repeat: false
    onTriggered: root.refresh()
  }

  Process {
    id: reader

    command: [root.binary, "devices"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyState(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.failed = true
        root.failure = "tapo-ctl a echoue (code " + exitCode + ")"
      }
    }
  }

  // Garde unique pour tous les declencheurs (timer, changement de theme,
  // confirmation d'action) : sans binaire, aucun `tapo-ctl` n'est forke.
  function refresh() {
    if (!installed) return
    if (reader.running) return
    reader.running = true
  }

  // Quinze secondes barre fermee : les lampes ne changent d'etat que sur
  // action, et chaque releve ouvre une session KLAP par ampoule. Panneau
  // ouvert on resserre, l'utilisateur y regarde les valeurs bouger.
  Timer {
    interval: root.opened ? 4000 : 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Les ampoules mettent un instant a confirmer : relire dans la foulee
  // renverrait encore l'ancien etat.
  Timer {
    id: settle

    interval: 600
    repeat: false
    onTriggered: root.refresh()
  }

  // --- Actions ---------------------------------------------------------------

  Process {
    id: worker

    command: [root.binary, "status"]
    onExited: settle.restart()
  }

  function runAction(verb, argument, target) {
    if (worker.running) return

    var argv = [root.binary, verb]
    if (argument !== undefined && argument !== null) argv.push(String(argument))
    if (target !== undefined && target !== null) argv.push(String(target))

    worker.command = argv
    worker.running = true
  }

  // Un bouton unique doit donner un resultat previsible : si quoi que ce soit
  // est allume, tout eteindre, sinon tout allumer. Un `toggle` lampe par lampe
  // conserverait l'etat mixte et donnerait l'impression d'un clic sans effet.
  function toggleGroup() {
    runAction(anyLit ? "off" : "on", "all")
  }

  function toggleLamp(name) {
    runAction("toggle", name)
  }

  function setBrightness(name, percent) {
    runAction("bri", Math.round(percent), name)
  }

  // Assigner un role plutot qu'une teinte : tapo-ctl ecrit le choix dans sa
  // config et applique la couleur du theme courant dans la foulee. La lampe
  // suivra les themes suivants sans qu'on ait a y revenir.
  function setRole(name, role) {
    if (worker.running) return

    worker.command = [root.binary, "role", String(name), String(role)]
    worker.running = true
    // Optimiste : la pastille se marque active tout de suite, le prochain
    // releve confirmera. Attendre l'aller-retour ferait clignoter le panneau.
    var next = {}
    for (var key in root.assigned) next[key] = root.assigned[key]
    next[name] = role === "none" ? null : role
    root.assigned = next
  }

  function setTemperature(name, kelvin) {
    runAction("temp", Math.round(kelvin), name)
  }

  // La molette emet bien plus vite qu'une lampe ne repond (~300 ms de handshake
  // chacune). On accumule les crans et on n'envoie qu'un seul palier.
  property int pendingSteps: 0

  Timer {
    id: scrollDebounce

    interval: 200
    repeat: false
    onTriggered: {
      if (root.pendingSteps === 0) return

      var amount = root.pendingSteps
      root.pendingSteps = 0
      root.runAction("bri", (amount > 0 ? "+" : "") + amount, "all")
    }
  }

  function nudge(delta) {
    pendingSteps += (delta > 0 ? 10 : -10)
    scrollDebounce.restart()
  }

  // --- Ouverture -------------------------------------------------------------

  property bool opened: false
  // Lampe visee par les reglages de couleur. Le nom, pas l'index : le releve
  // se reordonne a chaque lecture et un index designerait une autre lampe.
  property string selected: ""

  readonly property var selectedLamp: {
    for (var i = 0; i < lamps.length; i++) if (lamps[i].name === selected) return lamps[i]
    return lamps.length > 0 ? lamps[0] : null
  }

  function open() {
    opened = true
    if (selected === "" && lamps.length > 0) selected = lamps[0].name
    refresh()
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

  function moveSelection(step) {
    if (lamps.length === 0) return

    var index = 0
    for (var i = 0; i < lamps.length; i++) if (lamps[i].name === selected) index = i

    var next = index + (step > 0 ? 1 : -1)
    if (next < 0) next = lamps.length - 1
    if (next >= lamps.length) next = 0
    selected = lamps[next].name
  }

  function nudgeSelected(step) {
    var lamp = selectedLamp
    if (!lamp) return

    var current = lamp.on && lamp.brightness !== null ? lamp.brightness : 0
    setBrightness(lamp.name, Math.max(1, Math.min(100, current + step * 5)))
  }

  readonly property bool primaryInstance: {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screens = Quickshell.screens
    return !!window && screens.length > 0 && window.screen === screens[0]
  }

  IpcHandler {
    enabled: root.primaryInstance
    target: "menubar.tapo"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
  }

  // --- Bouton de barre -------------------------------------------------------

  // Ecrit en echappement plutot qu'en caractere : ce glyphe vit dans la zone
  // privee Unicode et ne survit pas toujours a un copier-coller.
  readonly property string glyph: "\uF0EB"

  // Largeur impaire : l'ilot l'est alors aussi, son centre tombe sur un pixel
  // entier et le glyphe s'y aligne sans demi-pixel d'ecart.
  readonly property int glyphWidth: Style.space(15)
  readonly property int contentGap: Style.space(5)
  readonly property bool detailRevealed: widgetHover.hovered || opened

  // Au survol on montre le compte quand l'etat est mixte, le niveau sinon :
  // c'est l'information manquante dans chacun des deux cas.
  readonly property string detailText: {
    if (failed) return "injoignable"
    if (mixed) return litCount + "/" + totalCount
    if (anyLit) return level + "%"
    return "eteint"
  }

  property int detailExtent: detailRevealed ? detailLabel.implicitWidth + contentGap : 0

  Behavior on detailExtent {
    NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
  }

  // Sans binaire le widget se retire entierement de la barre : Bar.qml ignore
  // les enfants invisibles, y compris pour l'espacement, donc l'ilot se referme
  // proprement au lieu de laisser un trou.
  visible: installed

  implicitWidth: contentGap + glyphWidth + detailExtent + contentGap
  implicitHeight: islandSize

  HoverHandler {
    id: widgetHover

    // Le detail deplie donne l'etat en un mot ; l'infobulle nomme les lampes,
    // ce que la pastille ne peut pas montrer.
    onHoveredChanged: {
      if (!root.bar || root.opened) return
      if (hovered) root.bar.showTooltip(root, root.summary())
      else root.bar.hideTooltip(root)
    }
  }

  function summary() {
    if (failed) return failure !== "" ? failure : "Lampes injoignables"

    var lines = []
    for (var i = 0; i < lamps.length; i++) {
      var lamp = lamps[i]
      var line = lamp.alias + " : " + (lamp.on ? "allumee" : "eteinte")
      if (lamp.on && lamp.brightness !== null) line += " - " + lamp.brightness + "%"
      lines.push(line)
    }
    if (failure !== "") lines.push(failure)
    return lines.join("\n")
  }

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -root.haloInsetX
    anchors.rightMargin: -root.haloInsetX
    anchors.topMargin: -root.haloInsetY
    anchors.bottomMargin: -root.haloInsetY
    radius: root.islandRadius
    color: root.failed ? root.urgentColor : root.accentColor
    opacity: (root.anyLit || root.detailRevealed || root.failed) ? root.accentFillOpacity : 0

    Behavior on opacity {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }
  }

  Text {
    id: glyphLabel

    x: root.contentGap
    width: root.glyphWidth
    text: root.glyph
    // En accent quand ca eclaire, en sourdine sinon : la couleur porte l'etat,
    // le glyphe reste le meme pour que la pastille ne saute pas en largeur.
    color: root.failed ? root.urgentColor : (root.anyLit ? root.accentColor : root.mutedColor)
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
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: function(mouse) {
      // Le clic gauche ouvre le detail, le milieu bascule tout sans ouvrir :
      // le geste rapide reste disponible une fois le panneau connu.
      if (mouse.button === Qt.MiddleButton) root.toggleGroup()
      else if (mouse.button === Qt.RightButton) root.refresh()
      else root.toggle()
    }
    onWheel: function(wheel) {
      root.nudge(wheel.angleDelta.y)
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
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveSelection(dy)
        else if (dx !== 0) root.nudgeSelected(dx)
      }
      onActivateRequested: {
        var lamp = root.selectedLamp
        if (lamp) root.toggleLamp(lamp.name)
      }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
        else if (text === "a" || text === "A") root.toggleGroup()
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
                color: root.anyLit ? root.accentColor : root.mutedColor
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
                  text: root.litCount + " / " + root.totalCount + " allumee" + (root.litCount > 1 ? "s" : "")
                  color: root.foregroundColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: root.failed && root.failure !== "" ? root.failure : (root.anyLit ? root.level + "% EN MOYENNE" : "TOUT ETEINT")
                  color: root.failed ? root.urgentColor : root.mutedColor
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

          // ---- Bascule groupee ----
          PanelIsland {

            CursorSurface {
              width: parent.width
              height: Style.space(30)
              hasCursor: groupHover.hovered
              foreground: root.foregroundColor
              accent: root.accentColor

              HoverHandler { id: groupHover }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleGroup()
              }

              Text {
                text: root.anyLit ? "Tout eteindre" : "Tout allumer"
                color: root.accentColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          // ---- Lampe par lampe ----
          PanelIsland {

            SectionHeader { text: "LAMPES" }

            Repeater {
              model: root.lamps

              LampRow {
                required property var modelData

                width: parent.width
                lamp: modelData
              }
            }
          }

          // ---- Couleur de la lampe visee ----
          PanelIsland {
            visible: !!root.selectedLamp && (root.selectedLamp.can_color || root.selectedLamp.can_temp)

            SectionHeader {
              text: "COULEUR"
              value: root.themeName !== "" ? root.themeName.toUpperCase() : ""
            }

            // Les pastilles sont les roles du theme, pas des teintes fixes :
            // cliquer assigne un role a la lampe visee, et ce role la suivra
            // dans tous les themes a venir.
            Row {
              width: parent.width
              spacing: Style.space(6)
              visible: !!root.selectedLamp && root.selectedLamp.can_color && root.roles.length > 0

              Repeater {
                model: root.roles

                RoleSwatch {
                  required property var modelData

                  role: modelData
                  size: (parent.width - Style.space(6) * (root.roles.length - 1)) / Math.max(1, root.roles.length)
                }
              }
            }

            Text {
              width: parent.width
              visible: !!root.selectedLamp && root.selectedLamp.can_color
              text: {
                var lamp = root.selectedLamp
                if (!lamp) return ""
                var role = root.assigned[lamp.name]
                if (!role) return "Ne suit pas le theme - cliquer une pastille pour l'y relier"
                return "Suit " + role + " du theme " + root.themeName
              }
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            SectionHeader {
              text: "BLANC"
              value: {
                if (!root.selectedLamp || !root.selectedLamp.can_temp) return ""
                if (tempSlider.dragging) return Math.round(tempSlider.liveValue) + "K"
                return root.selectedLamp.color_temp > 0 ? root.selectedLamp.color_temp + "K" : "MODE COULEUR"
              }
            }

            CursorSurface {
              width: parent.width
              height: tempSlider.implicitHeight
              visible: !!root.selectedLamp && root.selectedLamp.can_temp
              hasCursor: tempHover.hovered
              foreground: root.foregroundColor
              accent: root.accentColor
              outline: true

              HoverHandler { id: tempHover }

              PanelSlider {
                id: tempSlider

                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                // Les bornes viennent de la lampe : elles different d'un modele
                // a l'autre et une valeur hors plage est rejetee sechement.
                minimum: root.selectedLamp && root.selectedLamp.temp_min ? root.selectedLamp.temp_min : 2500
                maximum: root.selectedLamp && root.selectedLamp.temp_max ? root.selectedLamp.temp_max : 6500
                integer: true
                fillColor: root.accentColor
                knobColor: root.accentColor
                value: {
                  if (!root.selectedLamp) return 2700
                  // En mode couleur la lampe rend 0 : on retombe sur un blanc
                  // chaud plutot que de coller le curseur a la borne basse.
                  return root.selectedLamp.color_temp > 0 ? root.selectedLamp.color_temp : 2700
                }
                onReleased: function(value) {
                  if (root.selectedLamp) root.setTemperature(root.selectedLamp.name, value)
                }
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
      width: Math.min(implicitWidth, parent.width * 0.55)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Une lampe : son glyphe d'etat, son nom, puis son intensite. Cliquer la
  // ligne la vise pour la section couleur ; cliquer le glyphe la bascule.
  component LampRow: Item {
    id: lampRow

    required property var lamp

    readonly property bool isSelected: root.selected === lamp.name

    implicitHeight: Style.space(34)

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.selected = lampRow.lamp.name
    }

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin: -Style.space(4)
      anchors.rightMargin: -Style.space(4)
      radius: Style.cornerRadius
      color: root.accentColor
      opacity: lampRow.isSelected ? root.accentFillOpacity * 0.7 : 0

      Behavior on opacity {
        NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
      }
    }

    Text {
      id: rowGlyph

      text: root.glyph
      color: lampRow.lamp.on ? root.accentColor : root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      anchors.left: parent.left
      anchors.leftMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter

      Behavior on color {
        ColorAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
      }

      MouseArea {
        anchors.fill: parent
        anchors.margins: -Style.space(6)
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleLamp(lampRow.lamp.name)
      }
    }

    Text {
      id: rowName

      text: lampRow.lamp.alias
      color: lampRow.lamp.on ? root.foregroundColor : root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      width: Math.min(implicitWidth, parent.width * 0.42)
      anchors.left: rowGlyph.right
      anchors.leftMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
    }

    PanelSlider {
      id: rowSlider

      bar: root.bar
      anchors.left: rowName.right
      anchors.leftMargin: Style.space(10)
      anchors.right: rowValue.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      minimum: 1
      maximum: 100
      integer: true
      fillColor: root.accentColor
      knobColor: root.accentColor
      opacity: lampRow.lamp.on ? 1 : 0.45
      value: lampRow.lamp.brightness !== null ? lampRow.lamp.brightness : 1
      // Sur `released` et non `moved` : chaque envoi coute un handshake KLAP,
      // suivre le glissement noierait la lampe sous les requetes.
      onReleased: function(value) { root.setBrightness(lampRow.lamp.name, value) }
    }

    Text {
      id: rowValue

      text: {
        if (rowSlider.dragging) return Math.round(rowSlider.liveValue) + "%"
        if (!lampRow.lamp.on) return "off"
        return (lampRow.lamp.brightness !== null ? lampRow.lamp.brightness : 0) + "%"
      }
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignRight
      width: Style.space(34)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Pastille de role. Elle se peint avec la couleur que le theme donne a ce
  // role : changer de theme repeint les pastilles en meme temps que la barre,
  // sans qu'aucune valeur ne soit codee ici.
  component RoleSwatch: Rectangle {
    id: roleSwatch

    required property string role
    property int size: Style.space(26)

    readonly property color roleColor: {
      var hex = root.palette[role]
      return hex ? hex : root.mutedColor
    }

    // L'etat actif se lit dans le role assigne, pas dans la teinte rapportee
    // par la lampe : le materiel arrondit ce qu'on lui envoie, et deux roles
    // d'un meme theme peuvent tomber a quelques degres l'un de l'autre.
    readonly property bool isCurrent: {
      var lamp = root.selectedLamp
      return !!lamp && root.assigned[lamp.name] === role
    }

    width: size
    height: size
    radius: size / 2
    color: roleColor
    border.width: isCurrent ? 2 : 0
    border.color: root.foregroundColor
    opacity: swatchHover.hovered || isCurrent ? 1 : 0.7
    scale: swatchHover.hovered ? 1.12 : 1

    Behavior on opacity {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }
    Behavior on scale {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }
    Behavior on color {
      ColorAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }

    HoverHandler {
      id: swatchHover

      onHoveredChanged: {
        if (!root.bar) return
        if (hovered) root.bar.showTooltip(roleSwatch, roleSwatch.role + " - " + root.palette[roleSwatch.role])
        else root.bar.hideTooltip(roleSwatch)
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        var lamp = root.selectedLamp
        if (!lamp) return
        // Recliquer le role actif le retire : la lampe cesse de suivre le
        // theme sans qu'il faille un bouton "detacher" en plus.
        root.setRole(lamp.name, roleSwatch.isCurrent ? "none" : roleSwatch.role)
      }
    }
  }
}
