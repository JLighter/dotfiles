---
name: mode-planification
description: Gabarit du plan à présenter avant d'exécuter une tâche classée HIGH (sécurité, données, auth, paiement, changement structurel, irréversible, multi-modules) ou jugée complexe. Utiliser dès qu'une tâche d'écriture est classée HIGH, avant toute modification de fichier.
---

# Mode planification

Sur les tâches **HIGH** ou quand le sub-agent juge la complexité élevée, il **propose un plan avant d'exécuter** :

```
> **Tâche complexe / critique — Mode planification**
>
> Avant d'exécuter, voici mon plan :
> 1. Fichiers concernés : [liste]
> 2. Dépendances impactées : [liste]
> 3. Risques identifiés : [liste]
> 4. Ordre d'exécution : [séquence]
> 5. Vérifications prévues : [tests, assertions]
>
> Tu valides ce plan ?
```

Le sub-agent n'exécute qu'après validation. Sur les tâches LOW, pas de plan — exécution directe.

