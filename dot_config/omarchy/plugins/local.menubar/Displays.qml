import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Widget d'ecrans autonome : glyphe dans la barre, panneau complet au clic.
// Reimplementation de `omarchy.monitor` — memes sections et memes gestes, sans
// dependre du plugin natif.
//
// Bouton : clic ouvre le panneau, molette ajuste la luminosite de 5 %.
// Panneau : luminosite du retroeclairage, facteur d'echelle de l'ecran focus,
// liste des ecrans avec activation.
BarWidget {
  id: root
  moduleName: "local.menubar.displays"

  readonly property int islandSize: bar && bar.islandSize !== undefined ? bar.islandSize : barSize
  readonly property int islandRadius: bar && bar.islandRadius !== undefined ? bar.islandRadius : Style.cornerRadius

  // Une seule courbe pour tout ce qui se deplie ou s'allume.
  readonly property int revealDuration: bar && bar.revealDuration !== undefined ? bar.revealDuration : 180
  readonly property int revealEasing: Easing.OutCubic

  // Accent porte par tout ce qui est actif, survole ou en mouvement — la teinte
  // du workspace courant.
  readonly property color accentColor: bar ? bar.accent : Color.urgent
  readonly property real accentFillOpacity: bar && bar.accentFillOpacity !== undefined ? bar.accentFillOpacity : 0.18
  // Debordement du halo, pour qu'il epouse les bords de l'ilot au lieu d'en
  // laisser voir un lisere tout autour.
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

  // --- Etat ------------------------------------------------------------------
  // Tout vient de `omarchy-monitor-state`, qui rassemble en un appel ce que
  // brightnessctl et hyprctl exposent separement.

  property int brightnessPercent: 0
  property bool brightnessAvailable: false
  property string focusedMonitor: ""
  property string monitorScale: ""
  property var displays: []
  property int enabledDisplayCount: 0

  // Ecran qui porte la barre complete — les autres n'affichent que leurs
  // workspaces. La valeur vient de la barre, qui l'a deja resolue contre les
  // ecrans reellement branches : ce qui est marque ici est donc ce qui est
  // affiche, pas ce qui est enregistre.
  readonly property string primaryScreen: bar && bar.primaryScreen !== undefined ? String(bar.primaryScreen) : ""

  // Les seuls facteurs qu'`omarchy-hyprland-monitor-scaling` accepte : lui en
  // passer un autre le fait sortir en erreur sans rien changer.
  readonly property var scaleValues: ["1", "1.25", "1.6", "2", "3", "4"]

  // La section des ecrans n'a de sens qu'a partir de deux : avec un seul, il n'y
  // a rien a choisir et la seule action possible serait d'eteindre le poste.
  readonly property bool displaysVisible: displays.length > 1

  function clampBrightness(value) {
    var n = Number(value)
    if (!isFinite(n)) return 1
    return Math.max(1, Math.min(100, Math.round(n)))
  }

  // Les facteurs remontent de hyprctl avec un nombre de decimales variable
  // ("1.00", "1.6") : sans mise a plat, aucune pastille ne se reconnaitrait
  // comme active.
  function normalizeScale(scale) {
    var n = parseFloat(String(scale || ""))
    if (!isFinite(n)) return ""
    return String(Math.round(n * 100) / 100)
  }

  // Nom d'ambiance pour un niveau de luminosite. Les bandes couvrent 10 a
  // 20 points : un reglage franc change le libelle, un ajustement fin non.
  function brightnessName(percent) {
    var p = Math.round(percent)
    if (p >= 95) return "Sun blast"
    if (p >= 80) return "Solar flare"
    if (p >= 65) return "Golden hour"
    if (p >= 45) return "Even day"
    if (p >= 30) return "Soft glow"
    if (p >= 20) return "Lamp light"
    if (p >= 10) return "Candlelit"
    return "Night owl"
  }

  function parseState(raw) {
    var lines = String(raw || "").split("\n")

    var brightness = String(lines[0] || "").trim()
    brightnessAvailable = brightness !== "unavailable" && brightness !== ""
    brightnessPercent = brightnessAvailable
      ? Math.max(0, Math.min(100, parseInt(brightness, 10)))
      : 0

    // Les lignes 1 a 4 decrivent l'ecran interne et le miroir : le panneau natif
    // les lit sans jamais les afficher, on les ignore aussi.
    focusedMonitor = String(lines[5] || "").trim()
    monitorScale = normalizeScale(String(lines[6] || "").trim())

    var parsed = []
    try {
      parsed = JSON.parse(String(lines[7] || "[]").trim())
    } catch (e) {
      parsed = []
    }
    if (!Array.isArray(parsed)) parsed = []

    var count = 0
    for (var i = 0; i < parsed.length; i++) {
      if (parsed[i] && parsed[i].enabled) count++
    }

    displays = parsed
    enabledDisplayCount = count
    clampCursor()
  }

  Process {
    id: stateProc

    command: ["omarchy-monitor-state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseState(text)
    }
  }

  function refresh() {
    if (!stateProc.running) stateProc.running = true
  }

  // Cadence resserree quand le panneau est ouvert. Ferme, la barre n'a besoin
  // que de savoir combien d'ecrans sont branches.
  Timer {
    interval: root.opened ? 2000 : 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // --- Actions ---------------------------------------------------------------

  function setBrightness(value) {
    if (!brightnessAvailable) return

    var percent = clampBrightness(value)
    brightnessPercent = percent
    pendingBrightnessPercent = percent

    // Un seul appel en vol a la fois : brightnessctl serialise mal les ecritures
    // concurrentes. La derniere valeur demandee part des que le precedent rend
    // la main.
    if (setBrightnessProc.running) {
      brightnessSetQueued = true
      return
    }

    brightnessSetQueued = false
    setBrightnessProc.command = ["omarchy-brightness-display", "--no-osd", percent + "%"]
    setBrightnessProc.running = true
  }

  property int pendingBrightnessPercent: 0
  property bool brightnessSetQueued: false

  // Pendant un glissement, la valeur affichee suit le doigt et l'ecriture reelle
  // attend une pause : sans ce delai, chaque pixel parcouru forkerait un appel.
  function previewBrightness(value) {
    brightnessPercent = clampBrightness(value)
    brightnessDebounce.restart()
  }

  Timer {
    id: brightnessDebounce
    interval: 180
    onTriggered: root.setBrightness(root.brightnessPercent)
  }

  Process {
    id: setBrightnessProc

    stdout: StdioCollector { waitForEnd: true }
    // Surtout pas de refresh() ici : la valeur qu'on vient d'ecrire fait foi, et
    // relire le retroeclairage pendant que le pilote l'applique renvoie parfois
    // une chaine vide — le panneau retomberait alors visiblement a zero. Les
    // changements venus d'ailleurs sont rattrapes par le releve periodique.
    onRunningChanged: {
      if (running) return
      if (root.brightnessSetQueued) root.setBrightness(root.pendingBrightnessPercent)
    }
  }

  // Eteindre le dernier ecran actif laisserait la session sans affichage : la
  // ligne concernee devient inerte plutot que de proposer un geste sans retour.
  function toggleDisplay(name, enabled) {
    if (!name) return
    if (enabled && enabledDisplayCount <= 1) return

    actionProc.command = ["hyprctl", "keyword", "monitor",
                          name + (enabled ? ",disable" : ",preferred,auto,auto")]
    if (!actionProc.running) actionProc.running = true
  }

  // Promouvoir un ecran eteint laisserait la barre complete sur une surface
  // invisible : le geste n'est offert que sur les ecrans allumes, et la barre
  // fait de toute facon retomber le role sur le premier ecran si celui qui est
  // nomme disparait.
  function setPrimary(name) {
    if (!name || !bar || typeof bar.setPrimaryScreen !== "function") return

    bar.setPrimaryScreen(String(name))
  }

  // Le facteur s'applique a l'ecran qui a le focus, pas a tous.
  function setScale(scale) {
    actionProc.command = ["omarchy-hyprland-monitor-scaling", String(scale)]
    if (!actionProc.running) actionProc.running = true
  }

  Process {
    id: actionProc

    stdout: StdioCollector { waitForEnd: true }
    onRunningChanged: if (!running) root.refresh()
  }

  // --- Glyphes ---------------------------------------------------------------
  // Glyphes Nerd Font, memes codepoints que le widget natif. Ils vivent dans la
  // zone privee Unicode : ils s'affichent en carre vide dans un editeur sans la
  // police, mais le fichier est bien en UTF-8.

  readonly property string glyphDisplay: "󰍹"
  readonly property string glyphDisplays: "󰍺"
  readonly property string glyphEnabled: "󰄬"
  readonly property string glyphPrimary: "󰓎"
  readonly property string glyphNotPrimary: "󰓒"

  readonly property string currentGlyph: displays.length > 1 ? glyphDisplays : glyphDisplay

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
  //   omarchy-shell menubar.displays toggle
  IpcHandler {
    enabled: root.primaryInstance
    target: "menubar.displays"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  onOpenedChanged: {
    if (!opened) return

    refresh()
    cursor = 0
    cursorActive = false
    scaleCursor = currentScaleIndex()
    displayColumn = 0
  }

  // --- Curseur clavier -------------------------------------------------------
  // Les lignes navigables sont mises a plat dans un seul tableau : le curseur est
  // un index dedans, partage avec la souris pour qu'un seul element soit
  // surligne a la fois. Les pastilles d'echelle occupent une ligne unique, ou le
  // deplacement horizontal choisit la pastille.

  property int cursor: 0
  property int scaleCursor: 0
  property bool cursorActive: false
  // Colonne active a l'interieur d'une ligne d'ecran : 0 = allumage, 1 = ecran
  // principal. Meme mecanique que `scaleCursor` sur la ligne d'echelle, les
  // fleches horizontales font la navette entre les deux.
  readonly property int displayColumnCount: 2
  property int displayColumn: 0

  readonly property var rows: {
    var list = []
    if (brightnessAvailable) list.push({ kind: "brightness", index: -1 })
    list.push({ kind: "scale", index: -1 })
    if (displaysVisible) {
      for (var i = 0; i < displays.length; i++) list.push({ kind: "display", index: i })
    }
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

  function currentScaleIndex() {
    for (var i = 0; i < scaleValues.length; i++) {
      if (normalizeScale(scaleValues[i]) === normalizeScale(monitorScale)) return i
    }
    return 0
  }

  function clampCursor() {
    if (cursor >= rows.length) cursor = Math.max(0, rows.length - 1)
    if (cursor < 0) cursor = 0
    if (scaleCursor >= scaleValues.length) scaleCursor = scaleValues.length - 1
    if (scaleCursor < 0) scaleCursor = 0
    if (displayColumn >= displayColumnCount) displayColumn = displayColumnCount - 1
    if (displayColumn < 0) displayColumn = 0
  }

  function moveCursor(delta) {
    cursor = Math.max(0, Math.min(rows.length - 1, cursor + delta))
  }

  // Fleches horizontales : elles agissent a l'interieur de la ligne courante —
  // la luminosite sur son slider, la pastille voisine sur la ligne d'echelle,
  // l'allumage ou l'etoile sur une ligne d'ecran.
  function adjustCursorH(delta) {
    var row = rowAt(cursor)
    if (!row) return

    if (row.kind === "brightness") setBrightness(brightnessPercent + delta * 5)
    else if (row.kind === "scale")
      scaleCursor = Math.max(0, Math.min(scaleValues.length - 1, scaleCursor + delta))
    else if (row.kind === "display")
      displayColumn = Math.max(0, Math.min(displayColumnCount - 1, displayColumn + delta))
  }

  function activateCursor() {
    var row = rowAt(cursor)
    if (!row) return

    if (row.kind === "scale") setScale(scaleValues[scaleCursor])
    else if (row.kind === "display") {
      var display = displays[row.index]
      if (!display) return

      if (displayColumn === 1) {
        if (display.enabled) setPrimary(display.name)
      } else {
        toggleDisplay(display.name, display.enabled)
      }
    }
    // Luminosite : la valeur du slider est deja l'action, il n'y a rien a valider.
  }

  // `column` est optionnel : seules les lignes d'ecran en ont une, les autres
  // appellent avec deux arguments et laissent la colonne ou elle etait.
  function pointCursorAt(kind, index, column) {
    var position = rowIndexOf(kind, index)
    if (position < 0) return

    cursorActive = true
    cursor = position
    if (column !== undefined) displayColumn = column
  }

  // --- Bouton de barre -------------------------------------------------------

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Halo de survol. Meme rayon que l'ilot, et non la moitie de la hauteur : Qt
  // rabat le rayon a la moitie du plus petit cote, ce qui arrondirait le halo
  // plus que l'ilot qui l'entoure.
  Rectangle {
    anchors.fill: parent
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

    anchors.fill: parent
    bar: root.bar
    text: root.currentGlyph
    tooltipText: {
      var count = root.enabledDisplayCount
      var label = count + (count > 1 ? " displays" : " display")
      return root.focusedMonitor !== "" ? label + " · " + root.focusedMonitor : label
    }
    fixedWidth: root.vertical ? root.islandSize : Math.max(Style.space(24), root.islandRadius * 2)
    fixedHeight: root.islandSize
    // A la taille de la barre, le glyphe hinte tombe deux pixels trop a droite
    // dans le bouton. `rightExtraMargin` recule le libelle de la moitie de sa
    // valeur, a l'echelle du theme comme l'ecart qu'il corrige, sans toucher a
    // la largeur que `fixedWidth` tient deja. Le widget natif retient la meme
    // valeur pour ce meme glyphe.
    rightExtraMargin: 4
    onPressed: function(mouseButton) { root.toggle() }
    onWheelMoved: function(delta) {
      root.setBrightness(root.brightnessPercent + (delta > 0 ? 5 : -5))
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
        else if (dx !== 0) root.adjustCursorH(dx)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()

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
                color: root.foregroundColor
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
                  text: "Displays"
                  color: root.foregroundColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }

                // Sur un poste sans retroeclairage pilotable il n'y a pas
                // d'ambiance a nommer : l'ecran qui a le focus prend la place.
                Text {
                  text: root.brightnessAvailable
                    ? root.brightnessName(brightnessSlider.dragging
                        ? brightnessSlider.liveValue
                        : root.brightnessPercent).toUpperCase()
                    : (root.focusedMonitor !== "" ? root.focusedMonitor.toUpperCase() + " FOCUSED" : "")
                  visible: text !== ""
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

          // ---- Luminosite ----
          PanelIsland {

            SectionHeader {
              text: "BRIGHTNESS"
              value: root.brightnessAvailable
                ? Math.round(brightnessSlider.dragging ? brightnessSlider.liveValue : root.brightnessPercent) + "%"
                : ""
            }

            CursorSurface {
              width: parent.width
              height: brightnessSlider.implicitHeight
              visible: root.brightnessAvailable
              hasCursor: root.cursorActive && root.cursor === root.rowIndexOf("brightness", -1)
              foreground: root.foregroundColor
              accent: root.accentColor
              outline: true

              HoverHandler {
                onHoveredChanged: if (hovered) root.pointCursorAt("brightness", -1)
              }

              PanelSlider {
                id: brightnessSlider

                bar: root.bar
                fillColor: root.accentColor
                knobColor: root.accentColor
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: 1
                maximum: 100
                step: 1
                integer: true
                value: root.brightnessPercent
                enabled: root.brightnessAvailable
                onMoved: function(value) { root.previewBrightness(value) }
                onReleased: function(value) {
                  brightnessDebounce.stop()
                  root.setBrightness(value)
                }
              }
            }

            Text {
              visible: !root.brightnessAvailable
              text: "No controllable backlight found"
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              width: parent.width
            }
          }

          // ---- Facteur d'echelle ----
          PanelIsland {

            SectionHeader {
              text: "SCALE"
              value: root.monitorScale !== "" ? root.monitorScale + "x" : ""
            }

            Grid {
              id: scaleGrid

              width: parent.width
              columns: root.scaleValues.length
              spacing: Style.space(4)

              readonly property real cellWidth: columns > 0
                ? (width - spacing * (columns - 1)) / columns
                : 0

              Repeater {
                model: root.scaleValues

                ScalePill {
                  required property string modelData
                  required property int index

                  scaleValue: modelData
                  scaleIndex: index
                  width: scaleGrid.cellWidth
                }
              }
            }
          }

          // ---- Ecrans ----
          PanelIsland {
            visible: root.displaysVisible

            SectionHeader {
              text: "DISPLAYS"
              value: root.enabledDisplayCount + " / " + root.displays.length
            }

            Repeater {
              model: root.displays

              DisplayRow {
                required property var modelData
                required property int index

                width: parent.width
                display: modelData
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
  // Voile tire du texte plutot qu'une couleur fixe : l'ilot se detache aussi
  // bien sur un fond de carte clair que sombre.
  readonly property color islandFill: Qt.rgba(foregroundColor.r, foregroundColor.g, foregroundColor.b, 0.06)

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

  // En-tete de section : intitule a gauche, valeur a droite.
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

  // Pastille d'echelle. `CursorSurface` plutot que `Button` : c'est lui qui porte
  // le vocabulaire de survol partage par toutes les lignes du panneau.
  component ScalePill: CursorSurface {
    id: pill

    required property string scaleValue
    required property int scaleIndex

    readonly property bool isCurrent: root.normalizeScale(root.monitorScale) === root.normalizeScale(scaleValue)

    height: Style.space(26)
    current: pill.isCurrent
    hasCursor: root.cursorActive
      && root.cursor === root.rowIndexOf("scale", -1)
      && root.scaleCursor === pill.scaleIndex
    foreground: root.foregroundColor
    accent: root.accentColor

    HoverHandler {
      onHoveredChanged: if (hovered) {
        root.pointCursorAt("scale", -1)
        root.scaleCursor = pill.scaleIndex
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.setScale(pill.scaleValue)
    }

    Text {
      anchors.centerIn: parent
      text: pill.scaleValue + "x"
      color: pill.isCurrent ? root.accentColor : root.foregroundColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: pill.isCurrent
    }
  }

  // Ligne d'ecran : glyphe, nom, coche sur ceux qui sont allumes, etoile pour
  // designer celui qui porte la barre complete. Deux gestes distincts sur une
  // meme ligne, donc deux zones : le corps allume ou eteint, l'etoile promeut.
  component DisplayRow: CursorSurface {
    id: displayRow

    required property var display
    required property int rowIndex

    readonly property string displayName: display ? String(display.name || "") : ""
    readonly property bool isFocused: !!display && display.focused === true
    readonly property bool isEnabled: !!display && display.enabled === true
    readonly property bool isPrimary: displayName !== "" && displayName === root.primaryScreen
    // Le dernier ecran allume n'est pas extinguible : la zone s'estompe pour le
    // dire avant le clic.
    readonly property bool canToggle: !isEnabled || root.enabledDisplayCount > 1
    // Rien a promouvoir sur un ecran deja principal, ni sur un ecran eteint —
    // la barre complete y serait invisible.
    readonly property bool canPromote: isEnabled && !isPrimary

    readonly property int rowCursor: root.rowIndexOf("display", rowIndex)

    height: Style.space(30)
    current: displayRow.isFocused
    hasCursor: root.cursorActive && root.cursor === displayRow.rowCursor && root.displayColumn === 0
    foreground: root.foregroundColor
    accent: root.accentColor

    // Zone d'allumage : tout sauf l'etoile.
    Item {
      id: toggleZone

      anchors.left: parent.left
      anchors.right: primaryZone.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      opacity: displayRow.canToggle ? 1 : 0.45

      HoverHandler {
        onHoveredChanged: if (hovered) root.pointCursorAt("display", displayRow.rowIndex, 0)
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: displayRow.canToggle ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (displayRow.canToggle) root.toggleDisplay(displayRow.displayName, displayRow.isEnabled)
      }

      Row {
        anchors.fill: parent
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(4)
        spacing: Style.space(8)

        // L'ecran qui a le focus porte l'accent : glyphe et libelle.
        Text {
          text: root.glyphDisplay
          color: displayRow.isFocused ? root.accentColor : root.foregroundColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.icon
          width: Style.space(20)
          horizontalAlignment: Text.AlignHCenter
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: displayRow.displayName + (displayRow.isFocused ? " · focused" : "")
          color: displayRow.isFocused ? root.accentColor : root.foregroundColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: displayRow.isFocused
          elide: Text.ElideRight
          width: parent.width - Style.space(50)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: displayRow.isEnabled ? root.glyphEnabled : ""
          color: root.accentColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.icon
          width: Style.space(14)
          horizontalAlignment: Text.AlignRight
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    // Zone d'ecran principal. Sa propre `CursorSurface` : l'etoile se surligne
    // seule quand le curseur est sur cette colonne, et garde une pastille
    // permanente sur l'ecran qui tient le role.
    CursorSurface {
      id: primaryZone

      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(26)
      height: Style.space(24)
      current: displayRow.isPrimary
      hasCursor: root.cursorActive && root.cursor === displayRow.rowCursor && root.displayColumn === 1
      foreground: root.foregroundColor
      accent: root.accentColor
      opacity: displayRow.canPromote || displayRow.isPrimary ? 1 : 0.45

      HoverHandler {
        id: primaryHover

        onHoveredChanged: if (hovered) root.pointCursorAt("display", displayRow.rowIndex, 1)
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: displayRow.canPromote ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (displayRow.canPromote) root.setPrimary(displayRow.displayName)
      }

      Text {
        anchors.centerIn: parent
        text: displayRow.isPrimary ? root.glyphPrimary : root.glyphNotPrimary
        color: displayRow.isPrimary ? root.accentColor : root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
      }
    }

    // Bulle d'aide de l'etoile : le geste change ce que montrent les AUTRES
    // ecrans, ce qu'aucun etat visible sur cette ligne ne dit. Elle se pose dans
    // la ligne, a gauche de l'etoile — le ScrollView clippe son contenu, une
    // bulle debordant de la liste serait rognee.
    BorderSurface {
      anchors.right: primaryZone.left
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: primaryHintLabel.implicitWidth + Style.space(16)
      implicitHeight: primaryHintLabel.implicitHeight + Style.space(8)
      radius: Style.cornerRadius
      color: Color.tooltip.background
      borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
      opacity: primaryHover.hovered ? 1 : 0
      visible: opacity > 0

      Behavior on opacity {
        NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
      }

      Text {
        id: primaryHintLabel

        anchors.centerIn: parent
        text: {
          if (displayRow.isPrimary) return "Carries the full menubar"
          if (!displayRow.isEnabled) return "Turn this screen on first"
          return "Move the full menubar here"
        }
        color: Color.tooltip.text
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
