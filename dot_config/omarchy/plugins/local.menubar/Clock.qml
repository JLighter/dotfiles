import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Horloge du bord oppose aux workspaces. Clic gauche = bascule vers le format
// long, clic de nouveau pour revenir.
BarWidget {
  id: root
  moduleName: "local.menubar.clock"

  // Formats Qt (cf. Qt.formatDateTime). Ils se modifient ici : cette barre ne
  // passe pas par `bar.layout`, donc `omarchy bar set` ne les atteint pas.
  property string format: "dddd HH:mm"
  property string formatAlt: "d MMMM yyyy"
  property string verticalFormat: "HH\n—\nmm"

  property bool alt: false

  readonly property string activeFormat: alt ? formatAlt : (root.vertical ? verticalFormat : format)
  // Hauteur de l'ilot qui nous contient : plus petite que `barSize`, qui compte
  // en plus l'air laisse entre les ilots et les bords de la surface.
  readonly property int islandSize: bar && bar.islandSize !== undefined ? bar.islandSize : barSize

  readonly property color accentColor: bar ? bar.accent : Color.urgent
  readonly property real accentFillOpacity: bar && bar.accentFillOpacity !== undefined ? bar.accentFillOpacity : 0.18
  readonly property int revealDuration: bar && bar.revealDuration !== undefined ? bar.revealDuration : 180

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Halo de survol, dans la meme teinte que le workspace actif.
  Rectangle {
    anchors.fill: parent
    radius: Math.min(height / 2, Style.cornerRadius)
    color: root.accentColor
    opacity: button.tooltipHovered ? root.accentFillOpacity : 0

    Behavior on opacity {
      NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutCubic }
    }
  }

  // Reveille le binding a chaque changement de minute, pas a chaque seconde.
  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  WidgetButton {
    id: button

    anchors.fill: parent
    bar: root.bar
    text: Qt.formatDateTime(clock.date, root.activeFormat)
    tooltipText: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy")
    // L'ilot apporte deja sa propre marge horizontale.
    horizontalMargin: 6
    fixedHeight: root.islandSize
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.alt = !root.alt
    }
  }
}
