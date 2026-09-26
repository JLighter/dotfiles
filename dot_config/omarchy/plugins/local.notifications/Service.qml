// Rendu des toasts de notification aux couleurs de local.menubar.
//
// Ce service ne tient PAS de daemon : `omarchy.notifications` reste le serveur
// freedesktop, et il est indeboulonnable — `PluginRegistry.isEnabled()` renvoie
// inconditionnellement `true` pour tout plugin first-party non-bar, et deux
// NotificationServer se disputeraient org.freedesktop.Notifications.
//
// A la place, on intercepte son rendu. `Service.qml` amont expose
// `property alias popupModel` : un ListModel public et mutable, auquel sa propre
// fenetre est liee par `visible: popupModel.count > 0`. Des qu'une ligne y
// arrive, on la recopie ici puis on appelle `popupModel.remove(i)` — un simple
// retrait de ListModel, surtout PAS `removePopup()`, qui lui fermerait la
// notification et l'archiverait. Le stack natif se vide donc et s'efface, et
// c'est nous qui peignons.
//
// Ce qui reste a la charge du natif, et qu'on ne touche pas :
//   - le filtrage DND, applique dans `handleNotification()` avant l'insertion ;
//   - la persistance du fichier de popup, ecrite a l'insertion.
// Ce qu'on doit reproduire a la main, parce que `removePopup()` le faisait :
//   - `ref.dismiss()` / `ref.expire()`, sur la reference que `refFor()` resout ;
//   - `archivePopupFileFor()`, qui fait passer le fichier du toast dans
//     l'historique — c'est lui, et lui seul, qui donne a `showRecentHistory()`
//     quelque chose a rejouer.
//
// ── Ce que la 4.0 a change ──────────────────────────────────────────────────
// L'annonce de fragilite ci-dessous s'est realisee : la mise a jour a refondu
// le centre de notifications en « toasts vivants + historique sur disque ».
//   - `pendingModel` / `pastModel` / `markSeenByOriginalId` ont disparu, avec la
//     notion meme de pending ; l'archivage sur disque les remplace ;
//   - la reference vivante a quitte la ligne du modele pour le dictionnaire
//     `liveRefs`, indexe par `originalId` — d'ou `refFor()`.
//
// ── Fragilite assumee ───────────────────────────────────────────────────────
// On s'accroche au contrat interne du service natif : `popupModel` et la forme
// de ses lignes, `liveRefs`, `isRestoredRow`, `archivePopupFileFor`,
// `durationFor`, `focusApp`. Un `omarchy update` qui renomme l'un d'eux casse
// les toasts. Le mode d'echec est cependant benin : si CE plugin ne charge pas,
// le natif garde son modele plein et affiche ses propres toasts, sans style
// mais sans perte.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons

import "components"

Item {
  id: service

  // Injecte par le chargeur de services d'omarchy-shell.
  property var shell: null

  readonly property var nativeService: shell && typeof shell.firstPartyServiceFor === "function"
    ? shell.firstPartyServiceFor("omarchy.notifications")
    : null
  readonly property var nativePopupModel: nativeService ? nativeService.popupModel : null

  // --- Contrat de style repris de la barre -----------------------------------
  // Chaque valeur est gardee : `omarchy.bar` n'expose que background /
  // foreground / urgent, les autres proprietes sont propres a local.menubar.
  readonly property var barItem: shell && shell.bar ? shell.bar : null

  readonly property string barFontFamily: barItem && barItem.fontFamily
    ? barItem.fontFamily : Style.font.family
  readonly property color surfaceColor: barItem && barItem.background !== undefined
    ? barItem.background : Color.bar.background
  readonly property color textColor: barItem && barItem.foreground !== undefined
    ? barItem.foreground : Color.bar.text
  readonly property color accentColor: {
    if (barItem && barItem.accent !== undefined) return barItem.accent
    if (barItem && barItem.urgent !== undefined) return barItem.urgent
    return Color.bar.active
  }
  readonly property real accentFillOpacity: barItem && barItem.accentFillOpacity !== undefined
    ? barItem.accentFillOpacity : 0.18
  readonly property int revealDuration: barItem && barItem.revealDuration !== undefined
    ? barItem.revealDuration : 180
  readonly property int revealEasing: barItem && barItem.revealEasing !== undefined
    ? barItem.revealEasing : Easing.OutCubic
  readonly property int revealDistance: Style.space(12)

  // Les ilots de barre plafonnent leur rayon a la moitie de leur hauteur ; une
  // carte de toast est bien plus haute, donc le rayon du theme s'applique tel
  // quel — c'est deja celui des panneaux flottants et du tooltip.
  readonly property int cornerRadius: Style.cornerRadius

  // --- Geometrie -------------------------------------------------------------
  // Les toasts restent en haut a droite. Ils ne degagent la barre que lorsque
  // celle-ci occupe le bord haut ou droit, pour qu'une barre a gauche ou en bas
  // ne les arrache pas de leur coin habituel.
  readonly property string barPosition: shell && shell.barConfig ? String(shell.barConfig.position || "top") : "top"
  readonly property bool barVertical: barPosition === "left" || barPosition === "right"
  readonly property int defaultBarSize: barVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  readonly property int liveBarSize: barItem && !barItem.barHidden ? Math.max(0, barItem.barSize) : defaultBarSize
  // Marge que la barre laisse entre son premier ilot et le bord de l'ecran. La
  // reprendre aligne le bord droit de la colonne sur le dernier widget de barre,
  // la ou le natif utilisait `Style.gapsOut` (moitie du gaps_out de Hyprland).
  readonly property int edgeMargin: barItem && barItem.edgeMargin !== undefined
    ? barItem.edgeMargin : Style.gapsOut
  readonly property int barClearance: liveBarSize + edgeMargin

  // --- Interception ----------------------------------------------------------

  ListModel { id: toastModel }

  // Les navigateurs Chromium prefixent le corps par le domaine emetteur, parfois
  // enrobe dans un <a>. Le natif nettoie dans sa carte, pas dans le snapshot :
  // les lignes qu'on draine portent donc le corps brut.
  function isChromiumDerived(app, appIcon) {
    var source = (String(app || "") + "\n" + String(appIcon || "")).toLowerCase()
    return source.indexOf("chrom") >= 0 || source.indexOf("brave") >= 0 ||
           source.indexOf("vivaldi") >= 0 || source.indexOf("microsoft-edge") >= 0 ||
           source.indexOf("opera") >= 0
  }

  function sanitizeBody(body, app, appIcon) {
    var text = String(body || "").replace(/<img[^>]*>/gi, "")
    if (!isChromiumDerived(app, appIcon)) return text

    return text
      .replace(/^\s*<a\b[^>]*>\s*(?:https?:\/\/|www\.)?(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?(?:\/[^<\s]*)?\s*<\/a>\s*/i, "")
      .replace(/^\s*(?:https?:\/\/|www\.)?(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?(?:\/\S*)?\s+/i, "")
  }

  // On vide par la fin : le natif range le plus recent en tete, et
  // `showRecentHistory()` peut en deverser cinq d'un coup. Prendre la derniere
  // ligne puis inserer en tete preserve l'ordre d'origine dans les deux cas.
  function drain() {
    var source = service.nativePopupModel
    if (!source) return

    while (source.count > 0) {
      var index = source.count - 1
      var row = source.get(index)
      if (!row) {
        source.remove(index)
        continue
      }

      // Copier AVANT de retirer : `get()` rend une reference dans le modele, que
      // `remove()` invalide aussitot.
      //
      // Pas de `ref` recopiee ici : la reference vivante a quitte la ligne du
      // modele natif, `refFor()` la resout au moment de s'en servir. On retient
      // en revanche si la ligne etait restauree — le savoir plus tard suppose
      // que le service natif la connaisse encore, or on la lui retire.
      var copy = {
        originalId: row.originalId,
        app: row.app || "",
        appIcon: row.appIcon || "",
        summary: String(row.summary || ""),
        body: service.sanitizeBody(row.body, row.app, row.appIcon),
        image: row.image || "",
        glyph: row.glyph || "",
        urgency: row.urgency,
        expireTimeout: row.expireTimeout || 0,
        timestamp: row.timestamp,
        restored: service.isRestored(row)
      }

      source.remove(index)
      toastModel.insert(0, copy)
    }
  }

  // Une ligne restauree n'a plus d'objet serveur derriere elle, et son
  // identifiant, d'une generation precedente, peut entre-temps appartenir a une
  // notification sans rapport : la resoudre fermerait celle-la a sa place.
  function isRestored(row) {
    return !!row && !!nativeService
      && typeof nativeService.isRestoredRow === "function"
      && nativeService.isRestoredRow(row)
  }

  // La reference vivante ne voyage plus dans la ligne : le service natif la
  // range dans `liveRefs`, indexee par `originalId`. On la resout a l'usage
  // plutot que de la recopier dans `toastModel` — un ListModel ne cree pas de
  // role pour une valeur indefinie, et la premiere notification depourvue de
  // reference condamnerait le champ pour toutes les suivantes.
  function refFor(entry) {
    if (!entry || entry.restored === true) return null

    var originalId = Number(entry.originalId)
    if (!isFinite(originalId) || originalId < 0) return null

    var refs = nativeService ? nativeService.liveRefs : null
    return refs ? (refs[originalId] || null) : null
  }

  // On suit le compte par liaison de propriete plutot que par un `Connections`
  // vers une cible dynamique : une liaison traverse `nativePopupModel` et
  // `count` d'un seul tenant, donc elle se reevalue aussi bien quand le service
  // natif se resout que quand une notification arrive. Une piece mobile en moins.
  readonly property int nativeCount: nativePopupModel ? nativePopupModel.count : 0

  // Draine hors de l'evaluation de la liaison : `drain()` vide le modele que
  // `nativeCount` observe, donc l'appeler d'ici en direct rouvre le calcul de la
  // propriete pendant qu'il tourne encore — Qt y voit une boucle de liaison, la
  // signale a chaque notification et menace de rompre la liaison.
  onNativeCountChanged: if (nativeCount > 0) Qt.callLater(drain)

  // Le service natif est charge avant celui-ci (les first-party sont scannes en
  // premier), mais l'injection de `shell` et la resolution du service se font en
  // plusieurs temps : on redraine des que la reference apparait, au cas ou une
  // notification serait deja en attente.
  onNativePopupModelChanged: drain()
  Component.onCompleted: drain()

  // --- Cycle de vie d'un toast ------------------------------------------------

  function durationFor(urgency, expireTimeout) {
    if (nativeService && typeof nativeService.durationFor === "function")
      return nativeService.durationFor(urgency, expireTimeout)
    // Repli sur les durees amont si le contrat a bouge : critique = persistant.
    if (urgency === 2) return 0
    return urgency === 0 ? 5000 : 8000
  }

  function removeToast(index, reason) {
    if (index < 0 || index >= toastModel.count) return

    var entry = toastModel.get(index)
    var ref = service.refFor(entry)

    // Ce que `removePopup()` fait pour ses propres lignes : le toast quitte
    // l'ecran, son fichier devient la derniere entree d'historique. Sans cet
    // appel rien n'entre jamais dans l'historique — on retire les lignes du
    // modele natif sans passer par lui — et `showRecentHistory()` n'a plus rien
    // a rejouer. L'archivage precede le retrait : `get()` rend une reference
    // dans le modele, que `remove()` invalide aussitot.
    //
    // (`markSeenByOriginalId` occupait cette place ; la 4.0 a remplace le couple
    // pending / past par cet archivage sur disque, et la fonction a disparu.)
    if (entry && nativeService && typeof nativeService.archivePopupFileFor === "function")
      nativeService.archivePopupFileFor(entry)

    toastModel.remove(index)

    if (ref) {
      try {
        if (ref.tracked) {
          if (reason === "expire" && typeof ref.expire === "function") ref.expire()
          else ref.dismiss()
        }
      } catch (e) {
        // Objet deja demonte par le serveur — rien a fermer.
      }
    }
  }

  // Declenche l'action libnotify « default », puis ferme. Les clients
  // l'enregistrent sous cet identifiant canonique ; les toasts de capture
  // d'ecran s'en servent pour ouvrir l'editeur au clic.
  function invokeDefault(index) {
    if (index < 0 || index >= toastModel.count) return

    var entry = toastModel.get(index)
    var ref = service.refFor(entry)
    var invoked = false

    if (ref && ref.actions) {
      for (var i = 0; i < ref.actions.length; i++) {
        var action = ref.actions[i]
        if (action && action.identifier === "default") {
          try { action.invoke(); invoked = true } catch (e) { console.warn("invoke default failed:", e) }
          break
        }
      }
    }

    // Les applis de chat n'enregistrent presque jamais d'action « default » :
    // elles attendent qu'un clic donne le focus a leur fenetre.
    if (!invoked && nativeService && typeof nativeService.focusApp === "function")
      nativeService.focusApp(entry)

    removeToast(index, "dismiss")
  }

  // --- Rendu ------------------------------------------------------------------
  //
  // Une PanelWindow par sortie. Couche Overlay, exclusionMode Ignore, aucun focus
  // clavier : les toasts sont passifs et ne doivent jamais voler l'entree a
  // l'application au premier plan.

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: popupWindow
      required property var modelData
      screen: modelData
      visible: toastModel.count > 0

      WlrLayershell.namespace: "local-notifications"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"

      anchors { top: true; right: true }
      margins {
        top: service.barPosition === "top" ? service.barClearance : service.edgeMargin
        right: service.barPosition === "right" ? service.barClearance : service.edgeMargin
      }

      implicitWidth: popupColumn.implicitWidth
      implicitHeight: popupColumn.implicitHeight

      ColumnLayout {
        id: popupColumn
        anchors.right: parent.right
        anchors.top: parent.top
        // Meme respiration entre deux toasts qu'entre la colonne et le bord de
        // l'ecran : la pile garde le rythme de la barre.
        spacing: service.edgeMargin

        Repeater {
          model: toastModel

          // Le delegue est un emplacement qui porte le minuteur de duree de vie ;
          // le visuel vit dans NotificationCard.
          delegate: Item {
            id: slot
            required property int index
            required property string app
            required property string appIcon
            required property string summary
            required property string body
            required property string image
            required property string glyph
            required property int urgency
            required property double expireTimeout

            Layout.preferredWidth: card.implicitWidth
            Layout.alignment: Qt.AlignRight
            implicitHeight: card.implicitHeight

            readonly property real lifetime: service.durationFor(slot.urgency, slot.expireTimeout)
            property real remainingLifetime: 1.0
            // Le survol gele le minuteur : la carte s'allume pour le signaler.
            readonly property bool ticking: slot.lifetime > 0 && !card.hovered

            // Passe a vrai juste apres l'incubation : la carte entre en glissant
            // au lieu d'apparaitre d'un coup.
            property bool revealed: false
            Component.onCompleted: slot.revealed = true

            Timer {
              interval: 50
              repeat: true
              running: slot.ticking
              onTriggered: {
                if (slot.lifetime <= 0) return
                slot.remainingLifetime -= 50.0 / slot.lifetime
                if (slot.remainingLifetime <= 0) {
                  slot.remainingLifetime = 0
                  service.removeToast(slot.index, "expire")
                }
              }
            }

            NotificationCard {
              id: card
              anchors.right: parent.right

              app: slot.app
              appIcon: slot.appIcon
              summary: slot.summary
              body: slot.body
              image: slot.image
              glyph: slot.glyph
              urgency: slot.urgency

              radius: service.cornerRadius
              fontFamily: service.barFontFamily
              surfaceColor: service.surfaceColor
              textColor: service.textColor
              accentColor: service.accentColor
              accentFillOpacity: service.accentFillOpacity
              revealDuration: service.revealDuration
              revealEasing: service.revealEasing

              // Meme geste que les popouts de barre : une descente courte, un
              // leger agrandissement et un fondu, sur la courbe du theme.
              opacity: slot.revealed ? 1 : 0
              scale: slot.revealed ? 1 : 0.97
              transformOrigin: Item.TopRight

              transform: Translate {
                y: slot.revealed ? 0 : -service.revealDistance

                Behavior on y {
                  NumberAnimation { duration: service.revealDuration; easing.type: service.revealEasing }
                }
              }

              Behavior on opacity {
                NumberAnimation { duration: service.revealDuration; easing.type: service.revealEasing }
              }
              Behavior on scale {
                NumberAnimation { duration: service.revealDuration; easing.type: service.revealEasing }
              }

              onCardClicked: service.invokeDefault(slot.index)
            }
          }
        }
      }
    }
  }
}
