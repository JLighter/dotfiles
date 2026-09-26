import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Ui

// Applications en arriere-plan : les icones que les programmes deposent dans le
// tray (protocole StatusNotifierItem). Reimplementation de `omarchy.tray` —
// memes gestes, meme tiroir — habillee comme le reste de la barre.
//
// Au repos seul un chevron occupe l'ilot ; au survol les icones glissent hors de
// lui. Les icones epinglees, elles, restent toujours visibles a sa droite.
//
// Reglages : `bar.tray.pinned` et `bar.tray.hidden` de shell.json. Le widget
// natif les range dans son entree de `bar.layout` via `updateEntryInline()`,
// chemin ferme ici — cette barre n'a pas de layout, ses widgets sont cables dans
// Bar.qml. On ecrit donc dans une cle a nous, avec `mutateShellConfig()`.
BarWidget {
  id: root
  moduleName: "local.menubar.tray"

  readonly property int islandSize: bar && bar.islandSize !== undefined ? bar.islandSize : barSize
  readonly property int islandRadius: bar && bar.islandRadius !== undefined ? bar.islandRadius : Style.cornerRadius

  readonly property int revealDuration: bar && bar.revealDuration !== undefined ? bar.revealDuration : 180
  readonly property int revealEasing: Easing.OutCubic

  readonly property color accentColor: bar ? bar.accent : Color.urgent
  readonly property real accentFillOpacity: bar && bar.accentFillOpacity !== undefined ? bar.accentFillOpacity : 0.18
  readonly property int haloInsetX: bar && bar.islandPaddingX !== undefined ? bar.islandPaddingX : 0
  readonly property int haloInsetY: bar && bar.islandPaddingY !== undefined ? bar.islandPaddingY : 0
  readonly property color foregroundColor: bar ? bar.foreground : Color.foreground
  readonly property color mutedColor: Qt.darker(foregroundColor, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color islandFill: Qt.rgba(foregroundColor.r, foregroundColor.g, foregroundColor.b, 0.06)
  readonly property color accentFill: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, accentFillOpacity)

  // --- Reglages --------------------------------------------------------------

  readonly property var trayConfig: {
    var config = bar && Util.isPlainObject(bar.barConfig) ? bar.barConfig.tray : null
    return Util.isPlainObject(config) ? config : ({})
  }

  readonly property var pinnedIds: Array.isArray(trayConfig.pinned) ? trayConfig.pinned : []
  readonly property var hiddenIds: Array.isArray(trayConfig.hidden) ? trayConfig.hidden : []

  // Le host reinjecte `barConfig` dans la barre apres ecriture, qui le repasse
  // ici : les listes se relisent seules, personne n'a a rafraichir quoi que ce
  // soit a la main.
  function persistTrayState(pinned, hidden) {
    var shell = bar ? bar.shell : null
    if (!shell || typeof shell.mutateShellConfig !== "function") return

    shell.mutateShellConfig(function(config) {
      if (!Util.isPlainObject(config.bar)) config.bar = {}
      config.bar.tray = { pinned: pinned, hidden: hidden }
    })
  }

  // Epingler retire du masque et inversement : un item ne peut pas etre a la
  // fois toujours visible et jamais visible.
  function togglePin(itemId) {
    var pinned = pinnedIds.slice()
    var hidden = hiddenIds.slice()
    var index = pinned.indexOf(itemId)

    if (index !== -1) {
      pinned.splice(index, 1)
    } else {
      pinned.push(itemId)
      var stale = hidden.indexOf(itemId)
      if (stale !== -1) hidden.splice(stale, 1)
    }

    persistTrayState(pinned, hidden)
  }

  function toggleHide(itemId) {
    var pinned = pinnedIds.slice()
    var hidden = hiddenIds.slice()
    var index = hidden.indexOf(itemId)

    if (index !== -1) {
      hidden.splice(index, 1)
    } else {
      hidden.push(itemId)
      var stale = pinned.indexOf(itemId)
      if (stale !== -1) pinned.splice(stale, 1)
    }

    persistTrayState(pinned, hidden)
  }

  // --- Repartition des items -------------------------------------------------

  // LocalSend choisit un identifiant de tray different a chaque lancement : le
  // masquer a la main ne tient donc pas d'une session a l'autre. Son item
  // n'affiche aucun etat et n'offre qu'Ouvrir et Quitter, la ou le menu Omarchy
  // expose deja Share > Receive — on l'ecarte par son nom, comme le natif.
  function ownedByOmarchy(item) {
    var haystack = (String(item.id || "") + "\n" + String(item.title || "") + "\n"
      + String(item.tooltipTitle || "")).toLowerCase()
    return haystack.indexOf("localsend") !== -1
  }

  function classify(item) {
    var itemId = String(item.id || "")
    if (hiddenIds.indexOf(itemId) !== -1) return "hidden"
    if (pinnedIds.indexOf(itemId) !== -1) return "pinned"
    return "drawer"
  }

  function bucket(category) {
    var values = SystemTray.items.values
    var result = []

    for (var i = 0; i < values.length; i++) {
      var item = values[i]
      if (item.status === Status.Passive) continue
      if (ownedByOmarchy(item)) continue

      if (category === "all") result.push(item)
      else if (classify(item) === category) result.push(item)
    }

    return result
  }

  readonly property var pinnedItems: bucket("pinned")
  readonly property var drawerItems: bucket("drawer")
  readonly property var allItems: bucket("all")

  // --- Tiroir ----------------------------------------------------------------

  property bool expanded: false
  property bool managePopupOpen: false
  property bool trayMenuOpen: false
  property var activeTrayItem: null
  property var activeTrayAnchor: null

  readonly property int itemExtent: Style.space(18)
  readonly property int chevronExtent: Style.space(14)
  readonly property int contentGap: Style.space(5)

  readonly property int drawerCount: drawerItems.length
  readonly property int drawerExtent: drawerCount * itemExtent

  property real revealProgress: expanded ? 1 : 0
  readonly property real revealExtent: drawerExtent * revealProgress

  Behavior on revealProgress {
    NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
  }

  function close() {
    managePopupOpen = false
    trayMenuOpen = false
  }

  function closeForPopoutSwitch() { close() }

  // --- Icones ----------------------------------------------------------------

  // Une icone « symbolic » embarque un aplat fixe, souvent presque blanc, que
  // l'hote est cense reteindre : sans cela elle disparait sur un fond clair. La
  // convention freedesktop la signale par le suffixe du nom.
  function iconIsSymbolic(icon) {
    var name = String(icon || "").split("?")[0]
    return name.slice(-9) === "-symbolic"
  }

  function itemTooltip(item) {
    return item.tooltipTitle || item.title || item.id || ""
  }

  function itemName(item) {
    var title = String(item.title || "").trim()
    if (title) return title

    var tooltip = String(item.tooltipTitle || "").trim()
    if (tooltip) return tooltip

    var itemId = String(item.id || "")
    var slash = itemId.lastIndexOf("/")
    return slash !== -1 ? itemId.substring(slash + 1) : (itemId || "Unknown")
  }

  // --- Menu contextuel -------------------------------------------------------
  // `QsMenuEntry.display()` passe par un menu de plateforme, que Quickshell
  // refuse hors mode QApplication — et le shell d'Omarchy n'y est pas. On rend
  // donc le menu nous-memes. Chaque niveau garde son propre ouvreur vivant : une
  // entree appartient au modele de son parent, replier la pile sur un seul
  // ouvreur detruirait l'entree qu'on est en train d'afficher.

  property var submenuStack: []

  readonly property int submenuDepth: submenuStack.length
  readonly property string currentTitle: submenuDepth > 0 ? submenuStack[submenuDepth - 1].title : ""
  readonly property var currentChildren: submenuDepth > 0
    ? submenuStack[submenuDepth - 1].opener.children
    : trayMenuOpener.children

  // Changer de niveau reconstruit les lignes sous un curseur qui n'a pas bouge.
  // Les clics de sous-menu ont longtemps ete sans effet, ce qui a habitue a
  // cliquer deux fois — et ce second clic tomberait maintenant sur l'entree qui
  // a pris la place. On ignore donc les clics pendant un court instant.
  property bool menuSettling: false

  Component {
    id: submenuOpenerComponent

    QsMenuOpener {}
  }

  Timer {
    id: menuSettleTimer

    interval: 250
    onTriggered: root.menuSettling = false
  }

  function settleMenu() {
    menuSettling = true
    menuSettleTimer.restart()
  }

  function resetTrayMenu() {
    menuSettling = false
    menuSettleTimer.stop()
    menuFlick.contentY = 0

    // Vider la pile reactive avant de detruire quoi que ce soit, pour qu'aucune
    // liaison ne lise un ouvreur a demi demonte. Puis detruire du plus profond
    // au plus haut : l'entree d'un ouvreur interne appartient au modele de son
    // parent, detruire le parent d'abord invaliderait ce que l'enfant lit.
    var openers = submenuStack
    submenuStack = []
    for (var i = openers.length - 1; i >= 0; i--) openers[i].opener.destroy()
  }

  function enterSubmenu(entry, title) {
    var opener = submenuOpenerComponent.createObject(root, { menu: entry })
    if (!opener) return

    var stack = submenuStack.slice()
    stack.push({ opener: opener, title: title })
    submenuStack = stack
    settleMenu()
  }

  function leaveSubmenu() {
    if (submenuStack.length === 0) return

    var stack = submenuStack.slice()
    var top = stack.pop()
    submenuStack = stack
    top.opener.destroy()
    settleMenu()
  }

  function openTrayMenu(item, anchorItem, mouse) {
    if (!item) return

    if (!item.menu) {
      var point = anchorItem.QsWindow.contentItem.mapFromItem(anchorItem, mouse.x, mouse.y)
      item.display(anchorItem.QsWindow.window, point.x, point.y)
      return
    }

    // Reinitialiser avant de changer d'item : `trayMenuOpener.menu` suit
    // `activeTrayItem.menu`, donc l'affectation invalide aussitot les enfants de
    // l'ancien menu, avant que les ouvreurs imbriques soient demontes.
    resetTrayMenu()
    activeTrayItem = item
    activeTrayAnchor = anchorItem
    trayMenuOpen = true
  }

  QsMenuOpener {
    id: trayMenuOpener

    menu: root.activeTrayItem ? root.activeTrayItem.menu : null
  }

  // --- Gabarit ---------------------------------------------------------------

  visible: pinnedItems.length > 0 || drawerCount > 0
  clip: false

  readonly property int drawerBlockExtent: allItems.length > 0 ? chevronExtent + drawerExtent : 0
  readonly property int pinnedExtent: pinnedItems.length * itemExtent
  readonly property int contentExtent: contentGap + drawerBlockExtent + pinnedExtent + contentGap

  implicitWidth: root.vertical ? islandSize : contentExtent
  implicitHeight: root.vertical ? contentExtent : islandSize

  // Le tiroir referme reserve la place ou il glissera : sans masque, la survoler
  // suffirait a l'ouvrir, et les clics n'atteindraient pas ce qu'il y a dessous.
  containmentMask: QtObject {
    function contains(point: point): bool {
      var along = root.vertical ? point.y : point.x
      var across = root.vertical ? point.x : point.y
      var thickness = root.vertical ? root.width : root.height

      if (across < 0 || across > thickness) return false

      // Le chevron se tient au bout du bloc quand tout est referme, et remonte
      // vers le debut a mesure que le tiroir s'ouvre.
      var chevronStart = root.contentGap + root.drawerExtent - root.revealExtent
      return along >= chevronStart && along <= root.contentExtent
    }
  }

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -root.haloInsetX
    anchors.rightMargin: -root.haloInsetX
    anchors.topMargin: -root.haloInsetY
    anchors.bottomMargin: -root.haloInsetY
    radius: root.islandRadius
    color: root.accentColor
    opacity: root.expanded || root.managePopupOpen ? root.accentFillOpacity : 0

    Behavior on opacity {
      NumberAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }
  }

  Loader {
    anchors.fill: parent
    sourceComponent: root.vertical ? verticalTray : horizontalTray
  }

  Component {
    id: horizontalTray

    Item {
      anchors.fill: parent

      Item {
        id: drawerArea

        x: root.contentGap
        width: root.drawerBlockExtent
        height: parent.height
        visible: root.allItems.length > 0

        HoverHandler {
          onHoveredChanged: root.expanded = hovered
        }

        Chevron {
          x: root.drawerExtent - root.revealExtent
          anchors.verticalCenter: parent.verticalCenter
        }

        Item {
          x: root.chevronExtent
          width: root.drawerExtent
          height: parent.height
          clip: true

          Row {
            x: root.drawerExtent - root.revealExtent
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Repeater {
              model: root.drawerItems

              TrayItem {}
            }
          }
        }
      }

      Row {
        x: root.contentGap + root.drawerBlockExtent
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Repeater {
          model: root.pinnedItems

          TrayItem {}
        }
      }
    }
  }

  Component {
    id: verticalTray

    Item {
      anchors.fill: parent

      Item {
        id: drawerArea

        y: root.contentGap
        width: parent.width
        height: root.drawerBlockExtent
        visible: root.allItems.length > 0

        HoverHandler {
          onHoveredChanged: root.expanded = hovered
        }

        Chevron {
          y: root.drawerExtent - root.revealExtent
          anchors.horizontalCenter: parent.horizontalCenter
          glyphRotation: 90
        }

        Item {
          y: root.chevronExtent
          width: parent.width
          height: root.drawerExtent
          clip: true

          Column {
            y: root.drawerExtent - root.revealExtent
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0

            Repeater {
              model: root.drawerItems

              TrayItem {}
            }
          }
        }
      }

      Column {
        y: root.contentGap + root.drawerBlockExtent
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0

        Repeater {
          model: root.pinnedItems

          TrayItem {}
        }
      }
    }
  }

  // --- Composants ------------------------------------------------------------

  component Chevron: Item {
    id: chevron

    property int glyphRotation: 0

    width: root.vertical ? parent.width : root.chevronExtent
    height: root.vertical ? root.chevronExtent : parent.height

    Text {
      anchors.centerIn: parent
      text: ""
      rotation: chevron.glyphRotation
      color: root.expanded ? root.accentColor : root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      renderType: Text.NativeRendering

      Behavior on color { ColorAnimation { duration: root.revealDuration } }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: root.managePopupOpen = !root.managePopupOpen
    }
  }

  // Rend une icone de tray, en reteignant les symboliques a la couleur de la
  // barre : laissee telle quelle, une symbolique garde son aplat d'origine et
  // s'efface sur un fond de meme teinte.
  component TrayIcon: Item {
    id: trayIcon

    required property var icon

    readonly property bool symbolic: root.iconIsSymbolic(icon)

    Image {
      id: iconImage

      anchors.fill: parent
      fillMode: Image.PreserveAspectFit
      // Decodage a la resolution physique : dimensionner en pixels logiques
      // laisse les PNG flous sur un ecran HiDPI.
      sourceSize.width: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
      sourceSize.height: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
      // Quickshell resout deja l'icone en une URL image:// utilisable telle
      // quelle, avec son repli "?path=" pour les applications qui rangent leur
      // icone hors des themes standard.
      source: String(trayIcon.icon || "")
      visible: !trayIcon.symbolic
      layer.enabled: trayIcon.symbolic
    }

    MultiEffect {
      anchors.fill: iconImage
      source: iconImage
      visible: trayIcon.symbolic
      colorization: 1.0
      colorizationColor: root.foregroundColor
    }
  }

  component TrayItem: Item {
    id: trayItem

    required property var modelData

    readonly property bool tooltipHovered: visible && itemArea.containsMouse

    visible: modelData.status !== Status.Passive
    implicitWidth: visible ? root.itemExtent : 0
    implicitHeight: visible ? root.itemExtent : 0

    function displayMenu(mouse) {
      root.openTrayMenu(trayItem.modelData, trayItem, mouse)
    }

    TrayIcon {
      anchors.centerIn: parent
      width: Style.space(12)
      height: Style.space(12)
      icon: trayItem.modelData.icon
    }

    MouseArea {
      id: itemArea

      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: if (root.bar) root.bar.showTooltip(trayItem, root.itemTooltip(trayItem.modelData))
      onExited: if (root.bar) root.bar.hideTooltip(trayItem)
      onPressed: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          trayItem.displayMenu(mouse)
          mouse.accepted = true
        }
      }
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) mouse.accepted = true
        else if (mouse.button === Qt.MiddleButton) trayItem.modelData.secondaryActivate()
        else if (trayItem.modelData.onlyMenu) trayItem.displayMenu(mouse)
        else trayItem.modelData.activate()
      }
      onWheel: function(wheel) {
        trayItem.modelData.scroll(wheel.angleDelta.y, false)
      }
    }
  }

  // --- Panneau de gestion ----------------------------------------------------

  PopupCard {
    id: managePopup

    anchorItem: root
    owner: root
    bar: root.bar
    open: root.managePopupOpen
    contentWidth: managePopup.fittedContentWidth(Style.space(320))
    contentHeight: managePopup.fittedContentHeight(manageColumn.implicitHeight)

    Column {
      id: manageColumn

      anchors.fill: parent
      spacing: Style.space(8)

      Text {
        text: "Background apps"
        color: root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Text {
        text: "Pinned icons stay visible. Hidden icons never show."
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
        width: parent.width
      }

      Text {
        visible: root.allItems.length === 0
        text: "Nothing running in the background"
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.italic: true
      }

      Repeater {
        model: root.allItems

        delegate: Rectangle {
          id: manageRow

          required property var modelData

          readonly property string itemId: String(modelData.id || "")
          readonly property bool isPinned: root.pinnedIds.indexOf(itemId) !== -1
          readonly property bool isHidden: root.hiddenIds.indexOf(itemId) !== -1

          width: manageColumn.width
          implicitHeight: Style.space(32)
          radius: Style.cornerRadius
          color: root.islandFill

          TrayIcon {
            id: manageIcon

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            width: Style.space(16)
            height: Style.space(16)
            icon: manageRow.modelData.icon
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: manageIcon.right
            anchors.leftMargin: Style.space(10)
            anchors.right: hideButton.left
            anchors.rightMargin: Style.space(8)
            text: root.itemName(manageRow.modelData)
            color: manageRow.isHidden ? root.mutedColor : root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          ManageAction {
            id: pinButton

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Style.space(8)
            label: manageRow.isPinned ? "Unpin" : "Pin"
            highlighted: manageRow.isPinned
            onTriggered: root.togglePin(manageRow.itemId)
          }

          ManageAction {
            id: hideButton

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: pinButton.left
            anchors.rightMargin: Style.space(6)
            label: manageRow.isHidden ? "Show" : "Hide"
            highlighted: manageRow.isHidden
            onTriggered: root.toggleHide(manageRow.itemId)
          }
        }
      }
    }
  }

  component ManageAction: Rectangle {
    id: manageAction

    property string label: ""
    property bool highlighted: false

    signal triggered()

    width: actionLabel.implicitWidth + Style.space(16)
    height: Style.space(22)
    radius: Style.cornerRadius
    color: actionArea.containsMouse || manageAction.highlighted ? root.accentFill : "transparent"

    Behavior on color {
      ColorAnimation { duration: root.revealDuration; easing.type: root.revealEasing }
    }

    Text {
      id: actionLabel

      anchors.centerIn: parent
      text: manageAction.label
      color: manageAction.highlighted ? root.accentColor : root.foregroundColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    MouseArea {
      id: actionArea

      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: manageAction.triggered()
    }
  }

  // --- Menu de l'application -------------------------------------------------

  PopupCard {
    id: trayMenuPopup

    anchorItem: root.activeTrayAnchor || root
    owner: root
    bar: root.bar
    open: root.trayMenuOpen
    padding: Style.space(8)
    contentWidth: trayMenuPopup.fittedContentWidth(Style.space(240))
    contentHeight: trayMenuPopup.fittedContentHeight(menuHeaderHeight + menuColumn.implicitHeight, Style.space(420))

    // La carte s'efface en fondu et reste visible le temps de celui-ci :
    // reinitialiser sur `open` echangerait un sous-menu vivant contre le menu
    // racine en plein fondu — un clignotement, et un saut de geometrie si les
    // deux niveaux n'ont pas la meme taille. Changer d'item, lui, reinitialise
    // tout de suite, depuis `openTrayMenu()`.
    onVisibleChanged: if (!visible) root.resetTrayMenu()

    // `Column` saute ses enfants invisibles mais continue d'annoncer leur
    // hauteur : on lit donc celle de l'entete a travers sa propre visibilite.
    readonly property int menuHeaderHeight: menuHeader.visible ? menuHeader.implicitHeight : 0

    Column {
      id: menuLayout

      anchors.fill: parent
      spacing: 0

      // Entete d'un sous-menu : dit ou l'on est et ramene en arriere. Pose
      // au-dessus du defilement plutot qu'emporte avec les lignes, pour que la
      // sortie reste atteignable dans un sous-menu plus haut que la carte.
      Column {
        id: menuHeader

        visible: root.submenuDepth > 0
        width: menuLayout.width
        spacing: 0

        Rectangle {
          width: menuHeader.width
          implicitHeight: Style.space(30)
          radius: Style.cornerRadius
          color: backArea.containsMouse ? root.accentFill : "transparent"

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: Style.space(22)
            horizontalAlignment: Text.AlignHCenter
            text: "‹"
            color: root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(28)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            text: root.currentTitle
            color: root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          MouseArea {
            id: backArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.menuSettling) return

              menuFlick.contentY = 0
              root.leaveSubmenu()
            }
          }
        }

        Rectangle {
          width: menuHeader.width
          height: Math.max(1, Style.spacing.hairline)
          color: root.islandFill
        }
      }

      Flickable {
        id: menuFlick

        width: menuLayout.width
        height: menuLayout.height - trayMenuPopup.menuHeaderHeight
        contentWidth: width
        contentHeight: menuColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: menuColumn

          width: menuFlick.width
          spacing: 0

          Repeater {
            model: root.currentChildren

            delegate: Item {
              id: menuRow

              required property var modelData
              required property int index

              readonly property string rowText: String(modelData.text || "")
              readonly property string activeTitle: root.activeTrayItem
                ? String(root.activeTrayItem.title || root.activeTrayItem.id || "")
                : ""

              // Les deux ne decrivent que le menu racine : dans un sous-menu les
              // premieres lignes sont de vraies entrees, a ne pas avaler.
              readonly property bool atRoot: root.submenuDepth === 0
              readonly property bool titleEntry: atRoot && index === 0 && modelData.hasChildren
                && rowText.toLowerCase() === activeTitle.toLowerCase()
              readonly property bool leadingSeparator: atRoot && modelData.isSeparator && index <= 1
              readonly property bool skipped: titleEntry || leadingSeparator

              visible: !skipped
              width: menuColumn.width
              implicitHeight: skipped ? 0 : (modelData.isSeparator ? Style.space(11) : Style.space(30))
              opacity: modelData.enabled ? 1 : 0.45

              Rectangle {
                visible: menuRow.modelData.isSeparator
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                height: Math.max(1, Style.spacing.hairline)
                color: root.islandFill
              }

              Rectangle {
                visible: !menuRow.modelData.isSeparator
                anchors.fill: parent
                radius: Style.cornerRadius
                color: rowArea.containsMouse && menuRow.modelData.enabled ? root.accentFill : "transparent"
              }

              Text {
                visible: !menuRow.modelData.isSeparator
                  && menuRow.modelData.buttonType !== QsMenuButtonType.None
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                width: Style.space(22)
                horizontalAlignment: Text.AlignHCenter
                text: menuRow.modelData.checkState === Qt.Checked ? "" : ""
                color: root.accentColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Image {
                id: rowIcon

                visible: !menuRow.modelData.isSeparator && String(menuRow.modelData.icon || "") !== ""
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.space(24)
                width: Style.space(16)
                height: Style.space(16)
                fillMode: Image.PreserveAspectFit
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio
                source: menuRow.modelData.icon
              }

              Text {
                visible: !menuRow.modelData.isSeparator
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: rowIcon.visible ? Style.space(46) : Style.space(28)
                anchors.right: submenuGlyph.left
                anchors.rightMargin: Style.space(8)
                text: menuRow.rowText
                color: root.foregroundColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Text {
                id: submenuGlyph

                visible: !menuRow.modelData.isSeparator && menuRow.modelData.hasChildren
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                text: "›"
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: rowArea

                anchors.fill: parent
                hoverEnabled: true
                enabled: !menuRow.modelData.isSeparator && menuRow.modelData.enabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (root.menuSettling) return

                  if (menuRow.modelData.hasChildren) {
                    // Remettre le defilement AVANT d'echanger le modele : cet
                    // echange detruit la delegation sur-le-champ, et les ids
                    // cessent d'y resoudre ensuite.
                    menuFlick.contentY = 0
                    root.enterSubmenu(menuRow.modelData, menuRow.rowText)
                  } else {
                    menuRow.modelData.triggered()
                    root.close()
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
