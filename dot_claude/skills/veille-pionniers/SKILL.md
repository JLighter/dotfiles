---
name: veille-pionniers
description: >
  Veille sur les pionniers du développement logiciel, ceux dont les livres et
  les pratiques sont devenus des références : Martin Fowler, Kent Beck,
  Robert C. Martin (Uncle Bob), Larry Constantine, Ron Jeffries, Dave Farley,
  Eric Evans, Michael Feathers, Dan North, Grady Booch, Rebecca Wirfs-Brock,
  Alistair Cockburn. Récap de ce qu'ils disent, font et publient, en priorité
  sur l'IA (LLM, agents, TDD et IA, craft et IA). Utiliser /veille-pionniers
  pour 30 jours, /veille-pionniers 7 ou /veille-pionniers 90 pour une autre
  fenêtre. Mots-clés : pionniers, craft, XP, refactoring, clean code, DDD,
  Fowler, Beck, Uncle Bob, IA, LLM.
user-invokable: true
argument-hint: "[nombre_de_jours]"
allowed-tools:
  - Read
  - Bash
  - WebFetch
  - WebSearch
---

# Veille des pionniers du développement

Tu fais une veille sur des personnes, pas sur des sujets. La question est
« qu'est-ce que chacun d'eux dit, fait et publie en ce moment ? », avec l'IA
en priorité. Ce qui compte, c'est leur position réelle, pas une paraphrase
plausible du titre.

## Procédure

### Étape 1 : Parser l'argument

- Un nombre (ex. `/veille-pionniers 7`) = nombre de jours.
- Sinon **30 jours** par défaut : ces auteurs publient bien moins souvent
  qu'un agrégateur.
- Stocke cette valeur comme `DAYS`.

### Étape 2 : Récupérer les flux

```bash
python3 ~/.claude/skills/veille-pionniers/fetch_feeds.py DAYS
```

En auto mode, déclarer ces hôtes dans `allowed_domains` :
`martinfowler.com`, `newsletter.kentbeck.com`, `ronjeffries.com`,
`www.youtube.com`, `www.domainlanguage.com`, `blog.cleancoder.com`,
`michaelfeathers.substack.com`, `dannorth.net`.

Le script lit `sources.yml` et affiche trois blocs :

1. Articles en TSV, triés par date décroissante :
   `DATE\tAUTEUR\tTITRE\tURL\tDESCRIPTION`
2. `SOURCES:` : une ligne par auteur,
   `NOM\tCONNU_POUR\tSITE\tNB_ARTICLES_FENÊTRE\tDERNIER_POST` (`N/A` = pas de flux ou échec).
3. `SEARCH:` : les auteurs à chercher sur le web,
   `NOM\tCONNU_POUR\tREQUÊTE`.

Les lignes `ERROR: ...` sortent sur stderr.

### Étape 3 : Repérer ce qui parle d'IA

Classe chaque article **sur le sens**, pas sur des mots-clés : un billet
intitulé « Baking a Model » peut ne pas parler de LLM, et « Refactoring =
Learning » peut en parler dans le corps. En cas de doute, lis l'article.

Est « IA » tout ce qui touche aux LLM, aux assistants de code, aux agents, au
vibe coding, à l'impact de l'IA sur le métier, les pratiques (TDD, revue,
design) ou l'apprentissage.

### Étape 4 : Lire les articles IA

Si `WebFetch` ou `WebSearch` ne sont pas chargés (outils différés), les
charger d'abord : `ToolSearch` avec `select:WebFetch,WebSearch`.

Pour chaque article IA (au plus **8**, les plus récents d'abord, au moins un
par auteur avant d'en prendre un second), récupère le contenu avec
`WebFetch` et extrais :

- la **thèse** de l'auteur en 2 à 4 phrases ;
- **une citation courte** (une phrase, verbatim, en langue originale) ;
- ce que l'auteur **fait** concrètement, si l'article le dit (expérimentation,
  outil, livre, formation).

Vidéos YouTube (Dave Farley) : `WebFetch` ne donne pas la transcription.
Résume à partir de la description, et signale-le (« d'après la description
de la vidéo »).

Au-delà de 8, les articles IA restants sont listés avec titre + description,
sans lecture.

### Étape 5 : Chercher les auteurs hors flux

Pour chaque ligne `SEARCH:`, lance un `WebSearch` avec la requête indiquée,
en ajoutant l'année et le mois courants. Ne retiens que ce qui est **daté dans
la fenêtre** ou, à défaut, le plus récent en indiquant clairement sa date.

Distingue toujours :
- ce que la personne **dit ou publie** elle-même (interview, talk, post) ;
- ce qu'on **dit d'elle** (article tiers) → « à propos de », jamais « il dit ».

Si rien de récent : l'écrire (« rien trouvé depuis [date] »). Ne pas combler.

### Étape 6 : Rédiger le récap

```
# Veille pionniers : du [date_début] au [date_fin]
> X publications de Y auteurs sur Z jours, dont N sur l'IA
```

Dates au format français lisible (ex. « 23 septembre 2026 »).

#### Section 1 : « Ce qu'ils disent de l'IA » (en tête)

Une sous-section par auteur, les plus actifs sur le sujet d'abord :

```
### Martin Fowler · *Refactoring, PoEAA*

**Position :** thèse en 2 à 4 phrases.
> « Citation courte verbatim » ([titre de l'article](URL), 17 sept.)

**Ce qu'il fait :** … (seulement si l'article le dit)

- [Autre article IA](URL) · date · une ligne
```

Puis, **seulement si au moins deux auteurs se sont exprimés sur l'IA**, un
paragraphe « Convergences et désaccords » qui compare leurs positions telles
qu'elles ont été lues, et rien de plus.

#### Section 2 : « Leurs autres publications »

Groupé **par auteur** (pas par jour), une ligne par article :
`- [Titre](URL) · date · description courte`
Si la description est vide ou `N/A`, pas de description.

#### Section 3 : « Hors flux » (résultats de l'étape 5)

Une entrée par auteur cherché, avec date et source de chaque élément.

#### Section 4 : « Silencieux sur la période »

À partir du bloc `SOURCES:`, les auteurs à 0 article, avec leur dernier post :
- dernier post de moins d'un an → « silencieux sur la période (dernier post : date) » ;
- plus d'un an → « blog dormant depuis [mois année] » ;
- `N/A` sans erreur → « pas de flux » (déjà couvert en section 3 s'il a une requête).

#### Pied de page

```
---
### Sources
- [Nom](site) · connu pour … · N articles
```

### Étape 7 : Gérer les erreurs

- Une ligne `ERROR:` → en tête du récap :
  `> **Note :** le flux de « Nom » n'a pas pu être récupéré.`
- Échec de `WebFetch` sur un article IA → garder titre et description, et
  écrire « article non lu ».
- Article coupé par un paywall (fréquent sur la newsletter de Kent Beck,
  Substack) → résumer seulement la partie visible et écrire « extrait gratuit
  seulement ». Ne jamais extrapoler la suite.
- Résultat `WebSearch` sans date lisible → écrire « date non établie ». Ne
  jamais le présenter comme récent.
- Aucun article dans la fenêtre → le dire, et proposer une fenêtre plus large.

## Ce que ce skill ne fait jamais

- Attribuer une opinion à un auteur à partir du seul titre. Pas lu = « d'après
  le titre » ou « d'après la description ».
- Inventer ou reformuler une citation. Une citation est verbatim, sinon ce
  n'est pas une citation.
- Présenter un article tiers comme la parole de l'auteur.
- Présenter un résultat ancien comme récent : toute date hors fenêtre est
  écrite en clair.
- Donner son propre avis sur les positions des auteurs. Le récap rapporte, il
  ne tranche pas.

## Ajouter ou retirer un auteur

Éditer `sources.yml` : `feed:` pour un flux RSS/Atom, `search:` pour une
recherche web, les deux si le flux est dormant. Si l'auteur a un flux, ajouter
son hôte à la liste `allowed_domains` de l'étape 2.
