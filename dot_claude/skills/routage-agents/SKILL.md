---
name: routage-agents
description: "Règles de routage pour attribuer chaque tâche au bon modèle Claude (Opus, Sonnet, Haiku). À charger OBLIGATOIREMENT avant de lancer un subagent (outil Agent, Workflow), et avant de créer ou modifier un subagent (~/.claude/agents/*.md, .claude/agents/*.md, champ `model:`). Mots-clés : subagent, agent, sous-agent, choix du modèle, model, opus, sonnet, haiku, routage, multi-agent, orchestration."
---

# Architecture de Sélection des Agents & Modèles Claude

Ce document définit les règles de routage pour attribuer chaque tâche de développement et de design au bon modèle Claude en fonction de ses forces.

## Quand appliquer ces règles

- **Avant de créer ou modifier un subagent** (`agents/*.md`) : fixer le champ `model:` du frontmatter selon le rôle principal de l'agent.
- **Avant de lancer un subagent** : si l'agent déclare déjà `model:` dans son frontmatter, ne pas passer le paramètre `model` de l'outil Agent (il écraserait ce choix), sauf si la tâche précise relève d'un autre modèle selon la matrice. Si l'agent ne déclare pas de modèle, passer `model` (`opus`, `sonnet`, `haiku`) explicitement. Avec `subagent_type: "fork"`, le paramètre `model` est ignoré : le fork hérite du modèle courant.
- Si une tâche relève de plusieurs catégories, retenir le modèle de la partie la plus complexe ou la plus ambiguë.
- En cas d'hésitation entre deux modèles, ou si la tâche ne correspond à aucune catégorie ci-dessous, le dire à l'utilisateur plutôt que trancher en silence.

## 🛠️ Matrice de Sélection des Modèles

| Modèle | Rôle Principal | Complexité Ciblée | Vitesse / Latence |
| :--- | :--- | :--- | :--- |
| **Claude Opus** | Stratège, Architecte & Auditeur UI/UX | Élevée / Ambiguë | Modérée (Raisonnement lourd) |
| **Claude Sonnet** | Développeur Front-End Principal & Intégrateur | Standard à Avancée | Rapide (Itération en direct) |
| **Claude Haiku** | Assistant d'Infrastructure, Trieur & Scripts | Faible / Répétitive | Ultra-rapide / Instantanée |

---

## 📋 Directives de Routage par Cas d'Usage

### 1. Design & Expérience Utilisateur (UI/UX)
*   **Sélectionner Claude Opus pour :**
    *   L'analyse de maquettes graphiques (Figma, captures d'écran) pour détecter les écarts de pixel ou les problèmes d'alignement.
    *   L'audit d'accessibilité (normes WCAG) et l'adaptation responsive (mobile vs desktop).
    *   La définition de la direction artistique initiale (choix des palettes, chartes graphiques) pour éviter le design générique d'IA.
*   **Sélectionner Claude Sonnet pour :**
    *   L'intégration rapide de composants stylisés avec Tailwind CSS, CSS Modules ou Styled Components.
    *   La création d'animations fluides à l'aide de bibliothèques tierces (ex: Framer Motion).

### 2. Développement Front-End & Logique
*   **Sélectionner Claude Sonnet pour :**
    *   L'écriture quotidienne de composants (React, Next.js, Vue, Svelte).
    *   L'écriture de tests unitaires et d'intégration (Jest, Vitest, Testing Library).
    *   L'intégration dans l'éditeur de code (via Cursor ou des outils CLI) pour du code-and-build rapide.
*   **Sélectionner Claude Opus pour :**
    *   L'architecture de la gestion d'état globale et complexe (Redux Toolkit, Zustand, Context API).
    *   La refactorisation majeure d'une base de code ou la migration d'un framework à un autre.

### 3. Tâches de Données & Automatisation
*   **Sélectionner Claude Haiku pour :**
    *   La génération de données de test (Mock Data) ou de fichiers JSON volumineux.
    *   L'écriture de scripts de build ou de configuration simples (Vite, Webpack, scripts Bash).
    *   Le tri, le nettoyage ou le requêtage de gros volumes de logs front-end.

---

## 🤖 Protocole Multi-Agent Recommandé (Mode Hybride)

Pour les projets d'envergure, configurez le flux de travail pour faire collaborer les modèles en cascade :

1.  **Phase de Planification (Opus) :** Demander à **Opus** de concevoir l'architecture des composants, de valider l'ergonomie UX et de découper le travail en sous-tâches claires.
2.  **Phase de Production (Sonnet) :** Transférer les spécifications d'Opus à **Sonnet** pour générer les fichiers de code, configurer les hooks et assembler l'interface.
3.  **Phase de Maintenance (Haiku) :** Utiliser **Haiku** pour générer la documentation technique d'accompagnement et les jeux de tests automatisés rapides.
