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

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

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
    horizontalMargin: 8.75
    verticalPadding: 8.75
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton) root.alt = !root.alt
    }
  }
}
