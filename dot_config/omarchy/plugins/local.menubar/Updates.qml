import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Widget de mises a jour : absent de la barre tant qu'il n'y a rien a mettre a
// jour. Des qu'un paquet attend, une pastille apparait, le compte se deplie au
// survol, et le panneau detaille ce qui changerait.
//
// Le releve vient de `updates.sh`, pose a cote de ce fichier, qui agrege
// pacman et l'AUR.
BarWidget {
  id: root
  moduleName: "local.menubar.updates"

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

  // --- Releve ----------------------------------------------------------------

  property var packages: []
  property bool checking: false

  readonly property int updateCount: packages.length
  readonly property int repoCount: {
    var total = 0
    for (var i = 0; i < packages.length; i++) if (packages[i].origin === "repo") total++
    return total
  }
  readonly property int aurCount: updateCount - repoCount

  function parseUpdates(raw) {
    var next = []
    var lines = String(raw || "").split("\n")

    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].split("\t")
      if (parts[0] !== "pkg" || parts.length < 5) continue

      next.push({
        origin: parts[1],
        name: parts[2],
        current: parts[3],
        candidate: parts[4]
      })
    }

    // Reaffectation en bloc : muter le tableau en place ne notifie pas.
    packages = next
  }

  Process {
    id: checkProc

    readonly property string scriptPath: String(Qt.resolvedUrl("updates.sh")).replace(/^file:\/\//, "")

    command: ["bash", scriptPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseUpdates(text)
    }
    onExited: root.checking = false
  }

  function refresh() {
    if (checkProc.running) return

    checking = true
    checkProc.running = true
  }

  // Une demi-heure : les deux commandes du releve touchent le reseau, inutile
  // d'y revenir plus souvent pour une information qui bouge une fois par jour.
  Timer {
    interval: 1800000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Apres avoir lance la mise a jour, on resonde plus souvent pendant un temps
  // pour que la pastille disparaisse peu apres la fin, et non a la prochaine
  // demi-heure.
  property int followUpsLeft: 0

  Timer {
    id: followUpTimer

    interval: 120000
    repeat: true
    running: root.followUpsLeft > 0
    onTriggered: {
      root.followUpsLeft--
      root.refresh()
    }
  }

  function runUpdate() {
    if (bar) bar.run("omarchy-launch-floating-terminal-with-presentation omarchy-update")

    followUpsLeft = 15
    close()
  }

  // --- Ouverture -------------------------------------------------------------

  property bool opened: false

  function open() {
    opened = true
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

  // Le panneau n'a plus lieu d'etre si la derniere mise a jour vient d'etre
  // appliquee pendant qu'il etait ouvert.
  onUpdateCountChanged: if (updateCount === 0) close()

  readonly property bool primaryInstance: {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screens = Quickshell.screens
    return !!window && screens.length > 0 && window.screen === screens[0]
  }

  IpcHandler {
    enabled: root.primaryInstance
    target: "menubar.updates"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
  }

  // --- Bouton de barre -------------------------------------------------------

  // Ecrit en echappement plutot qu'en caractere : ce glyphe vit dans la zone
  // privee Unicode et ne survit pas toujours a un copier-coller.
  readonly property string glyphUpdate: "\uF021"

  // Largeur impaire : l'ilot l'est alors aussi, son centre tombe sur un pixel
  // entier et le glyphe s'y aligne sans demi-pixel d'ecart.
  readonly property int glyphWidth: Style.space(15)
  readonly property int contentGap: Style.space(5)
  readonly property bool countRevealed: widgetHover.hovered || opened
  property int countExtent: countRevealed ? countLabel.implicitWidth + contentGap : 0

  Behavior on countExtent {
    NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
  }

  // Rien a mettre a jour, rien a montrer : l'ilot s'efface entierement.
  //
  // L'ilot ne peut pas se lier a `visible` : en QML cette propriete se propage
  // du parent a l'enfant, et comme le widget est enfant de l'ilot, l'ilot
  // invisible rendrait le widget invisible a son tour, ce qui le maintiendrait
  // invisible pour toujours. D'ou cet indicateur, que la propagation n'atteint
  // pas.
  readonly property bool hasUpdates: updateCount > 0

  visible: hasUpdates
  implicitWidth: visible ? contentGap + glyphWidth + countExtent + contentGap : 0
  implicitHeight: visible ? islandSize : 0

  HoverHandler { id: widgetHover }

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -root.haloInsetX
    anchors.rightMargin: -root.haloInsetX
    anchors.topMargin: -root.haloInsetY
    anchors.bottomMargin: -root.haloInsetY
    radius: root.islandRadius
    color: root.accentColor
    opacity: root.countRevealed ? root.accentFillOpacity : 0

    Behavior on opacity {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }
  }

  Text {
    id: glyphLabel

    x: root.contentGap
    width: root.glyphWidth
    text: root.glyphUpdate
    // En accent : la pastille n'apparait que pour signaler quelque chose.
    color: root.accentColor
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    anchors.verticalCenter: parent.verticalCenter
  }

  Item {
    x: root.contentGap + root.glyphWidth
    width: root.countExtent
    height: parent.height
    clip: true

    Text {
      id: countLabel

      x: root.contentGap
      text: root.updateCount + (root.updateCount > 1 ? " updates" : " update")
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
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(760))

    PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: root.runUpdate()
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
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

                text: root.glyphUpdate
                color: root.accentColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
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
                  text: root.updateCount + (root.updateCount > 1 ? " updates" : " update")
                  color: root.foregroundColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                  elide: Text.ElideRight
                  width: parent.width
                }

                Text {
                  text: {
                    if (root.checking) return "CHECKING"

                    var parts = []
                    if (root.repoCount > 0) parts.push(root.repoCount + " REPO")
                    if (root.aurCount > 0) parts.push(root.aurCount + " AUR")
                    return parts.join(" · ")
                  }
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

          // ---- Action ----
          PanelIsland {

            CursorSurface {
              width: parent.width
              height: Style.space(30)
              hasCursor: actionHover.hovered
              foreground: root.foregroundColor
              accent: root.accentColor

              HoverHandler { id: actionHover }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.runUpdate()
              }

              Text {
                text: "Run omarchy-update"
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

          // ---- Paquets ----
          PanelIsland {

            SectionHeader {
              text: "PENDING"
              value: root.checking ? "CHECKING" : ""
            }

            Repeater {
              model: root.packages

              PackageRow {
                required property var modelData

                width: parent.width
                entry: modelData
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
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Nom du paquet, puis le saut de version qu'il propose.
  component PackageRow: Item {
    id: packageRow

    required property var entry

    width: parent.width
    implicitHeight: Style.space(26)

    Text {
      id: nameLabel

      text: packageRow.entry.name
      color: root.foregroundColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      width: Math.min(implicitWidth, parent.width * 0.45)
      anchors.left: parent.left
      anchors.leftMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
    }

    // L'AUR est signale : ces paquets se reconstruisent et prennent plus de
    // temps que ceux des depots.
    Text {
      id: originTag

      text: packageRow.entry.origin === "aur" ? "AUR" : ""
      visible: text !== ""
      color: root.accentColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      anchors.left: nameLabel.right
      anchors.leftMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: packageRow.entry.current + " → " + packageRow.entry.candidate
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideLeft
      anchors.left: originTag.right
      anchors.leftMargin: Style.space(8)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(2)
      horizontalAlignment: Text.AlignRight
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
