# Dotfiles

Gérés avec [chezmoi](https://www.chezmoi.io/). Deux cibles : **macOS** et **Omarchy** (Arch + Hyprland).

Le dépôt est la *source*, `$HOME` est la *cible*. Les fichiers ne sont pas symlinkés :
`chezmoi apply` écrit les fichiers réels, après avoir évalué les templates pour la
machine courante. `chezmoi diff` montre ce qui changerait avant d'appliquer.

## Bootstrap sur une nouvelle machine

Une seule commande, identique sur macOS et sur Omarchy :

```sh
sh -c "$(curl -fsLS https://raw.githubusercontent.com/JLighter/dotfiles/main/bootstrap.sh)"
```

Seul prérequis : `git` (et Homebrew sur macOS). Le script installe chezmoi, clone le
dépôt dans `~/.dotfiles`, puis applique. Il est idempotent : relançable sans risque.

`chezmoi init` pose trois questions (nom git, email git, machine pro ou non) et écrit
les réponses dans `~/.config/chezmoi/chezmoi.toml`. Elles ne sont demandées qu'une
fois par machine, et c'est ce fichier qui fixe `sourceDir` à `~/.dotfiles` — les
commandes suivantes n'ont plus besoin de `--source`.

Le reste est pris en charge par les scripts de `.chezmoiscripts/`, que `chezmoi apply`
déclenche automatiquement une seule fois (`run_once_`) :

| Script                | Rôle                                                        |
| --------------------- | ----------------------------------------------------------- |
| `10-packages`         | zsh, git, neovim, tmux, fzf, zoxide, bat, spaceship          |
| `20-oh-my-zsh`        | oh-my-zsh et les trois plugins zsh                           |
| `30-tpm`              | gestionnaire de plugins tmux                                 |
| `40-default-shell`    | `chsh` vers zsh — seule étape qui demande le mot de passe    |

Deux exceptions à ce « une seule fois » : `35-herdr-plugins` et
`36-claude-plugins` rejouent à chaque `apply`. Ils installent des plugins dont le
dépôt versionne la *déclaration* mais pas le *clone* ; celui-ci peut disparaître
sans que la déclaration bouge, et laisse alors une touche ou une statusline muette.

`35-herdr-plugins` pose aussi herdr lui-même s'il manque, par l'installateur
officiel (`~/.local/bin`, mis à jour ensuite par `herdr update`), puis le hook
`herdr integration install claude` appelé par `settings.json`, et régénère
`~/.claude/skills/herdr` depuis `herdr --skill`. Sa config versionnée :
`config.toml`, `bin/spawn`, `workspaces/` et `plugins/config/herdr-spawn/config`.
Le plugin hunk.diff demande en plus le binaire `hunk`, non installé ici.

Deux gestes manuels restent, volontairement hors script : `<C-a> I` dans tmux pour
installer les plugins, et le premier lancement de Neovim pour LazyVim.

## Usage quotidien

```sh
chezmoi edit ~/.zshrc   # éditer la source du fichier
chezmoi diff            # voir les écarts source ↔ $HOME
chezmoi apply           # appliquer
chezmoi add ~/.foo      # faire entrer un nouveau fichier dans le dépôt
chezmoi cd              # aller dans ~/.dotfiles
chezmoi update          # git pull + apply
```

Après un `git pull` manuel, un `chezmoi apply` suffit.

## Convention de nommage des sources

chezmoi encode les métadonnées dans le nom des fichiers du dépôt :

| Source                          | Cible                                          |
| ------------------------------- | ---------------------------------------------- |
| `dot_zshrc.tmpl`                | `~/.zshrc` (template)                          |
| `dot_config/nvim/`              | `~/.config/nvim/`                              |
| `dot_claude/hooks/executable_*` | fichier déployé en `+x`                        |
| `private_shell.json`            | déployé en `0600`                              |
| `create_private_devices.json.tmpl` | créé s'il manque, **jamais réécrit** ensuite |

Le préfixe `create_` est la réponse aux fichiers que l'application modifie
elle-même : le dépôt fournit la graine, le programme reste maître ensuite. Sans
lui, chaque `apply` écraserait les réglages faits depuis l'interface.

Les fichiers commençant par un point dans le dépôt (`.gitignore`, `.chezmoiignore`)
sont **ignorés** par chezmoi : ils servent au dépôt, pas à `$HOME`.

## Ce qui diffère entre les machines

- `dot_zshrc.tmpl` — chemins Homebrew / Java / pnpm / gcloud selon l'OS, agent SSH
  (launchd sur macOS, systemd sur Arch), emplacement de `spaceship.zsh`.
- `dot_gitconfig.tmpl` — nom et email, et la redirection `insteadOf` GitLab n'est
  écrite que sur une machine marquée pro.
- `.chezmoiignore` — les overrides Hyprland ne sont jamais déployés sur macOS,
  `.hushlogin` ne l'est que sur macOS.

Pour une surcharge locale à une seule machine et non versionnée : `~/.zshrc.local`,
sourcé en fin de `.zshrc`.

## Omarchy

Omarchy installe ses propres configs dans `~/.config/` et les fait évoluer via
`omarchy update`. Pour ne pas se mettre en travers, le dépôt ne versionne que les
fichiers qui **divergent réellement** des défauts de la distro :

| Fichier                    | Écart                                          |
| -------------------------- | ---------------------------------------------- |
| `.config/hypr/input.conf`  | `kb_layout = us`                               |
| `.config/hypr/envs.conf`   | variables NVIDIA                               |
| `.config/hypr/hyprsplit.conf` | workspaces par écran — **inactif**, cf. en-tête |

Tout le reste (`bindings.conf`, `looknfeel.conf`, `monitors.conf`, `hyprland.conf`…)
est laissé à Omarchy. Pour vérifier ce qui a divergé depuis :

```sh
for f in ~/.config/hypr/*.conf; do
    d=~/.local/share/omarchy/config/hypr/$(basename "$f")
    [ -f "$d" ] && ! diff -q "$f" "$d" >/dev/null && echo "diverge : $(basename "$f")"
done
```

> `~/.config/hypr/envs.conf` n'est sourcé par **aucun** fichier : `hyprland.conf`
> ne charge que le `envs.conf` des défauts Omarchy. Les variables NVIDIA qu'il
> contient sont donc inertes. Pour les activer, ajouter
> `source = ~/.config/hypr/envs.conf` à `~/.config/hypr/hyprland.conf`.

### Raccourcis : trois couches

| Couche | Modificateur | Où                                                     |
| ------ | ------------ | ------------------------------------------------------ |
| WM     | `ALT`        | `.config/hypr/bindings.conf` — reprise des gestes i3    |
| Mux    | `CTRL+SPACE` | prefix tmux **et** prefix herdr, identiques             |
| Éditeur| `SPACE`      | leader LazyVim, défaut du framework                     |

La couche WM reprend i3 (`$mod` y valait `Mod1` = ALT) : `ALT+Return` terminal,
`ALT+D` lanceur, `ALT+J/K/L/;` focus, `ALT+Shift+*` déplacement, `ALT+1..0`
workspaces, `ALT+Shift+A` fermer. Chaque geste repris est `unbind` de son
équivalent SUPER, pour qu'il n'existe qu'une seule façon de le faire.

Sans équivalent en dwindle, donc non repris : `mod+s` (stacking), `mod+w`
(tabbed), `mod+a` (focus parent), `mod+h`/`mod+v` (split explicite — `ALT+E`
togglesplit s'en rapproche) et `mod+space` (bascule focus flottant/tuilé).

> Deux conséquences assumées. `ALT+lettre` n'atteint plus les menus des
> applications GTK/Qt (`ALT+F` fichier, `ALT+E` édition) — c'était déjà le cas
> sous i3. Et sur Linux, herdr perd `alt+1..9` et `alt+w`, captés par Hyprland :
> son config est templatisé pour ne garder que `prefix+1..9` et `prefix+w`, qui
> fonctionnent sur les deux machines. Sur macOS, herdr conserve ses accès ALT.

Versionner `bindings.conf` a un coût : ce fichier ne suivra plus les évolutions
d'Omarchy. À comparer au défaut après une mise à jour majeure avec la boucle
`diff` ci-dessous.

### Suivi des thèmes

`omarchy theme set <nom>` ne modifie aucun fichier de config : il réécrit le
contenu de `~/.config/omarchy/current/theme/`. Les configs y pointent, donc elles
suivent le thème sans que chezmoi ait quoi que ce soit à réappliquer.

| App    | Mécanisme                                                                     |
| ------ | ----------------------------------------------------------------------------- |
| ghostty | `config-file = ?"…/current/theme/ghostty.conf"` — fourni par chaque thème      |
| nvim   | `plugins/themes.lua` charge `…/current/theme/neovim.lua`, une spec lazy.nvim   |
| tmux   | `themed/tmux.conf.tpl` traduit `colors.toml` en `@thm_*`, sourcé après Catppuccin |
| btop   | natif Omarchy, le dépôt ne versionne pas `btop.conf`                          |

Sur macOS, aucun de ces fichiers n'existe : ghostty et nvim retombent sur
Catppuccin, qui suit la bascule clair/sombre du système.

Le hook `hooks/theme-set.d/reload-tmux` resource `~/.tmux.conf` après un
changement, pour que les sessions ouvertes se recolorent. Neovim n'est pas
rechargé : un thème différent implique un autre plugin, donc `:Lazy sync` puis
relance.

> **La police est le seul point de friction.** `omarchy font set` fait un `sed -i`
> sur la ligne `font-family` de `~/.config/ghostty/config`, que le dépôt gère —
> le prochain `chezmoi apply` écrase donc le choix. Pour changer de police
> durablement : l'éditer dans le dépôt, ou récupérer le choix d'Omarchy avec
> `chezmoi add ~/.config/ghostty/config`.

### Le shell Quickshell

`~/.config/omarchy/shell.json` décrit la barre : disposition, plugins activés,
réglages par widget. Il est versionné **tel quel**, car c'est précisément ce
qu'on veut retrouver à l'identique d'une machine à l'autre.

Deux réserves, à connaître :

- `primaryScreen` en est retiré. Il vaut `DP-2` ici, ce qui ne veut rien dire
  ailleurs ; sans lui le shell choisit l'écran seul.
- Omarchy **réécrit ce fichier** lors de certaines migrations (le passage à
  Quattro a renommé tous les ids `whiterose.*` en `omarchy.*`). Après un
  `omarchy update` qui touche la barre, récupérer le résultat avec
  `chezmoi re-add ~/.config/omarchy/shell.json` — sinon le prochain `apply`
  restaure la version d'avant migration et casse la barre.

Les plugins maison vivent dans `.config/omarchy/plugins/local.*`. `Bar.qml`
instancie chaque widget en dur : un widget dont l'outil sous-jacent est absent
doit donc se retirer lui-même de la barre plutôt que de ne pas être déployé.
`Voxtype.qml` et `Tapo.qml` suivent tous deux ce motif — une sonde `Process` au
démarrage, une propriété `installed`, un `visible` qui en dépend.

### Domotique Tapo

Trois ampoules TP-Link pilotées en local, sans cloud. Quatre pièces :

| Fichier                                        | Rôle                                      |
| ---------------------------------------------- | ----------------------------------------- |
| `dot_local/bin/executable_tapo-ctl.tmpl`       | l'outil ; shebang templaté vers son venv  |
| `dot_config/tapo-ctl/create_private_devices.json.tmpl` | inventaire des lampes             |
| `dot_config/omarchy/plugins/local.menubar/Tapo.qml` | la pastille et son panneau           |
| `dot_config/omarchy/hooks/theme-set.d/tapo-lamps` | aligne les lampes sur le thème actif   |

**Trois niveaux de confidentialité**, traités différemment :

- Les *préférences* (noms des lampes, modèles, rôles de couleur) sont dans le
  dépôt : elles doivent suivre d'une machine à l'autre.
- L'*email du compte* et les *adresses IP* sont demandés par `chezmoi init` et
  mémorisés dans `~/.config/chezmoi/chezmoi.toml`. Ils dépendent du réseau, pas
  des goûts. Répondre vide désactive proprement la lampe concernée
  (champ `enabled`), et un email vide n'installe aucune domotique du tout.
- Le *mot de passe* n'est ni dans le dépôt ni dans `chezmoi.toml`, qui sont du
  texte en clair. `.chezmoiscripts/run_once_after_60-tapo.sh` le réclame au
  premier `apply` et le range dans le trousseau, d'où `tapo-ctl` le relit via
  `secret-tool`. Pour le changer ensuite :

  ```sh
  secret-tool store --label='Tapo' service tapo-ctl username <ton-email-tapo>
  ```

Le même script installe `python-kasa` dans un venv dédié
(`~/.local/share/tapo-ctl/venv`) plutôt qu'en paquet système : le shebang de
`tapo-ctl` pointe droit dessus, à l'abri des montées de version de Python
d'Arch. Une machine sans compte Tapo ne reçoit rien de tout ça, et la pastille
se retire d'elle-même de la barre.

## Claude Code

`dot_claude/` versionne ce qui est *réglage* — `settings.json`, agents, skills,
rules, hooks — et laisse dehors ce qui est *état* : sessions, historique, cache
des plugins. La frontière est tenue par `dot_claude/.gitignore`, avec une seule
exception, `plugins/claude-hud/config.json`, qui est bien un réglage même s'il
vit au milieu du cache.

### Statusline

Le HUD de la statusline vient de [claude-hud](https://github.com/jarrodwatts/claude-hud),
installé depuis sa propre marketplace. `settings.json` déclare la marketplace et
active le plugin, mais le clone lui-même vit sous `~/.claude/plugins/`, hors du
dépôt : `.chezmoiscripts/36-claude-plugins.sh` le repose s'il manque. Comme les
plugins herdr, il rejoue à chaque `apply` plutôt qu'une seule fois, puisque le
cache peut être purgé sans que la déclaration bouge.

`/claude-hud:setup` génère normalement une ligne de commande d'une centaine de
caractères avec le chemin absolu du runtime en dur — `/opt/homebrew/bin/node` sur
macOS, `/usr/bin/node` sur Arch. Impossible à versionner tel quel. La statusline
pointe donc sur `hooks/claude-hud-statusline.sh`, qui résout le runtime (bun s'il
existe, node sinon) et la version du plugin au lancement.

### Permissions

Trois couches, du plus dur au plus souple :

| Couche       | Portée                                             | Contournable ? |
| ------------ | -------------------------------------------------- | -------------- |
| `sandbox`    | isolation OS — bubblewrap sur Arch, Seatbelt sur macOS | non         |
| `deny`       | règles Claude Code, évaluées avant tout le reste    | non par le modèle |
| `ask`        | demande confirmation, même si une règle `allow` correspond | oui, par l'humain |

Le sandbox tourne en `autoAllowBashIfSandboxed` : une commande qui tient dans
l'isolation s'exécute sans confirmation. C'est **moins** de friction et **plus**
de garanties qu'une liste `allow` — celle-ci est donc restée vide, elle ferait
double emploi. Ce qui sort du sandbox (réseau vers un hôte non listé, notamment)
retombe sur le flux de permissions normal.

`deny` couvre deux familles : la lecture de secrets (`.env`, clés privées,
`~/.ssh`, `~/.gnupg`, les credentials cloud, et le trousseau de Claude Code
lui-même) et les commandes irréversibles. Tout `rm` récursif y est, dans ses six
écritures possibles — `-r`, `-R`, `--recursive`, seuls ou après d'autres flags.
`sh`, `bash` et `zsh` nus y sont aussi : c'est la moitié exécutante d'un
`curl … | sh`, que Claude Code découpe en sous-commandes avant de les évaluer.

`Edit(~/.claude/settings.json)` est refusé : les changements de config passent
par le dépôt, donc par un diff git relu, jamais par une écriture directe.

> **Limite connue sur Linux.** Six règles reposent sur un glob d'extension
> (`*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.kdbx`, `.env.*.local`) que le sandbox
> ne sait pas traduire en restriction noyau — `claude doctor` le signale à
> chaque passage. La protection reste applicative : les outils de lecture et les
> `cat`/`head`/`sed` lancés en Bash sont bloqués, un script Python qui ouvre le
> fichier lui-même ne l'est pas. Les chemins du home, eux, sont couverts au
> niveau OS par `sandbox.credentials.files`.

`disableBypassPermissionsMode` neutralise `--dangerously-skip-permissions`, et
`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` retire les credentials Anthropic et cloud de
l'environnement de tous les sous-processus, sandbox ou pas.

### Raccourcis shell

`dot_claude_cli.zsh` pose `~/.claude_cli.zsh`, sourcé par le `.zshrc` juste
après `.aliases`. Sept commandes qui répondent, lisent, modifient ou relisent
sans qu'il y ait de session à ouvrir ni de modèle à choisir :

| Commande | Modèle | Outils | Usage |
| -------- | ------ | ------ | ----- |
| `cq` | haiku / low | aucun | question de culture générale, sans contexte projet |
| `cqr` | sonnet / high | lecture | question sur le code du dossier courant |
| `cqe` | sonnet / high | lecture + écriture | modification ciblée, éditions appliquées sans confirmation |
| `cqf` | sonnet / high | lecture + écriture | `<commande qui échoue> 2>&1 \| cqf` — diagnostic puis correctif |
| `cqc` | sonnet / low | aucun | message de commit à partir de l'index |
| `cqv` | opus / high | lecture | revue du diff courant, ou face à une base donnée |
| `cqd` | opus / max | session interactive | gros sujet, ouvert en mode plan |

Trois choix méritent d'être notés. **Le prompt part toujours par stdin**, jamais
en argument : `--tools`, `--allowedTools` et `--add-dir` sont variadiques, et un
prompt placé derrière est avalé comme nom d'outil — `claude` répond alors
« Input must be provided ». Passer par stdin règle aussi le quoting et permet à
n'importe quelle commande de piper son contexte dans `cq`.

**Aucune fonction n'ouvre `Bash`.** `cqe` et `cqf` écrivent sans confirmation,
mais leur liste d'outils s'arrête à `Read`, `Edit`, `Write`, `Grep` et `Glob` :
pas de commande auto-approuvée, et un `git diff` suffit à défaire la passe. La
liste est déclarée deux fois, en `--permission-mode acceptEdits` et en
`--allowedTools` explicite, parce que `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB` remet
le mode de permission à `default` dès que la commande est lancée depuis une
session Claude Code — et c'est justement ce que ce message d'avertissement
demande de faire.

`cq` tourne en `--safe-mode` : ni `CLAUDE.md`, ni skills, ni MCP, ni hooks. Une
question qui n'a rien à voir avec le projet courant n'a pas à traîner ses
conventions, et le démarrage y gagne. Le rendu markdown (`glow`, sinon `bat`)
ne s'applique que si la sortie va au terminal, pour que `cq … | jq` et
`git commit -m "$(cqc)"` reçoivent du texte brut. Les modèles et niveaux
d'effort se surchargent par `CQ_ASK_*`, `CQ_CODE_*` et `CQ_DEEP_*`.

## Dépendances externes

- **zsh** : oh-my-zsh, plus trois plugins à cloner dans `$ZSH_CUSTOM/plugins/` —
  [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions),
  [zsh-completions](https://github.com/zsh-users/zsh-completions),
  [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting).
- **Neovim** : config [LazyVim](https://www.lazyvim.org/), les plugins s'installent
  au premier lancement (`lazy-lock.json` fait foi).
- **tmux** : [tpm](https://github.com/tmux-plugins/tpm) à cloner dans
  `~/.config/tmux/plugins/tpm`, puis `<C-a> I`.
