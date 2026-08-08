import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Centre de notifications : pastille DND dans la barre, panneau au clic.
// Reimplementation du widget de `omarchy.notifications` — memes gestes, meme
// contenu — habillee comme les autres panneaux de la barre.
//
// Le daemon reste celui d'Omarchy. `PluginRegistry.isEnabled()` renvoie
// inconditionnellement `true` pour tout plugin first-party non-bar : il n'existe
// aucun moyen de couper `omarchy.notifications`, et deux NotificationServer se
// disputeraient org.freedesktop.Notifications. Ce widget se contente donc de lire
// ses modeles (pending / past / DND) ; les toasts restent rendus par lui.
//
// Bouton : clic gauche ouvre le panneau, clic droit bascule le mode DND.
BarWidget {
  id: root
  moduleName: "local.menubar.notifications"

  readonly property int islandSize: bar && bar.islandSize !== undefined ? bar.islandSize : barSize
  readonly property int islandRadius: bar && bar.islandRadius !== undefined ? bar.islandRadius : Style.cornerRadius

  readonly property int revealDuration: bar && bar.revealDuration !== undefined ? bar.revealDuration : 180
  readonly property int revealEasing: Easing.OutCubic

  readonly property color accentColor: bar ? bar.accent : Color.urgent
  readonly property real accentFillOpacity: bar && bar.accentFillOpacity !== undefined ? bar.accentFillOpacity : 0.18
  // Debordement du halo, pour qu'il epouse les bords de l'ilot au lieu d'en
  // laisser voir un lisere tout autour.
  readonly property int haloInsetX: bar && bar.islandPaddingX !== undefined ? bar.islandPaddingX : 0
  readonly property int haloInsetY: bar && bar.islandPaddingY !== undefined ? bar.islandPaddingY : 0
  readonly property color foregroundColor: bar ? bar.foreground : Color.foreground
  readonly property color mutedColor: Qt.darker(foregroundColor, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  // Meme remplissage d'ilot que les panneaux reseau et audio.
  readonly property color islandFill: Qt.rgba(foregroundColor.r, foregroundColor.g, foregroundColor.b, 0.06)
  readonly property color accentFill: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, accentFillOpacity)

  // --- Service natif ---------------------------------------------------------

  readonly property var hostShell: bar && bar.shell ? bar.shell : null
  readonly property var service: hostShell && typeof hostShell.firstPartyServiceFor === "function"
    ? hostShell.firstPartyServiceFor("omarchy.notifications")
    : null

  readonly property int pendingCount: service ? service.pendingModel.count : 0
  readonly property int pastCount: service ? service.pastModel.count : 0
  readonly property bool dnd: service ? service.doNotDisturb : false

  function toggleDnd() {
    if (service) service.setDoNotDisturb(!service.doNotDisturb)
  }

  // Les navigateurs Chromium prefixent le corps par le domaine emetteur, parfois
  // enrobe dans un <a>. On le retire pour ne garder que le message ; les <img>
  // sautent dans tous les cas, la ligne ayant son propre emplacement d'icone.
  function isChromiumDerived(app, appIcon) {
    var source = (String(app || "") + "\n" + String(appIcon || "")).toLowerCase()
    return source.indexOf("chrom") >= 0 || source.indexOf("brave") >= 0 ||
           source.indexOf("vivaldi") >= 0 || source.indexOf("microsoft-edge") >= 0 ||
           source.indexOf("opera") >= 0
  }

  function sanitizeBody(body, app, appIcon) {
    var text = String(body || "").replace(/<img[^>]*>/gi, "")
    if (!isChromiumDerived(app, appIcon)) return text

    return text
      .replace(/^\s*<a\b[^>]*>\s*(?:https?:\/\/|www\.)?(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?(?:\/[^<\s]*)?\s*<\/a>\s*/i, "")
      .replace(/^\s*(?:https?:\/\/|www\.)?(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?(?:\/\S*)?\s+/i, "")
  }

  function iconSource(icon) {
    var value = String(icon || "")
    if (value.length === 0) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  // --- Ouverture -------------------------------------------------------------

  property bool opened: false
  // Onglet actif. On revient sur pending des qu'il y a du non-vu, quelle que soit
  // la facon dont le panneau a ete ouvert : sans cela le comportement deriverait
  // selon le dernier onglet choisi a la main.
  property string activeTab: "pending"

  function open() {
    opened = true
    activeTab = pendingCount > 0 ? "pending" : "past"
  }

  function close() { opened = false }
  function toggle() { opened ? close() : open() }
  function closeForPopoutSwitch() { close() }

  readonly property bool primaryInstance: {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screens = Quickshell.screens
    return !!window && screens.length > 0 && window.screen === screens[0]
  }

  IpcHandler {
    enabled: root.primaryInstance
    target: "menubar.notifications"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function dnd(): void { root.toggleDnd() }
  }

  // --- Bouton de barre -------------------------------------------------------

  readonly property string glyph: {
    if (dnd) return "󰂛"
    if (pendingCount > 0) return "󱅫"
    return "󰂚"
  }

  // Meme gabarit que Network et Displays : une boite de glyphe de largeur fixe
  // entre deux gouttieres egales. La largeur fixe compte ici plus qu'ailleurs —
  // le glyphe change avec l'etat (cloche, cloche a badge, cloche barree), et un
  // cadre elastique ferait tressauter l'ilot a chaque notification recue.
  readonly property int glyphWidth: Style.space(14)
  readonly property int contentGap: Style.space(5)
  readonly property bool highlighted: widgetHover.hovered || opened

  implicitWidth: contentGap + glyphWidth + contentGap
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
    opacity: root.highlighted ? root.accentFillOpacity : 0

    Behavior on opacity {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }
  }

  Text {
    x: root.contentGap
    width: root.glyphWidth
    text: root.glyph
    // En attente, le glyphe prend l'accent — comme un workspace actif. En DND il
    // s'eteint sur l'encre secondaire : le mode est volontaire, il n'a pas a
    // reclamer l'attention.
    color: {
      if (root.dnd) return root.mutedColor
      return root.pendingCount > 0 ? root.accentColor : root.foregroundColor
    }
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    anchors.verticalCenter: parent.verticalCenter

    Behavior on color { ColorAnimation { duration: root.revealDuration } }
  }

  MouseArea {
    id: button

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.toggleDnd()
      else root.toggle()
    }
  }

  // --- Panneau ---------------------------------------------------------------

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    contentWidth: popup.fittedContentWidth(Style.space(440))
    contentHeight: popup.cappedContentHeight(Style.space(540))

    ColumnLayout {
      anchors.fill: parent
      // Meme respiration entre blocs que le contenu des autres panneaux.
      spacing: Style.space(12)

      // ---- Entete ----
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Text {
          text: "Notifications"
          font.family: root.fontFamily
          color: root.foregroundColor
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Item { Layout.fillWidth: true }

        // Pastille DND : pleine en accent quand le mode est actif, simple ilot au
        // repos. Pas de liseré — comme toutes les surfaces de panneau.
        Rectangle {
          id: dndPill
          Layout.preferredHeight: Math.max(Style.space(24), Style.font.bodySmall + Style.spacing.controlPaddingY * 2)
          Layout.preferredWidth: dndLabel.implicitWidth + dndGlyph.implicitWidth + Style.space(18)
          radius: Style.cornerRadius
          color: root.dnd ? root.accentColor : root.islandFill

          Behavior on color {
            ColorAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
          }

          Row {
            anchors.centerIn: parent
            spacing: Style.space(4)

            Text {
              id: dndGlyph
              text: root.dnd ? "󰂛" : "󰂚"
              font.family: root.fontFamily
              color: root.dnd ? Color.bar.background : root.mutedColor
              font.pixelSize: Style.font.body
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: dndLabel
              text: root.dnd ? "DND on" : "DND off"
              font.family: root.fontFamily
              color: root.dnd ? Color.bar.background : root.mutedColor
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleDnd()
          }
        }
      }

      // ---- Onglets ----
      RowLayout {
        Layout.fillWidth: true
        spacing: 0

        Repeater {
          model: [
            { key: "pending", label: "Pending",  count: root.pendingCount },
            { key: "past",    label: "Recently", count: root.pastCount }
          ]
          delegate: Rectangle {
            required property var modelData
            readonly property bool isActive: root.activeTab === modelData.key

            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(Style.space(30), Style.font.body + Style.spacing.controlPaddingY * 2)
            color: "transparent"

            Text {
              anchors.centerIn: parent
              text: modelData.label + (modelData.count > 0 ? "  " + modelData.count : "")
              font.family: root.fontFamily
              color: parent.isActive ? root.foregroundColor : root.mutedColor
              font.pixelSize: Style.font.body
              font.bold: parent.isActive
            }

            // Soulignement : accent pour l'onglet actif, encre d'ilot sinon.
            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: Math.max(1, Style.space(2))
              radius: height / 2
              color: parent.isActive ? root.accentColor : root.islandFill

              Behavior on color {
                ColorAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.activeTab = modelData.key
            }
          }
        }
      }

      // ---- Action de masse ----
      RowLayout {
        Layout.fillWidth: true
        visible: (root.activeTab === "pending" && root.pendingCount > 0)
              || (root.activeTab === "past" && root.pastCount > 0)
        spacing: Style.space(8)

        Item { Layout.fillWidth: true }

        Rectangle {
          Layout.preferredWidth: actionLabel.implicitWidth + Style.space(16)
          Layout.preferredHeight: Math.max(Style.space(22), Style.font.bodySmall + Style.spacing.controlPaddingY * 2)
          radius: Style.cornerRadius
          // Au survol, le meme halo d'accent que les widgets de barre.
          color: actionArea.containsMouse ? root.accentFill : root.islandFill

          Behavior on color {
            ColorAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
          }

          Text {
            id: actionLabel
            anchors.centerIn: parent
            text: root.activeTab === "pending" ? "Mark all as seen" : "Clear recent"
            font.family: root.fontFamily
            color: root.foregroundColor
            font.pixelSize: Style.font.caption
          }

          MouseArea {
            id: actionArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (!root.service) return
              if (root.activeTab === "pending") root.service.markAllSeen()
              else root.service.clearPast()
            }
          }
        }
      }

      // ---- Liste ----
      ListView {
        id: listView
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Style.space(8)

        readonly property bool onPending: root.activeTab === "pending"
        model: !root.service ? null
              : (onPending ? root.service.pendingModel : root.service.pastModel)
        visible: count > 0

        // Chaque ligne est un ilot de panneau : aplat a 6 %, rayon du theme,
        // aucune bordure — exactement PanelIsland des panneaux reseau et audio.
        delegate: Rectangle {
          id: row
          required property int index
          required property string app
          required property string appIcon
          required property string summary
          required property string body
          required property string image
          required property int urgency
          required property double timestamp

          readonly property bool hasMedia: image.length > 0 && (
            image.indexOf("image://icon//") === 0 || image.indexOf("file://") === 0)
          readonly property string smallIconSource: image.length > 0 ? image : root.iconSource(appIcon)
          readonly property bool hasIcon: !hasMedia && smallIconSource.length > 0
          readonly property string sanitizedBody: root.sanitizeBody(body, app, appIcon)
          readonly property bool critical: urgency === 2

          width: listView.width
          implicitHeight: rowContent.implicitHeight + Style.spacing.panelGap
          radius: Style.cornerRadius
          // Une notification critique se signale par un aplat d'accent : c'est la
          // seule distinction d'urgence que la barre pratique elle aussi.
          color: critical ? root.accentFill : root.islandFill

          RowLayout {
            id: rowContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(10)

            Item {
              id: imageSlot
              Layout.preferredWidth: Style.space(32)
              Layout.preferredHeight: Style.space(32)
              Layout.alignment: Qt.AlignVCenter
              // Masque en cas d'echec de chargement, pour qu'un nom d'icone non
              // resolu ne peigne pas le carre « image cassee » de Qt.
              visible: (row.hasIcon || row.hasMedia) && rowIcon.status !== Image.Error

              Image {
                id: rowIcon
                anchors.fill: parent
                source: row.hasMedia ? row.image : row.smallIconSource
                fillMode: row.hasMedia ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                sourceSize.width: imageSlot.width * Screen.devicePixelRatio
                sourceSize.height: imageSlot.height * Screen.devicePixelRatio
                asynchronous: true
                smooth: true
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(2)

              Text {
                Layout.fillWidth: true
                visible: row.summary.length > 0
                text: row.summary
                font.family: root.fontFamily
                color: root.foregroundColor
                font.pixelSize: Style.font.body
                font.bold: true
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 1
              }

              Text {
                Layout.fillWidth: true
                visible: row.sanitizedBody.length > 0
                text: row.sanitizedBody
                font.family: root.fontFamily
                textFormat: Text.PlainText
                color: root.mutedColor
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
              }
            }

            Rectangle {
              Layout.preferredWidth: Style.space(18)
              Layout.preferredHeight: Style.space(18)
              Layout.alignment: Qt.AlignVCenter
              radius: Style.cornerRadius
              color: closeArea.containsMouse ? root.accentFill : "transparent"

              Behavior on color {
                ColorAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
              }

              Text {
                anchors.centerIn: parent
                text: "✕"
                font.family: root.fontFamily
                color: closeArea.containsMouse ? root.accentColor : root.mutedColor
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!root.service) return
                  if (listView.onPending) root.service.dismissPending(row.index)
                  else root.service.dismissPast(row.index)
                }
              }
            }
          }
        }
      }

      // ---- Etat vide ----
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: listView.count === 0

        ColumnLayout {
          anchors.centerIn: parent
          spacing: Style.space(6)

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰂚"
            font.family: root.fontFamily
            // Assez pale pour rester decoratif, assez dense pour ne pas
            // disparaitre : l'aplat d'ilot a 6 % serait invisible en glyphe.
            color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, 0.15)
            font.pixelSize: Style.font.displayLarge
          }

          Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.activeTab === "pending" ? "Nothing waiting for you" : "Nothing recent"
            font.family: root.fontFamily
            color: root.mutedColor
            font.pixelSize: Style.font.body
          }
        }
      }
    }
  }
}
