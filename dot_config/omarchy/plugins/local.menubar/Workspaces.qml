import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Switcher de workspaces Hyprland, par ecran.
//
// Chaque ecran a ses propres `slotsPerScreen` workspaces, et cette barre-ci ne
// montre que ceux du sien : les deux ecrans affichent donc 1..5 en meme temps.
// Sous le capot les identifiants restent globaux — Hyprland n'en connait pas
// d'autres — et l'ecran de droite se voit attribuer la tranche 6..10. Le
// decoupage est pose par ~/.config/hypr/workspaces.lua, qui epingle chaque
// tranche a son ecran ; on se contente ici de le refleter, en reetiquetant les
// pastilles 1..5 pour qu'elles correspondent aux touches SUPER+1..5.
BarWidget {
  id: root
  moduleName: "local.menubar.workspaces"

  // Doit valoir SLOTS dans ~/.config/hypr/workspaces.lua : les deux fichiers
  // decrivent le meme decoupage, l'un pour les touches, l'autre pour l'affichage.
  property int slotsPerScreen: 5

  // Ecran qui porte cette instance de la barre, passe par Bar.qml. Sans lui on
  // ne peut pas savoir quelle tranche afficher.
  property var barScreen: null

  // Hauteur de l'ilot qui nous contient : plus petite que `barSize`, qui compte
  // en plus l'air laisse entre les ilots et les bords de la surface.
  readonly property int islandSize: bar && bar.islandSize !== undefined ? bar.islandSize : barSize

  readonly property color accentColor: bar ? bar.accent : Color.urgent
  readonly property real accentFillOpacity: bar && bar.accentFillOpacity !== undefined ? bar.accentFillOpacity : 0.18
  readonly property int revealDuration: bar && bar.revealDuration !== undefined ? bar.revealDuration : 180
  readonly property int haloInsetX: bar && bar.islandPaddingX !== undefined ? bar.islandPaddingX : 0
  readonly property int haloInsetY: bar && bar.islandPaddingY !== undefined ? bar.islandPaddingY : 0

  // `Hyprland.monitors` se remplit a la demande : tant que personne n'a reclame
  // un moniteur, la liste est vide. On les amorce tous des le depart, sinon le
  // calcul de la tranche ci-dessous verrait un seul ecran au demarrage et
  // placerait les deux barres sur la meme tranche.
  Component.onCompleted: {
    for (var i = 0; i < Quickshell.screens.length; i++) Hyprland.monitorFor(Quickshell.screens[i])
  }

  readonly property var monitor: root.barScreen ? Hyprland.monitorFor(root.barScreen) : null

  // Ecrans de gauche a droite, puis de haut en bas — le meme ordre que
  // workspaces.lua, pour que la pastille "3" et la touche SUPER+3 designent bien
  // le meme workspace. On n'ordonne pas par `id`, que Hyprland reattribue au
  // branchement.
  readonly property int slotBase: {
    if (!root.monitor) return 0

    var monitors = Hyprland.monitors.values.slice()
    monitors.sort(function(left, right) {
      if (left.x !== right.x) return left.x - right.x
      if (left.y !== right.y) return left.y - right.y
      return left.name < right.name ? -1 : 1
    })

    for (var i = 0; i < monitors.length; i++) {
      if (monitors[i].name === root.monitor.name) return i * root.slotsPerScreen
    }

    return 0
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  // Les `slotsPerScreen` pastilles de cet ecran, etiquetees 1..5 quelle que soit
  // la tranche. Elles restent toutes visibles meme vides : workspaces.lua les
  // declare `persistent`, et la barre ne se decale donc pas quand on ferme le
  // dernier client d'un workspace.
  function slotEntries() {
    var base = root.slotBase
    var entries = []

    for (var slot = 1; slot <= root.slotsPerScreen; slot++) {
      entries.push({ id: base + slot, label: String(slot) })
    }

    // Un workspace hors tranche a pu atterrir sur cet ecran — une regle
    // applicative, ou un troisieme ecran debranche qui a rendu sa tranche. Le
    // cacher le rendrait inatteignable a la souris : on l'ajoute a la suite,
    // sous son identifiant reel pour qu'il se distingue des slots.
    var name = root.monitor ? root.monitor.name : ""
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var workspace = values[i]

      // Les workspaces speciaux (scratchpad) portent un id negatif : on les
      // ignore, ils ne se selectionnent pas comme un workspace normal.
      if (workspace.id <= 0) continue
      if (workspace.id > base && workspace.id <= base + root.slotsPerScreen) continue
      if (!workspace.monitor || workspace.monitor.name !== name) continue

      entries.push({ id: workspace.id, label: String(workspace.id) })
    }

    entries.sort(function(left, right) { return left.id - right.id })
    return entries
  }

  // Hyprland 0.56 a remplace les dispatchers historiques par une API Lua :
  // `hyprctl dispatch workspace 2` renvoie desormais une erreur de syntaxe.
  //
  // Au clavier c'est l'ecran focus qui decide de la cible ; au clic c'est la
  // barre cliquee, donc on vise l'identifiant directement. Cliquer la barre de
  // l'ecran voisin y amene le focus, ce qui est bien l'intention du geste.
  function focusWorkspace(id) {
    if (!root.bar) return

    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  implicitWidth: grid.implicitWidth
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid

    anchors.fill: parent
    columns: root.vertical ? 1 : root.slotEntries().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.slotEntries()

      Item {
        id: cell

        required property var modelData

        implicitWidth: workspaceButton.implicitWidth
        implicitHeight: workspaceButton.implicitHeight

        // Halo de survol, dans la meme teinte que le workspace actif. Il deborde
        // du padding de l'ilot : les pastilles extremes en epousent alors les
        // bords, et celles du milieu restent centrees sur leur chiffre.
        Rectangle {
          anchors.fill: parent
          anchors.leftMargin: -root.haloInsetX
          anchors.rightMargin: -root.haloInsetX
          anchors.topMargin: -root.haloInsetY
          anchors.bottomMargin: -root.haloInsetY
          radius: Math.min(height / 2, Style.cornerRadius)
          color: root.accentColor
          opacity: workspaceButton.tooltipHovered ? root.accentFillOpacity : 0

          Behavior on opacity {
            NumberAnimation { duration: root.revealDuration; easing.type: Easing.OutCubic }
          }
        }

        WidgetButton {
          id: workspaceButton

          readonly property var workspace: root.workspaceById(cell.modelData.id)
          readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0

          // Le workspace actif de CET ecran, pas celui qui a le focus clavier :
          // les deux barres montrent chacune ou elles en sont, et celle de
          // l'ecran inactif garde sa pastille allumee.
          readonly property bool current: root.monitor !== null
            && root.monitor.activeWorkspace !== null
            && root.monitor.activeWorkspace.id === cell.modelData.id

          anchors.fill: parent
          bar: root.bar
          text: cell.modelData.label
          // Actif = couleur d'accent ; vide = estompe, sans disparaitre.
          active: current
          opacity: occupied || current ? 1 : 0.4
          fixedWidth: root.vertical ? root.islandSize : Style.space(20)
          fixedHeight: root.islandSize
          onPressed: function(mouseButton) {
            if (mouseButton === Qt.LeftButton) root.focusWorkspace(cell.modelData.id)
          }
        }
      }
    }
  }
}
