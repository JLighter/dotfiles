import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Barre de statut minimale : un switcher de workspaces au bord de depart, une
// horloge au bord oppose. La disposition est ecrite en dur ici, `bar.layout`
// de shell.json ne s'applique pas a cette barre (les commandes `omarchy bar
// add/remove/move` ne la touchent donc pas).
Item {
  id: root

  // Assignees par le host omarchy-shell juste apres le chargement. Aucune n'est
  // `required` : le host n'assigne que les proprietes qu'il trouve, et un
  // composant qui refuse de s'instancier disparait sans autre trace qu'une
  // ligne dans le log du shell.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  property var barWidgetRegistry: null
  property var pluginRegistry: null
  // Sous-arbre `bar:` de shell.json, reinjecte a chaque rechargement du
  // fichier. Seuls `position` et `transparent` sont lus.
  property var barConfig: null

  readonly property string position: {
    var value = Util.isPlainObject(barConfig) ? String(barConfig.position || "") : ""
    return ["top", "bottom", "left", "right"].indexOf(value) !== -1 ? value : "top"
  }
  readonly property bool vertical: position === "left" || position === "right"
  readonly property int barSize: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  readonly property bool transparent: Util.isPlainObject(barConfig) && barConfig.transparent === true

  // Contrat attendu par WidgetButton (qui lit ces couleurs sans garde) et par
  // les plugins qui s'ancrent sur la barre : le service de notifications lit
  // barSize/barHidden pour ne pas afficher ses popups sous la barre.
  property string fontFamily: Style.font.family
  property color background: Color.bar.background
  property color foreground: Color.bar.text
  property color barForeground: foreground
  property color urgent: Color.bar.active
  property bool foregroundAnimationEnabled: true
  property bool barHidden: false

  Behavior on background { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on barForeground { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

  // Lance une commande sur le workspace actif, sans attendre son resultat.
  function run(command) {
    if (!command) return

    launcher.command = Util.hyprExecCommand(command)
    launcher.startDetached()
  }

  function shellQuote(value) {
    return Util.shellQuote(value)
  }

  Process { id: launcher }

  // --- Tooltip partage -------------------------------------------------------
  // WidgetButton appelle showTooltip/hideTooltip sans verifier leur existence :
  // les deux doivent exister meme si un seul widget affiche un tooltip.

  property var tooltipTarget: null
  property string tooltipText: ""
  property bool tooltipShown: false

  function showTooltip(target, text) {
    if (!target || !text) {
      clearTooltip()
      return
    }

    tooltipTarget = target
    tooltipText = text
    tooltipTimer.restart()
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target) return

    clearTooltip()
  }

  function clearTooltip() {
    tooltipTimer.stop()
    tooltipShown = false
    tooltipTarget = null
    tooltipText = ""
  }

  function targetWindow(target) {
    return target && target.QsWindow ? target.QsWindow.window : null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && targetWindow(target) === window
  }

  Timer {
    id: tooltipTimer
    interval: 400
    onTriggered: root.tooltipShown = root.tooltipTarget !== null
  }

  // Filet de securite : un widget detruit ou masque sous le curseur n'emet pas
  // toujours son `exited`, ce qui laisserait le tooltip affiche indefiniment.
  Timer {
    interval: 100
    repeat: true
    running: root.tooltipShown
    onTriggered: if (!root.tooltipTarget || root.tooltipTarget.tooltipHovered !== true) root.clearTooltip()
  }

  // --- Masquage de la barre --------------------------------------------------
  // `omarchy-toggle-bar` cree ou supprime ce drapeau. FileView ne peut pas
  // observer un fichier absent : on surveille le dossier parent et on resonde.

  Process {
    id: barHiddenProbe
    running: true
    command: ["bash", "-lc", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser {
      onRead: function(line) { root.barHidden = String(line).trim() === "yes" }
    }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: barHiddenProbe.running = true
  }

  // --- Surfaces --------------------------------------------------------------

  Variants {
    model: Quickshell.screens

    delegate: Component {
      PanelWindow {
        id: barWindow

        required property var modelData

        screen: modelData
        visible: !root.barHidden
        color: root.transparent ? "transparent" : root.background

        // Ancrer deux bords opposes etire la fenetre le long de ceux-ci.
        anchors {
          top: root.position === "top" || root.vertical
          bottom: root.position === "bottom" || root.vertical
          left: root.position === "left" || !root.vertical
          right: root.position === "right" || !root.vertical
        }

        implicitWidth: root.vertical ? root.barSize : 0
        implicitHeight: root.vertical ? 0 : root.barSize

        WlrLayershell.namespace: "local-menubar"
        WlrLayershell.layer: WlrLayer.Top

        Loader {
          anchors.fill: parent
          sourceComponent: root.vertical ? verticalLayout : horizontalLayout
        }

        Component {
          id: horizontalLayout

          Item {
            anchors.fill: parent

            Workspaces {
              bar: root
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
            }

            Clock {
              bar: root
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }

        Component {
          id: verticalLayout

          Item {
            anchors.fill: parent

            Workspaces {
              bar: root
              anchors.top: parent.top
              anchors.topMargin: Style.space(8)
              anchors.horizontalCenter: parent.horizontalCenter
            }

            Clock {
              bar: root
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.space(8)
              anchors.horizontalCenter: parent.horizontalCenter
            }
          }
        }

        PopupWindow {
          id: tooltipWindow

          visible: root.tooltipShown
            && root.tooltipText !== ""
            && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
          color: "transparent"
          implicitWidth: Math.ceil(tooltipBubble.implicitWidth)
          implicitHeight: Math.ceil(tooltipBubble.implicitHeight)

          anchor {
            id: tooltipAnchor

            window: barWindow
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1

            // Le tooltip sort du cote oppose au bord occupe par la barre.
            onAnchoring: {
              var target = root.tooltipTarget
              if (!root.targetBelongsToWindow(target, barWindow)) return

              var localX = target.width / 2 - tooltipWindow.implicitWidth / 2
              var localY = target.height + Style.space(6)

              if (root.position === "bottom") {
                localY = -tooltipWindow.implicitHeight - Style.space(6)
              } else if (root.position === "left") {
                localX = target.width + Style.space(6)
                localY = target.height / 2 - tooltipWindow.implicitHeight / 2
              } else if (root.position === "right") {
                localX = -tooltipWindow.implicitWidth - Style.space(6)
                localY = target.height / 2 - tooltipWindow.implicitHeight / 2
              }

              var point = barWindow.contentItem.mapFromItem(target, localX, localY)
              tooltipAnchor.rect.x = Math.round(point.x)
              tooltipAnchor.rect.y = Math.round(point.y)
            }
          }

          BorderSurface {
            id: tooltipBubble

            implicitWidth: tooltipLabel.implicitWidth + Style.space(20)
            implicitHeight: tooltipLabel.implicitHeight + Style.space(14)
            color: Color.tooltip.background
            borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
            radius: Style.cornerRadius

            Text {
              id: tooltipLabel

              anchors.centerIn: parent
              text: root.tooltipText
              color: Color.tooltip.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
        }
      }
    }
  }
}
