import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Horloge du bord oppose aux workspaces. Clic gauche = calendrier, clic droit =
// bascule vers le format long, clic de nouveau pour revenir.
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
  readonly property int islandRadius: bar && bar.islandRadius !== undefined ? bar.islandRadius : Style.cornerRadius

  readonly property color accentColor: bar ? bar.accent : Color.urgent
  readonly property real accentFillOpacity: bar && bar.accentFillOpacity !== undefined ? bar.accentFillOpacity : 0.18
  readonly property color foregroundColor: bar ? bar.foreground : Color.foreground
  readonly property color mutedColor: Qt.darker(foregroundColor, 1.4)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color islandFill: Qt.rgba(foregroundColor.r, foregroundColor.g, foregroundColor.b, 0.06)
  readonly property int revealDuration: bar && bar.revealDuration !== undefined ? bar.revealDuration : 180
  readonly property int revealEasing: Easing.OutCubic
  readonly property int haloInsetX: bar && bar.islandPaddingX !== undefined ? bar.islandPaddingX : 0
  readonly property int haloInsetY: bar && bar.islandPaddingY !== undefined ? bar.islandPaddingY : 0

  readonly property string barPosition: bar ? bar.position : "top"
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

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // Halo de survol, dans la meme teinte que le workspace actif. Il deborde du
  // padding de l'ilot pour en epouser les bords au lieu d'en laisser voir un
  // liseré tout autour.
  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -root.haloInsetX
    anchors.rightMargin: -root.haloInsetX
    anchors.topMargin: -root.haloInsetY
    anchors.bottomMargin: -root.haloInsetY
    radius: root.islandRadius
    color: root.accentColor
    opacity: button.tooltipHovered || root.opened ? root.accentFillOpacity : 0

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
      if (mouseButton === Qt.RightButton) root.alt = !root.alt
      else root.toggle()
    }
  }

  // --- Dates -----------------------------------------------------------------
  // Toute la logique du calendrier tient sur des `Date` JS ramenees a minuit :
  // comparer deux jours revient alors a comparer trois nombres, et un jour de
  // plus ou de moins se demande a `new Date(y, m, d + n)`, qui franchit tout
  // seul les bords de mois et d'annee.

  // `clock` bat a la minute : la journee en cours se reevalue donc d'elle-meme
  // au passage de minuit, panneau ouvert ou non.
  readonly property date today: dayOf(clock.date)

  function dayOf(value) {
    var d = new Date(value)
    return new Date(d.getFullYear(), d.getMonth(), d.getDate())
  }

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear()
      && a.getMonth() === b.getMonth()
      && a.getDate() === b.getDate()
  }

  function shiftDays(date, count) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() + count)
  }

  // Lundi de la semaine contenant `date`. `getDay()` compte a partir de
  // dimanche (0) : on le decale pour que lundi vaille 0.
  function startOfWeek(date) {
    return shiftDays(date, -((date.getDay() + 6) % 7))
  }

  // Numero de semaine ISO 8601 : la semaine 1 est celle qui contient le premier
  // jeudi de l'annee. On se place sur le jeudi de la semaine courante, et on
  // compte les semaines qui le separent du 1er janvier de *son* annee — le
  // jeudi porte l'annee ISO, ce qui regle a lui seul le cas des semaines a
  // cheval sur decembre et janvier.
  function isoWeekNumber(date) {
    var thursday = shiftDays(startOfWeek(date), 3)
    var firstOfYear = new Date(thursday.getFullYear(), 0, 1)
    var days = Math.round((thursday - firstOfYear) / 86400000)
    return Math.floor(days / 7) + 1
  }

  // Une case de la grille. `inMonth` distingue les jours du mois affiche de
  // ceux que les semaines de bord empruntent aux mois voisins.
  function dayCell(date, refMonth) {
    return {
      date: date,
      day: date.getDate(),
      inMonth: date.getMonth() + 1 === refMonth
    }
  }

  // Construit la grille affichee : un tableau de semaines, chacune de la forme
  //
  //   { week: <numero ISO>, days: [ <case>, ... x7 ] }   lundi en premier
  //
  // Six semaines quelle que soit la longueur du mois : la hauteur du panneau ne
  // bouge alors jamais d'une fleche a l'autre. Le prix en est une ligne
  // entierement empruntee au mois suivant sur les mois courts — un fevrier non
  // bissextile commencant un lundi n'en demande que quatre. Pour n'en rendre
  // que le necessaire, boucler tant que `shiftDays(premierLundi, weeks * 7)`
  // n'a pas depasse `new Date(year, month, 0).getDate()`, au prix d'un panneau
  // qui change de taille — et il s'anime, donc ca se voit.
  function buildMonthGrid(year, month) {
    var firstMonday = startOfWeek(new Date(year, month - 1, 1))
    var weeks = []

    for (var w = 0; w < 6; w++) {
      var days = []
      for (var d = 0; d < 7; d++) days.push(dayCell(shiftDays(firstMonday, w * 7 + d), month))
      weeks.push({ week: isoWeekNumber(days[0].date), days: days })
    }

    return weeks
  }

  // --- Calendrier : etat -----------------------------------------------------
  // `viewYear`/`viewMonth` decident du mois dessine ; `cursorDate` du jour mis
  // en avant. Les deux se suivent : deplacer le curseur hors du mois affiche
  // fait tourner la page.

  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth() + 1
  property date cursorDate: today

  readonly property var monthGrid: buildMonthGrid(viewYear, viewMonth)
  readonly property date viewMonthStart: new Date(viewYear, viewMonth - 1, 1)
  readonly property bool viewingToday: viewYear === today.getFullYear() && viewMonth === today.getMonth() + 1

  function showMonth(year, month) {
    // Un mois 0 ou 13 est un mois valide de l'annee d'a cote : `Date` le
    // normalise, on lui laisse le calcul plutot que de le refaire ici.
    var normalized = new Date(year, month - 1, 1)
    viewYear = normalized.getFullYear()
    viewMonth = normalized.getMonth() + 1
  }

  function shiftMonth(count) {
    showMonth(viewYear, viewMonth + count)
  }

  // Le curseur mene la vue : atterrir sur un jour emprunte au mois voisin
  // tourne la page pour le suivre.
  function moveCursor(days) {
    setCursor(shiftDays(cursorDate, days))
  }

  function setCursor(date) {
    cursorDate = date
    showMonth(date.getFullYear(), date.getMonth() + 1)
  }

  function goToToday() {
    setCursor(today)
  }

  // --- Ouverture -------------------------------------------------------------

  property bool opened: false

  function open() {
    // Rouvrir doit toujours retomber sur aujourd'hui : le mois qu'on
    // consultait la derniere fois n'a plus de raison d'etre celui qu'on
    // cherche.
    goToToday()
    opened = true
  }

  function close() {
    opened = false
  }

  function toggle() {
    opened ? close() : open()
  }

  function closeForPopoutSwitch() {
    close()
  }

  readonly property bool primaryInstance: {
    var window = root.QsWindow ? root.QsWindow.window : null
    var screens = Quickshell.screens
    return !!window && screens.length > 0 && window.screen === screens[0]
  }

  // `IpcHandler` vit dans `Quickshell.Io`, pas dans `Quickshell` : sans cet
  // import, le fichier ne compile pas, et comme `Bar.qml` instancie ses widgets
  // en dur, c'est la barre entiere qui disparait.
  IpcHandler {
    enabled: root.primaryInstance
    target: "menubar.clock"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  // --- Panneau ---------------------------------------------------------------

  // Sept colonnes de jours plus l'etroite colonne des numeros de semaine.
  readonly property int weekColumnWidth: Style.space(24)
  readonly property int cellHeight: Style.space(28)

  KeyboardPanel {
    id: panel

    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(760))

    PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      onCloseRequested: root.close()
      // Entree ramene a aujourd'hui : c'est le seul endroit ou l'on veuille
      // revenir apres avoir feuillete.
      onActivateRequested: root.goToToday()
      onMoveRequested: function(dx, dy) { root.moveCursor(dx + dy * 7) }
      onTabRequested: function(direction) { root.shiftMonth(direction) }

      Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

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
        // Suit le curseur, pas l'horloge : feuilleter le calendrier lit la date
        // survolee ici plutot que d'obliger a la reconstituer de tete.
        PanelIsland {

          Item {
            width: parent.width
            implicitHeight: Math.max(heroDay.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroDay

              text: root.cursorDate.getDate()
              color: root.sameDay(root.cursorDate, root.today) ? root.accentColor : root.foregroundColor
              font.family: root.fontFamily
              font.pixelSize: Math.round(Style.font.title * 1.8)
              font.bold: true
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels

              anchors.left: heroDay.right
              anchors.leftMargin: Style.space(16)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: Qt.formatDateTime(root.cursorDate, "dddd")
                color: root.foregroundColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                text: Qt.formatDateTime(root.cursorDate, "d MMMM yyyy").toUpperCase()
                  + " · W" + root.isoWeekNumber(root.cursorDate)
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
                width: parent.width
              }
            }
          }
        }

        // ---- Grille ----
        PanelIsland {

          // Barre de navigation. Le titre est cliquable et prend l'accent des
          // qu'on a quitte le mois courant : c'est lui qui y ramene.
          Item {
            width: parent.width
            implicitHeight: Style.space(26)

            NavArrow {
              // Ecrits en echappement plutot qu'en caractere : ces glyphes
              // vivent dans la zone privee Unicode et ne survivent pas toujours
              // a un copier-coller.
              glyph: "\uF053"
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              onTriggered: root.shiftMonth(-1)
            }

            Text {
              text: Qt.formatDateTime(root.viewMonthStart, "MMMM yyyy")
              color: root.viewingToday ? root.foregroundColor : root.accentColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
              anchors.centerIn: parent

              MouseArea {
                anchors.fill: parent
                anchors.margins: -Style.space(6)
                cursorShape: Qt.PointingHandCursor
                onClicked: root.goToToday()
              }
            }

            NavArrow {
              glyph: "\uF054"
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              onTriggered: root.shiftMonth(1)
            }
          }

          // En-tetes de colonnes. Les noms viennent de la locale du systeme,
          // tronques a deux lettres pour tenir dans la largeur d'une case ;
          // l'ordre, lui, reste fixe — la semaine commence lundi, comme la
          // numerotation ISO en dessous.
          Row {
            width: parent.width

            Item {
              width: root.weekColumnWidth
              height: Style.space(18)
            }

            Repeater {
              model: 7

              Text {
                required property int index

                width: (parent.width - root.weekColumnWidth) / 7
                height: Style.space(18)
                text: Qt.locale().dayName((index + 1) % 7, Locale.ShortFormat).substring(0, 2)
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                renderType: Text.NativeRendering
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }
          }

          Repeater {
            model: root.monthGrid

            WeekRow {
              required property var modelData

              width: parent.width
              entry: modelData
            }
          }
        }
      }
    }
  }

  // --- Composants internes ---------------------------------------------------

  component PanelIsland: Rectangle {
    default property alias content: holder.data
    property int padding: Style.space(10)

    width: parent.width
    implicitHeight: holder.implicitHeight + padding * 2
    radius: Style.cornerRadius
    color: root.islandFill

    Column {
      id: holder

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: parent.padding
      spacing: Style.space(4)
    }
  }

  component NavArrow: Item {
    id: navArrow

    property string glyph: ""

    signal triggered()

    width: Style.space(22)
    height: Style.space(22)

    CursorSurface {
      anchors.fill: parent
      hasCursor: arrowHover.hovered
      foreground: root.foregroundColor
      accent: root.accentColor
    }

    HoverHandler { id: arrowHover }

    Text {
      anchors.centerIn: parent
      text: navArrow.glyph
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      renderType: Text.NativeRendering
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: navArrow.triggered()
    }
  }

  // Un numero de semaine, puis les sept jours qu'il couvre.
  component WeekRow: Row {
    id: weekRow

    required property var entry

    Text {
      width: root.weekColumnWidth
      height: root.cellHeight
      text: weekRow.entry.week
      color: root.mutedColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      renderType: Text.NativeRendering
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }

    Repeater {
      model: weekRow.entry.days

      DayCell {
        required property var modelData

        width: (weekRow.width - root.weekColumnWidth) / 7
        cell: modelData
      }
    }
  }

  // Une case. Le contrat de CursorSurface interdit de peindre depuis le survol
  // local : la case ne connait que `root.cursorDate`, que la souris comme les
  // fleches deplacent. Un seul jour est donc mis en avant a la fois, quel que
  // soit celui des deux qui commande.
  //
  // L'id ne peut pas s'appeler `dayCell` : ce nom est deja celui de la fonction
  // qui fabrique les cases, et les deux se disputeraient la resolution.
  component DayCell: Item {
    id: cellItem

    required property var cell

    readonly property bool isToday: root.sameDay(cell.date, root.today)
    readonly property bool isCursor: root.sameDay(cell.date, root.cursorDate)

    height: root.cellHeight

    CursorSurface {
      anchors.fill: parent
      anchors.margins: 1
      hasCursor: cellItem.isCursor
      current: cellItem.isToday
      foreground: root.foregroundColor
      accent: root.accentColor
    }

    Text {
      anchors.centerIn: parent
      text: cellItem.cell.day
      // Les jours empruntes aux mois voisins restent lisibles mais s'effacent :
      // ils bouchent les bords de la grille sans se faire prendre pour le mois
      // affiche.
      color: cellItem.isToday ? root.accentColor : root.foregroundColor
      opacity: cellItem.cell.inMonth ? 1 : 0.35
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: cellItem.isToday
      renderType: Text.NativeRendering
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.cursorDate = cellItem.cell.date
      onClicked: root.setCursor(cellItem.cell.date)
    }
  }
}
