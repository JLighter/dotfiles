# Dotfiles

Gérés avec [chezmoi](https://www.chezmoi.io/). Deux cibles : **macOS** et **Omarchy** (Arch + Hyprland).

Le dépôt est la *source*, `$HOME` est la *cible*. Les fichiers ne sont pas symlinkés :
`chezmoi apply` écrit les fichiers réels, après avoir évalué les templates pour la
machine courante. `chezmoi diff` montre ce qui changerait avant d'appliquer.

## Bootstrap sur une nouvelle machine

Une seule commande, identique sur macOS et sur Omarchy :

```sh
sh -c "$(curl -fsLS https://raw.githubusercontent.com/jlighter/dotfiles/main/bootstrap.sh)"
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

| Source                          | Cible                     |
| ------------------------------- | ------------------------- |
| `dot_zshrc.tmpl`                | `~/.zshrc` (template)     |
| `dot_config/nvim/`              | `~/.config/nvim/`         |
| `dot_claude/hooks/executable_*` | fichier déployé en `+x`   |

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

## Dépendances externes

- **zsh** : oh-my-zsh, plus trois plugins à cloner dans `$ZSH_CUSTOM/plugins/` —
  [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions),
  [zsh-completions](https://github.com/zsh-users/zsh-completions),
  [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting).
- **Neovim** : config [LazyVim](https://www.lazyvim.org/), les plugins s'installent
  au premier lancement (`lazy-lock.json` fait foi).
- **tmux** : [tpm](https://github.com/tmux-plugins/tpm) à cloner dans
  `~/.config/tmux/plugins/tpm`, puis `<C-a> I`.
