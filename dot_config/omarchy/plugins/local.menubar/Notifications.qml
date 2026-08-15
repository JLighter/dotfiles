import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Cloche de notifications : rejoue l'historique recent au clic gauche, bascule
// le mode DND au clic droit, balaie les toasts a l'ecran au clic milieu.
//
// Omarchy 4 a remplace le centre de notifications par un couple « toasts vivants
// + historique sur disque » : `pendingModel`, `pastModel`, `markAllSeen`,
// `clearPast`, `dismissPending` et `dismissPast` ont disparu du service. Il ne
// reste que `popupModel` — ce qui est affiche a l'instant — et un historique
// dans ~/.local/state/omarchy/notifications/history/ que seul le service sait
// relire. Le service ne sait donc plus rendre une liste, il sait re-afficher :
// le panneau a onglets n'a plus de source, et ce widget suit le geste natif.
//
// Le daemon reste celui d'Omarchy. `PluginRegistry.isEnabled()` renvoie
// inconditionnellement `true` pour tout plugin first-party non-bar : il n'existe
// aucun moyen de couper `omarchy.notifications`, et deux NotificationServer se
// disputeraient org.freedesktop.Notifications. Ce widget se contente donc de
// piloter le service ; les toasts restent rendus par lui.
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

  // --- Service natif ---------------------------------------------------------

  readonly property var hostShell: bar && bar.shell ? bar.shell : null
  readonly property var service: hostShell && typeof hostShell.firstPartyServiceFor === "function"
    ? hostShell.firstPartyServiceFor("omarchy.notifications")
    : null

  // Ce qui est affiche a l'instant, pas ce qui reste a lire : un toast compte
  // tant qu'il est a l'ecran, et l'historique n'est jamais denombre — le service
  // repond a un rejeu vide par son propre toast, personne n'a donc a savoir
  // d'avance s'il y a quelque chose a rejouer.
  readonly property int liveCount: service && service.popupModel ? service.popupModel.count : 0
  readonly property bool dnd: service ? service.doNotDisturb : false

  // Re-affiche en toasts ce que le service a archive. Sans effet visible tant
  // qu'un rejeu precedent n'est pas retombe : le service ignore la demande.
  function showHistory() {
    if (service) service.showRecentHistory()
  }

  function toggleDnd() {
    if (service) service.setDoNotDisturb(!service.doNotDisturb)
  }

  // Retire les toasts de l'ecran. L'historique, lui, n'est pas touche : un
  // balayage se defait d'un clic, alors qu'oublier l'archive est definitif —
  // seul l'IPC l'expose, hors de portee d'un clic milieu mal vise.
  function dismissAll() {
    if (service) service.clearPopups()
  }

  function clearHistory() {
    if (service) service.clearHistory()
  }

  readonly property bool primaryInstance: {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screens = Quickshell.screens
    return !!window && screens.length > 0 && window.screen === screens[0]
  }

  IpcHandler {
    enabled: root.primaryInstance
    target: "menubar.notifications"

    function history(): void { root.showHistory() }
    function dnd(): void { root.toggleDnd() }
    function dismiss(): void { root.dismissAll() }
    function clear(): void { root.clearHistory() }
  }

  // --- Bouton de barre -------------------------------------------------------

  readonly property string glyph: {
    if (dnd) return "󰂛"
    if (liveCount > 0) return "󱅫"
    return "󰂚"
  }

  readonly property string tooltip: {
    if (dnd) return "Ne pas deranger"
    if (liveCount > 0) return liveCount + (liveCount > 1 ? " notifications a l'ecran" : " notification a l'ecran")
    return "Rejouer les notifications recentes"
  }

  // Meme gabarit que Network et Displays : une boite de glyphe de largeur fixe
  // entre deux gouttieres egales. La largeur fixe compte ici plus qu'ailleurs —
  // le glyphe change avec l'etat (cloche, cloche a badge, cloche barree), et un
  // cadre elastique ferait tressauter l'ilot a chaque notification recue.
  readonly property int glyphWidth: Style.space(14)
  readonly property int contentGap: Style.space(5)
  readonly property bool highlighted: button.containsMouse

  // Lu par le filet de securite de la barre, qui repose le tooltip si son cible
  // disparait sous le curseur sans emettre son `exited`.
  readonly property bool tooltipHovered: button.containsMouse

  implicitWidth: contentGap + glyphWidth + contentGap
  implicitHeight: islandSize

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
    // A l'ecran, le glyphe prend l'accent — comme un workspace actif. En DND il
    // s'eteint sur l'encre secondaire : le mode est volontaire, il n'a pas a
    // reclamer l'attention.
    color: {
      if (root.dnd) return root.mutedColor
      return root.liveCount > 0 ? root.accentColor : root.foregroundColor
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
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltip)
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) root.toggleDnd()
      else if (mouse.button === Qt.MiddleButton) root.dismissAll()
      else root.showHistory()
    }
  }
}
