import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Cloche de notifications : l'archive au clic gauche, DND au clic droit, balayage
// des toasts a l'ecran au clic milieu.
//
// Omarchy 4 a remplace le centre de notifications par un couple « toasts vivants
// + historique sur disque » : `pendingModel`, `pastModel`, `markAllSeen`,
// `clearPast`, `dismissPending` et `dismissPast` ont disparu du service. Il ne
// reste que `popupModel` — ce qui est affiche a l'instant — et un historique de
// DIX fichiers dans ~/.local/state/omarchy/notifications/history/, que le service
// sait rejouer mais pas rendre en liste. Dix, c'est le bon compte pour rejouer ce
// qu'on vient de manquer ; c'est tres loin du compte pour repondre a « c'etait
// quoi, deja ».
//
// D'ou l'archive tenue par `local.notifications` : elle recopie chaque fichier
// des qu'il apparait et le garde trente jours, icone comprise. Ce widget en est
// la vue. Il ne detient aucun etat propre a l'archive — elle vit dans le plugin
// `service`, instancie une fois pour tout le shell, la ou cette barre l'est une
// fois par ecran ; un « tout marquer lu » pose ici ne vaudrait que pour l'ecran
// ou l'on a clique.
//
// Le daemon reste celui d'Omarchy. `PluginRegistry.isEnabled()` renvoie
// inconditionnellement `true` pour tout plugin first-party non-bar : il n'existe
// aucun moyen de couper `omarchy.notifications`, et deux NotificationServer se
// disputeraient org.freedesktop.Notifications. Ce widget se contente donc de
// piloter le service ; les toasts restent rendus par `local.notifications`.
BarWidget {
  id: root
  moduleName: "local.menubar.notifications"

  // --- Contrat de style ------------------------------------------------------

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
  readonly property color islandFill: Qt.rgba(foregroundColor.r, foregroundColor.g, foregroundColor.b, 0.06)

  readonly property string barPosition: bar ? bar.position : "top"
  readonly property bool barVertical: barPosition === "left" || barPosition === "right"
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

  // La barre le resout deja pour elle-meme ; on retombe sur l'environnement
  // si jamais une autre barre venait a heberger ce widget.
  readonly property string omarchyPath: bar && bar.omarchyPath
    ? bar.omarchyPath : Quickshell.env("OMARCHY_PATH")

  // --- Reglages --------------------------------------------------------------
  //
  // `local.menubar` est un plugin `kind: bar` : ses widgets sont instancies en dur
  // par Bar.qml, il n'y a donc pas d'entree de layout dans shell.json d'ou tirer
  // des reglages, et pas de formulaire genere comme en aurait un `bar-widget`.
  // On passe quand meme par `setting()` — ca ne coute rien et ca cable le jour ou
  // la cloche deviendrait un plugin a part — et Bar.qml peut surcharger chaque
  // valeur a l'instanciation : `Notifications { bar: root; badge: "Count" }`.

  // Ce que la cloche dit des notifications arrivees depuis la derniere ouverture.
  // « Dot » repond a la question qu'on pose vraiment a une barre — y en a-t-il ;
  // « Count » dit combien, et fait de la cloche quelque chose qu'on lit plutot
  // qu'on ne regarde ; « Highlight » n'ajoute rien a cote et colore la cloche
  // elle-meme, ce qui est la facon dont le reste de la barre dit deja qu'une chose
  // reclame l'attention, et la seule qui laisse la rangee d'icones exactement de
  // la forme qu'elle avait.
  property string badge: setting("badge", "Dot")
  // Jours. Au-dela, une notification est supprimee avec l'icone gardee pour elle.
  // C'est le reglage qui limite les degats : l'archive, c'est tout ce qu'on a
  // recu, messages et codes a usage unique compris.
  property int keepDays: setting("keepDays", 30)
  property int maxItems: setting("maxItems", 1000)
  // « Auto » ouvre l'image que la notification designait, et sinon donne le focus
  // a l'application qui l'a envoyee. Jamais la commande dont la notification etait
  // porteuse : voir `activate()`.
  property string clickAction: setting("clickAction", "Auto")
  property bool showBody: setting("showBody", true)
  property bool showPreview: setting("showPreview", true)
  property int panelWidth: setting("panelWidth", 380)

  // --- Service natif ---------------------------------------------------------

  readonly property var hostShell: bar && bar.shell ? bar.shell : null
  readonly property var service: hostShell && typeof hostShell.firstPartyServiceFor === "function"
    ? hostShell.firstPartyServiceFor("omarchy.notifications")
    : null

  // Ce qui est affiche a l'instant. Sert au glyphe et au balayage, pas au compte
  // de non-lus — celui-la vient de l'archive.
  readonly property int liveCount: service && service.popupModel ? service.popupModel.count : 0
  readonly property bool dnd: service ? service.doNotDisturb : false

  function toggleDnd() {
    if (service) service.setDoNotDisturb(!service.doNotDisturb)
  }

  // Retire les toasts de l'ecran. L'archive n'est pas touchee : un balayage se
  // defait d'un clic, alors qu'oublier l'archive est definitif.
  function dismissAll() {
    if (service) service.clearPopups()
  }

  // --- L'archive -------------------------------------------------------------
  //
  // Tenue par `local.notifications`, pas par ce widget. On s'y attache au premier
  // moment ou `bar.shell` est resolu, et on reessaie : l'ordre de chargement des
  // plugins n'est pas garanti d'un demarrage a l'autre.

  property var store: null

  function bindStore() {
    if (store) {
      pushSettings()
      return
    }
    if (!hostShell || typeof hostShell.serviceFor !== "function") return
    var owner = hostShell.serviceFor("local.notifications")
    if (!owner || !owner.archive) return
    store = owner.archive
    pushSettings()
    rebuild()
  }

  function pushSettings() {
    if (!store) return
    store.keepDays = keepDays
    store.maxItems = maxItems
    store.showPreview = showPreview
  }

  onHostShellChanged: bindStore()
  onKeepDaysChanged: pushSettings()
  onMaxItemsChanged: pushSettings()
  onShowPreviewChanged: pushSettings()

  Timer {
    interval: 200
    running: root.store === null
    repeat: true
    onTriggered: root.bindStore()
  }

  Connections {
    target: root.store
    function onEntryAdded(entry) { root.handleEntryAdded(entry) }
    function onEntriesReset() { root.rebuild() }
  }

  readonly property var entries: store ? store.entries : []
  readonly property int unread: store ? store.unread : 0
  readonly property double lastSeen: store ? store.lastSeen : 0
  readonly property bool loaded: store ? store.loaded : false

  // --- Etat du panneau -------------------------------------------------------

  property bool opened: false
  property string filter: ""
  property bool searching: false
  property int hoverIndex: -1
  property bool clearArmed: false

  // Ce contre quoi les cartes sont marquees. Ouvrir le centre rend tout lu :
  // marquer contre `lastSeen` voudrait dire que la liste ne montre jamais ce
  // qu'on n'avait pas lu, parce que les marques auraient disparu avant meme
  // qu'elle finisse de se dessiner. On garde ici la lecture de l'instant d'avant
  // l'ouverture — c'est la question qu'on se posait.
  property double readMark: 0

  function open() { opened = true }

  function close() {
    opened = false
    endSearch()
    clearArmed = false
    hoverIndex = -1
  }

  function toggle() { opened ? close() : open() }

  function closeForPopoutSwitch() { close() }

  onOpenedChanged: {
    if (!opened) return
    if (store) store.load()
    readMark = lastSeen
    if (store) store.markSeen()
  }

  function startSearch() {
    searching = true
    searchField.forceActiveFocus()
  }

  function endSearch() {
    searching = false
    filter = ""
    searchField.text = ""
  }

  // --- La liste --------------------------------------------------------------

  ListModel { id: rows }

  function matches(entry) {
    if (filter === "") return true
    var needle = filter.toLowerCase()
    return String(entry.app || "").toLowerCase().indexOf(needle) >= 0
        || String(entry.summary || "").toLowerCase().indexOf(needle) >= 0
        || String(entry.body || "").toLowerCase().indexOf(needle) >= 0
  }

  function rowFor(entry) {
    var stamp = Number(entry.timestamp || 0)
    return {
      key: String(entry.key || ""),
      app: String(entry.app || ""),
      appIcon: String(entry.appIcon || ""),
      summary: String(entry.summary || ""),
      body: String(entry.body || ""),
      image: String(entry.image || ""),
      preview: String(entry.preview || ""),
      file: String(entry.file || ""),
      glyph: String(entry.glyph || ""),
      urgency: Number(entry.urgency || 0),
      timestamp: stamp,
      day: dayOf(stamp),
      time: Qt.formatDateTime(new Date(stamp), "HH:mm")
    }
  }

  function rebuild() {
    rows.clear()
    for (var i = 0; i < entries.length; i++)
      if (matches(entries[i])) rows.append(rowFor(entries[i]))
  }

  // Une entree qui arrive pendant que le panneau est ouvert se glisse en tete
  // plutot que de faire reconstruire toute la liste sous le curseur.
  function handleEntryAdded(entry) {
    if (!matches(entry)) return
    rows.insert(0, rowFor(entry))
  }

  onFilterChanged: rebuild()

  // L'en-tete sous lequel une notification est rangee. Des journees et non des
  // heures : ce dont on se souvient d'une notification qu'on cherche, c'est le
  // jour ou elle est arrivee — et une liste decoupee a l'heure est une liste
  // surtout faite d'en-tetes.
  function dayOf(timestamp) {
    var when = new Date(timestamp)
    var now = new Date()
    var midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
    if (timestamp >= midnight) return "Aujourd'hui"
    if (timestamp >= midnight - 86400000) return "Hier"
    // Dans la semaine, le jour de la semaine est la meilleure poignee :
    // « mardi » est la facon dont on s'en souvient, « 17 aout » celle dont il
    // faudrait le deduire.
    if (timestamp >= midnight - 6 * 86400000) return Qt.formatDateTime(when, "dddd")
    if (when.getFullYear() === now.getFullYear()) return Qt.formatDateTime(when, "d MMMM")
    return Qt.formatDateTime(when, "d MMMM yyyy")
  }

  function removeRow(key) {
    if (!key || !store) return
    for (var i = 0; i < rows.count; i++) {
      if (rows.get(i).key === key) { rows.remove(i); break }
    }
    store.remove(key)
  }

  function clearAll() {
    if (store) store.clearAll()
    clearArmed = false
  }

  // --- Activation ------------------------------------------------------------
  //
  // Ce qu'un clic sur une vieille notification doit faire.
  //
  // Pas ce que la notification demandait. Une notification arrive porteuse d'une
  // commande, choisie par celui qui l'envoie, et n'importe quel process du bus de
  // session peut en envoyer une — le commentaire de
  // `NotificationLogic.parseExecArgv()` en amont le dit sans detour : c'est
  // « equivalent to same-uid code execution ». Garder cette commande pour la
  // lancer plus tard, c'est deposer la commande d'un attaquant en attente d'un
  // clic, et ca ne vaut rien a cote de la seule chose qu'on veut vraiment
  // retrouver : l'image. Ce que le magasin garde est donc au plus un chemin
  // absolu vers une image ; il est ouvert par argument et non a travers un shell,
  // si bien qu'un chemin hostile est un fichier qui refuse de s'ouvrir plutot
  // qu'une commande qui s'execute.
  //
  // Le magasin filtre deja ce chemin a l'ingestion. On le refiltre ici : c'est la
  // meme regle ecrite deux fois, et le jour ou l'une des deux se relache, l'autre
  // tient encore.
  function isOpenableImage(path) {
    return /^\/[^\r\n"']*\.(jpe?g|png|webp|gif)$/i.test(String(path || ""))
  }

  function focusApp(app) {
    var name = String(app || "")
    // Le nom d'application est porte par la notification, donc choisi par
    // l'emetteur, et `omarchy-hyprland-focus-app` s'en sert comme d'une
    // expression reguliere : une application qui se nommerait « .* » prendrait le
    // focus de la premiere fenetre venue. Seul ce qui a la forme d'un nom passe.
    if (!/^[A-Za-z0-9][A-Za-z0-9 ._+-]*$/.test(name)) return
    if (!omarchyPath) return
    Quickshell.execDetached([omarchyPath + "/bin/omarchy-hyprland-focus-app", name])
  }

  function activate(row) {
    if (!row || clickAction === "Nothing") return

    if (clickAction === "Auto" && isOpenableImage(row.file)) {
      Quickshell.execDetached(["xdg-open", String(row.file)])
      close()
      return
    }

    focusApp(row.app)
    close()
  }

  // --- IPC -------------------------------------------------------------------

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
    function dismiss(): void { root.dismissAll() }
    function clear(): void { root.clearAll() }
  }

  // --- Bouton de barre -------------------------------------------------------

  readonly property string glyph: {
    if (dnd) return "󰂛"
    if (badge !== "None" && unread > 0) return "󱅫"
    if (liveCount > 0) return "󱅫"
    return "󰂚"
  }

  readonly property string tooltip: {
    if (dnd) return unread > 0 ? "Ne pas deranger · " + unread + " non lues" : "Ne pas deranger"
    if (unread === 1) return "1 notification non lue"
    if (unread > 1) return unread + " notifications non lues"
    return "Notifications"
  }

  // Meme gabarit que Network et Displays : une boite de glyphe de largeur fixe
  // entre deux gouttieres egales. La largeur fixe compte ici plus qu'ailleurs —
  // le glyphe change avec l'etat, et un cadre elastique ferait tressauter l'ilot
  // a chaque notification recue. Pour la meme raison la pastille est posee PAR
  // DESSUS la cloche et jamais a cote : une barre qui change de largeur a chaque
  // message est une barre qui tressaute toute la journee.
  readonly property int glyphWidth: Style.space(14)
  readonly property int contentGap: Style.space(5)
  readonly property bool highlighted: button.containsMouse || opened

  // Lu par le filet de securite de la barre, qui repose le tooltip si sa cible
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
    id: glyphLabel

    x: root.contentGap
    width: root.glyphWidth
    text: root.glyph
    // Non lu ou toast a l'ecran : le glyphe prend l'accent, comme un workspace
    // actif. En DND il s'eteint sur l'encre secondaire — le mode est volontaire,
    // il n'a pas a reclamer l'attention.
    color: {
      if (root.dnd) return root.mutedColor
      if (root.badge === "Highlight" && root.unread > 0) return root.accentColor
      return root.liveCount > 0 ? root.accentColor : root.foregroundColor
    }
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    anchors.verticalCenter: parent.verticalCenter

    Behavior on color { ColorAnimation { duration: root.revealDuration } }
  }

  // La pastille : posee sur le glyphe, pas a cote.
  Rectangle {
    visible: root.badge === "Dot" && root.unread > 0 && !root.dnd
    anchors.right: glyphLabel.right
    anchors.top: glyphLabel.top
    anchors.topMargin: -Style.space(1)
    width: Style.space(5)
    height: width
    radius: width / 2
    color: root.accentColor
  }

  Rectangle {
    visible: root.badge === "Count" && root.unread > 0 && !root.dnd
    anchors.right: glyphLabel.right
    anchors.rightMargin: -Style.space(2)
    anchors.top: glyphLabel.top
    anchors.topMargin: -Style.space(2)
    width: Math.max(countText.implicitWidth + Style.space(5), Style.space(11))
    height: Style.space(11)
    radius: height / 2
    color: root.accentColor

    Text {
      id: countText
      anchors.centerIn: parent
      // Passe quatre-vingt-dix-neuf le nombre a cesse d'etre une information et
      // la pastille ne dit plus que « beaucoup », ce qu'elle peut dire en trois
      // caracteres.
      text: root.unread > 99 ? "99+" : String(root.unread)
      textFormat: Text.PlainText
      font.family: root.fontFamily
      font.pixelSize: Math.max(8, Style.font.caption - Style.space(3))
      font.bold: true
      color: root.bar ? root.bar.background : Color.background
    }
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
      // Clic droit : on fait taire sans rien ouvrir. Decider qu'on veut le calme
      // et vouloir lire l'arriere sont deux elans opposes.
      if (mouse.button === Qt.RightButton) root.toggleDnd()
      else if (mouse.button === Qt.MiddleButton) root.dismissAll()
      else root.toggle()
    }
  }

  // Le point d'accroche du panneau : une largeur nulle tres au-dela du bord droit
  // de tout ecran. Invisible, absent de la mise en page, lu pour sa seule
  // position. KeyboardPanel ramene sa carte dans l'ecran, donc une ancre posee
  // la-bas se resout toujours contre le bord droit, quoi qu'il advienne de
  // l'ordre des widgets. C'est le seul panneau de la barre a avoir un domicile
  // fixe : un centre de notifications qui s'ouvrirait a un endroit different
  // selon le nombre de widgets a sa gauche serait un centre qu'il faut chercher.
  Item {
    id: rightAnchor
    anchors.top: button.top
    anchors.bottom: button.bottom
    x: 1000000
    width: 1
    visible: false
  }

  // --- Panneau ---------------------------------------------------------------

  KeyboardPanel {
    id: panel

    // Sur une barre verticale le panneau se pose deja contre elle : l'ancre
    // lointaine n'aurait rien a corriger et eloignerait la carte du bouton.
    anchorItem: root.barVertical ? button : rightAnchor
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(root.panelWidth))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      // Tant que le champ de recherche a le focus, il possede toutes les touches,
      // y compris celles que ceci lirait comme de la navigation.
      blocked: root.searching

      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) { list.flick(0, dy > 0 ? -900 : 900) }
      onTextKey: function(text) {
        // « / » est la seule touche qui ouvre la recherche. Un panneau qui se
        // mettrait a filtrer a n'importe quelle frappe serait un panneau qui
        // avale ce qu'on etait en train de taper dans la fenetre du dessous.
        if (text === "/") root.startSearch()
      }

      Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(8)

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

        // ---- En-tete ----
        Item {
          id: header

          width: parent.width
          implicitHeight: Style.space(24)

          Text {
            id: headerTitle

            text: "Notifications"
            color: root.foregroundColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
            anchors.left: parent.left
            anchors.leftMargin: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: rows.count > 0 ? String(rows.count) : ""
            color: root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            anchors.left: headerTitle.right
            anchors.leftMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            // La cloche de l'en-tete, c'est « ne pas deranger » — le meme
            // interrupteur que celui de la barre.
            HeaderButton {
              glyph: root.dnd ? "󰂛" : "󰂚"
              tint: root.dnd ? root.accentColor : root.foregroundColor
              onTriggered: root.toggleDnd()
            }

            HeaderButton {
              glyph: "󰍉"
              tint: root.searching ? root.accentColor : root.foregroundColor
              onTriggered: root.searching ? root.endSearch() : root.startSearch()
            }

            // Vider demande deux fois : le premier clic arme, le second execute,
            // et l'armement retombe seul au bout de trois secondes. Effacer
            // l'archive est definitif, et le bouton est a un centimetre de la
            // recherche.
            HeaderButton {
              glyph: root.clearArmed ? "󰅚" : "󰩹"
              tint: root.clearArmed ? root.accentColor : root.mutedColor
              enabled: rows.count > 0
              onTriggered: {
                if (root.clearArmed) root.clearAll()
                else { root.clearArmed = true; disarm.restart() }
              }
            }
          }
        }

        Timer {
          id: disarm
          interval: 3000
          onTriggered: root.clearArmed = false
        }

        // ---- Recherche ----
        TextField {
          id: searchField

          width: parent.width
          visible: root.searching
          foreground: root.foregroundColor
          accent: root.accentColor
          font.family: root.fontFamily
          placeholderText: "Rechercher"

          onTextChanged: root.filter = text
          Keys.onEscapePressed: root.endSearch()
          // Les fleches doivent faire defiler la liste, pas deplacer le curseur
          // de saisie : c'est la liste qu'on parcourt, meme en cherchant.
          Keys.onDownPressed: list.flick(0, -900)
          Keys.onUpPressed: list.flick(0, 900)
        }

        // ---- Liste ----
        ListView {
          id: list

          width: parent.width
          // 0 laisse la liste courir jusqu'en bas de l'ecran, la ou macOS termine
          // sa colonne de notifications. Le plafond, c'est ce qui reste de l'ecran
          // une fois que l'en-tete, la recherche et le pied ont eu leur part — la
          // recherche comptee qu'elle soit affichee ou non, pour que l'ouvrir ne
          // pousse pas le pied hors de la carte.
          readonly property int cap: {
            var chrome = header.implicitHeight + searchField.implicitHeight
                       + foot.implicitHeight + content.spacing * 3
            return Math.max(Style.space(240),
                            panel.availableCardHeight - panel.verticalContentInset - chrome)
          }

          height: Math.min(contentHeight, cap)
          visible: rows.count > 0
          clip: true
          model: rows
          spacing: Style.space(6)
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          // La barre de defilement recoit un couloir a elle sur la droite. La
          // partager avec les cartes la pose sur la croix de fermeture au coin de
          // chacune d'elles, et le bouton qu'on vise est celui qu'on rate.
          readonly property real lane: Style.space(10)

          section.property: "day"
          section.criteria: ViewSection.FullString
          section.delegate: Item {
            id: daySection

            required property string section
            width: list.width - list.lane
            height: dayLabel.implicitHeight + Style.space(12)

            PanelSectionHeader {
              id: dayLabel

              text: daySection.section.toUpperCase()
              foreground: root.foregroundColor
              fontFamily: root.fontFamily
              anchors.left: parent.left
              anchors.leftMargin: Style.space(2)
              anchors.bottom: parent.bottom
              anchors.bottomMargin: Style.space(3)
            }
          }

          delegate: NotificationRow {
            required property var model
            required property int index

            width: list.width - list.lane
            entry: model
            rowIndex: index
          }
        }

        // ---- Etat vide ----
        Item {
          width: parent.width
          visible: rows.count === 0
          implicitHeight: Style.space(72)

          Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            color: root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            text: {
              if (!root.loaded) return "Lecture de l'archive…"
              if (root.filter !== "") return "Aucun resultat pour « " + root.filter + " »"
              return "Rien pour l'instant"
            }
          }
        }

        // ---- Pied ----
        Item {
          id: foot

          width: parent.width
          implicitHeight: Style.space(16)

          Text {
            text: {
              if (root.dnd) return "Silencieux · gardees " + root.keepDays + " jours"
              return "Gardees " + root.keepDays + " jours"
            }
            color: root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            anchors.left: parent.left
            anchors.leftMargin: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            text: root.clearArmed ? "Encore un clic pour tout effacer" : "« / » pour chercher"
            color: root.clearArmed ? root.accentColor : root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            anchors.right: parent.right
            anchors.rightMargin: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }

  // --- Composants ------------------------------------------------------------

  component HeaderButton: CursorSurface {
    id: headerButton

    property string glyph: ""
    property color tint: root.foregroundColor

    signal triggered()

    width: Style.space(22)
    height: Style.space(20)
    hasCursor: headerHover.hovered && headerButton.enabled
    foreground: root.foregroundColor
    accent: root.accentColor
    opacity: headerButton.enabled ? 1 : 0.35

    HoverHandler { id: headerHover; enabled: headerButton.enabled }

    Text {
      anchors.centerIn: parent
      text: headerButton.glyph
      color: headerButton.tint
      font.family: root.fontFamily
      font.pixelSize: Style.font.icon
      renderType: Text.NativeRendering
    }

    MouseArea {
      anchors.fill: parent
      enabled: headerButton.enabled
      cursorShape: Qt.PointingHandCursor
      onClicked: headerButton.triggered()
    }
  }

  component NotificationRow: CursorSurface {
    id: row

    required property var entry
    required property int rowIndex

    readonly property bool unseen: Number(entry.timestamp || 0) > root.readMark
    readonly property bool critical: Number(entry.urgency || 0) === 2
    readonly property string iconSource: {
      var image = String(entry.image || "")
      if (image.length > 0) return resolveIcon(image)
      return resolveIcon(String(entry.appIcon || ""))
    }
    readonly property bool hasGlyph: String(entry.glyph || "").length > 0
    readonly property string previewSource: root.showPreview ? String(entry.preview || "") : ""
    readonly property bool hasPreview: previewSource.length > 0
    readonly property string bodyText: root.showBody ? String(entry.body || "") : ""

    function resolveIcon(icon) {
      var value = String(icon || "")
      if (value.length === 0) return ""
      if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
      if (value.charAt(0) === "/") return Util.fileUrl(value)
      return Quickshell.iconPath(value, true)
    }

    implicitHeight: rowBody.implicitHeight + Style.space(14)
    height: implicitHeight
    hasCursor: root.hoverIndex === rowIndex
    // Une critique garde son aplat en permanence : seule distinction d'urgence
    // que la barre pratique elle aussi.
    current: critical
    foreground: root.foregroundColor
    accent: root.accentColor

    HoverHandler {
      onHoveredChanged: root.hoverIndex = hovered ? row.rowIndex : -1
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: root.clickAction === "Nothing" ? Qt.ArrowCursor : Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        // Clic droit : on l'oublie. Meme geste que la croix, sans avoir a viser.
        if (mouse.button === Qt.RightButton) root.removeRow(String(row.entry.key))
        else root.activate(row.entry)
      }
    }

    // Le point de non-lu, dans la gouttiere gauche : il ne prend pas de place aux
    // cartes, et la colonne qu'il forme se lit d'un coup d'oeil.
    Rectangle {
      visible: row.unseen
      width: Style.space(4)
      height: width
      radius: width / 2
      color: root.accentColor
      anchors.left: parent.left
      anchors.leftMargin: Style.space(3)
      anchors.top: parent.top
      anchors.topMargin: Style.space(13)
    }

    Column {
      id: rowBody

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: Style.space(11)
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(3)

      // Ligne de tete : icone, application, heure, croix.
      Item {
        width: parent.width
        implicitHeight: Style.space(14)

        Image {
          id: rowIcon

          visible: row.iconSource.length > 0 && status !== Image.Error
          source: row.iconSource
          width: Style.space(12)
          height: width
          sourceSize.width: width * Screen.devicePixelRatio
          sourceSize.height: height * Screen.devicePixelRatio
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          id: rowGlyph

          visible: row.hasGlyph && !rowIcon.visible
          text: String(row.entry.glyph || "")
          color: row.critical ? root.accentColor : root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.iconSmall
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          id: rowApp

          text: String(row.entry.app || "")
          color: root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          elide: Text.ElideRight
          anchors.left: (rowIcon.visible || rowGlyph.visible) ? rowIcon.right : parent.left
          anchors.leftMargin: (rowIcon.visible || rowGlyph.visible) ? Style.space(6) : 0
          anchors.right: rowTime.left
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          id: rowTime

          text: String(row.entry.time || "")
          color: root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          anchors.right: rowClose.left
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
        }

        // La croix n'apparait que sous le curseur : vingt croix affichees en
        // permanence font une colonne de bruit le long du bord droit.
        Text {
          id: rowClose

          text: "󰅖"
          visible: row.hasCursor
          color: closeHover.hovered ? root.accentColor : root.mutedColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.iconSmall
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter

          HoverHandler { id: closeHover }

          MouseArea {
            anchors.fill: parent
            anchors.margins: -Style.space(4)
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removeRow(String(row.entry.key))
          }
        }
      }

      Text {
        width: parent.width
        visible: text.length > 0
        text: String(row.entry.summary || "")
        color: root.foregroundColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        maximumLineCount: 2
      }

      Text {
        width: parent.width
        visible: text.length > 0
        text: row.bodyText
        textFormat: Text.PlainText
        color: root.mutedColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        maximumLineCount: row.hasCursor ? 6 : 3
      }

      // L'image dont la notification parlait : une camera qui capte un mouvement,
      // une capture qu'on vient de prendre. Le magasin en garde une copie a la
      // taille du panneau, l'original est reste ou il etait.
      Image {
        visible: row.hasPreview && status === Image.Ready
        source: row.previewSource
        width: parent.width
        fillMode: Image.PreserveAspectFit
        sourceSize.width: parent.width * Screen.devicePixelRatio
        asynchronous: true
        smooth: true
      }
    }
  }
}
