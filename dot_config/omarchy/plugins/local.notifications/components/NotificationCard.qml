// Carte de toast. Purement presentationnelle — aucune reference au service, a
// Notification ou a un ListModel : le conteneur pilote la duree de vie, la carte
// ne fait que peindre.
//
// Ecrite pour parler la meme langue que local.menubar :
//   - la police suit celle de la barre (monospace) la ou la carte native code en
//     dur « Liberation Sans » ;
//   - le fond et l'encre viennent de la palette de la barre ;
//   - l'echelle typographique est celle des panneaux (subtitle / body) et non
//     `title` pour le titre comme pour le corps ;
//   - le survol allume le meme halo d'accent que les widgets de barre.

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string app: ""
  property string appIcon: ""
  property string summary: ""
  property string body: ""
  property string image: ""
  // Glyphe Nerd Font affiche dans l'emplacement d'icone quand aucune vraie icone
  // n'est fournie. Alimente par le drapeau `-g` d'omarchy-notification-send.
  property string glyph: ""
  // NotificationUrgency : Low=0, Normal=1, Critical=2.
  property int urgency: 1

  // --- Contrat de style, injecte par le conteneur -----------------------------
  property string fontFamily: Style.font.family
  property color surfaceColor: Color.bar.background
  property color textColor: Color.bar.text
  property color accentColor: Color.bar.active
  property real accentFillOpacity: 0.18
  property int revealDuration: 180
  property int revealEasing: Easing.OutCubic

  readonly property bool hovered: hoverTracker.hovered

  signal cardClicked()

  // On prefere les donnees propres a la notification (media, avatar), puis on
  // retombe sur l'icone de l'application.
  readonly property string smallIconSource: image.length > 0 ? image : iconSource(appIcon)
  readonly property bool hasGlyph: glyph.length > 0
  // Un glyphe sans icone se rend en ligne, sans reserver la vignette de 40px.
  readonly property bool compactGlyph: hasGlyph && smallIconSource.length === 0
  readonly property bool hasSmallIcon: smallIconSource.length > 0
  readonly property bool singleLineToast: body.length === 0

  // Meme creusement que `mutedColor` dans les panneaux : une seule encre
  // secondaire pour tout le shell.
  readonly property color mutedColor: Qt.darker(textColor, 1.4)
  readonly property bool critical: urgency === 2

  function iconSource(icon) {
    var value = String(icon || "")
    if (value.length === 0) return ""
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return Util.fileUrl(value)
    return Quickshell.iconPath(value, true)
  }

  // Un toast d'une seule ligne respire moins qu'une carte titre + corps.
  readonly property int verticalPadding: singleLineToast ? Style.space(7) : Style.space(10)

  implicitWidth: Style.space(380)
  // Le padding doit entrer dans la hauteur implicite : `mainRow` est centre
  // verticalement, il ne pousse donc pas la carte tout seul.
  implicitHeight: mainRow.implicitHeight + verticalPadding * 2
  color: surfaceColor
  clip: true

  HoverHandler { id: hoverTracker }

  // Une notification critique se signale par un aplat d'accent permanent : seule
  // distinction d'urgence que la barre pratique elle aussi. Le survol pose le
  // meme halo, ce qui rend visible la pause du minuteur.
  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: root.accentColor
    opacity: root.critical
      ? root.accentFillOpacity
      : (root.hovered ? root.accentFillOpacity : 0)

    Behavior on opacity {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.cardClicked()
  }

  RowLayout {
    id: mainRow
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(12)
    anchors.rightMargin: Style.space(12)
    spacing: root.compactGlyph ? Style.space(8) : Style.space(12)

    Item {
      id: iconSlot
      Layout.preferredWidth: visible ? Style.space(40) : 0
      Layout.preferredHeight: visible ? Style.space(40) : 0
      Layout.alignment: Qt.AlignVCenter
      // Masque quand l'icone n'a pas pu etre resolue ET qu'aucun glyphe ne prend
      // le relais — sinon Qt peint son carre rose de texture manquante.
      visible: !root.compactGlyph && root.hasSmallIcon && (root.hasGlyph || iconImage.status !== Image.Error)

      Image {
        id: iconImage
        anchors.fill: parent
        source: root.smallIconSource
        sourceSize.width: iconSlot.width * Screen.devicePixelRatio
        sourceSize.height: iconSlot.height * Screen.devicePixelRatio
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        visible: !root.hasGlyph || iconImage.status === Image.Ready
      }

      Text {
        anchors.centerIn: parent
        visible: root.hasGlyph && iconImage.status !== Image.Ready
        text: root.glyph
        color: root.critical ? root.accentColor : root.textColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.iconLarge
      }
    }

    Text {
      Layout.alignment: Qt.AlignVCenter
      visible: root.compactGlyph
      text: root.glyph
      color: root.critical ? root.accentColor : root.textColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.icon
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      spacing: Style.space(2)

      Text {
        Layout.fillWidth: true
        visible: root.summary.length > 0
        text: root.summary
        font.family: root.fontFamily
        color: root.textColor
        font.pixelSize: Style.font.subtitle
        font.bold: true
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        maximumLineCount: 2
      }

      Text {
        Layout.fillWidth: true
        Layout.topMargin: Style.space(2)
        visible: root.body.length > 0
        text: root.body
        textFormat: Text.StyledText
        font.family: root.fontFamily
        color: root.mutedColor
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        maximumLineCount: 3
      }
    }
  }
}
