import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Switcher de workspaces Hyprland. Les `minimumWorkspaces` premiers restent
// toujours visibles pour que la barre ne se decale pas quand un workspace se
// vide ; tout workspace ouvert au-dela vient s'ajouter a la suite.
BarWidget {
  id: root
  moduleName: "local.menubar.workspaces"

  property int minimumWorkspaces: 5

  // Hauteur de l'ilot qui nous contient : plus petite que `barSize`, qui compte
  // en plus l'air laisse entre les ilots et les bords de la surface.
  readonly property int islandSize: bar && bar.islandSize !== undefined ? bar.islandSize : barSize

  readonly property color accentColor: bar ? bar.accent : Color.urgent
  readonly property real accentFillOpacity: bar && bar.accentFillOpacity !== undefined ? bar.accentFillOpacity : 0.18
  readonly property int revealDuration: bar && bar.revealDuration !== undefined ? bar.revealDuration : 180

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = []
    for (var n = 1; n <= root.minimumWorkspaces; n++) ids.push(n)

    // Les workspaces speciaux (scratchpad) portent un id negatif : on les
    // ignore, ils ne se selectionnent pas comme un workspace normal.
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  // Hyprland 0.56 a remplace les dispatchers historiques par une API Lua :
  // `hyprctl dispatch workspace 2` renvoie desormais une erreur de syntaxe.
  function focusWorkspace(id) {
    if (!root.bar) return

    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  implicitWidth: grid.implicitWidth
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid

    anchors.fill: parent
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      Item {
        id: cell

        required property int modelData

        implicitWidth: workspaceButton.implicitWidth
        implicitHeight: workspaceButton.implicitHeight

        // Halo de survol, dans la meme teinte que le workspace actif.
        Rectangle {
          anchors.fill: parent
          radius: Math.min(height / 2, Style.cornerRadius)
          color: root.accentColor
          opacity: workspaceButton.tooltipHovered ? root.accentFillOpacity : 0

          Behavior on opacity {
            NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutCubic }
          }
        }

        WidgetButton {
          id: workspaceButton

          readonly property var workspace: root.workspaceById(cell.modelData)
          readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
          readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === cell.modelData

          anchors.fill: parent
          bar: root.bar
          // Le workspace 10 s'affiche "0" pour tenir sur un caractere.
          text: cell.modelData === 10 ? "0" : String(cell.modelData)
          // Actif = couleur d'accent ; vide = estompe, sans disparaitre.
          active: focused
          opacity: occupied || focused ? 1 : 0.4
          fixedWidth: root.vertical ? root.islandSize : Style.space(20)
          fixedHeight: root.islandSize
          onPressed: function(mouseButton) {
            if (mouseButton === Qt.LeftButton) root.focusWorkspace(cell.modelData)
          }
        }
      }
    }
  }
}
