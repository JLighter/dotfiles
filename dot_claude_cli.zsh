# ~/.claude_cli.zsh — raccourcis Claude Code en une commande.
# Source : ~/.dotfiles/dot_claude_cli.zsh, sourcé depuis ~/.zshrc.
#
# Piège CLI contourné ici : --tools, --allowedTools et --add-dir sont
# variadiques. Un prompt placé après est avalé comme nom d'outil et claude
# répond « Input must be provided either through stdin or as a prompt
# argument ». D'où la règle : le prompt passe toujours par stdin, jamais en
# argument positionnel.

command -v claude >/dev/null 2>&1 || return 0

# ── Réglages (surchargeables avant le source, ou exportés à la volée) ────────
# ask  : réponse immédiate, aucun outil, aucun contexte projet
# code : lecture et écriture dans le dépôt courant
# deep : session interactive pour les gros sujets
: ${CQ_ASK_MODEL:=haiku}    ${CQ_ASK_EFFORT:=low}
: ${CQ_CODE_MODEL:=sonnet}  ${CQ_CODE_EFFORT:=high}
: ${CQ_DEEP_MODEL:=opus}    ${CQ_DEEP_EFFORT:=max}

# ── Helpers ─────────────────────────────────────────────────────────────────

# Rend le markdown seulement quand la sortie va au terminal : un `cq … | jq`
# ou un `$(cqc)` reçoit du texte brut, sans code couleur.
_cq_render() {
  if [[ ! -t 1 ]]; then cat
  elif command -v glow >/dev/null 2>&1; then glow -
  elif command -v bat >/dev/null 2>&1; then bat -pp -l md --color=always
  else cat
  fi
}

# _cq_run <prompt> <flags…> — envoie le prompt par stdin, en y concaténant le
# contenu piped s'il y en a un.
_cq_run() {
  local prompt=$1; shift
  local piped=''
  [[ -t 0 ]] || piped=$(cat)
  # Un pipe vide (commande sans sortie) ne doit pas partir en appel API.
  if [[ -n ${piped//[[:space:]]/} ]]; then
    { print -r -- "$prompt"; print -r -- $'\n--- entrée fournie via stdin ---'; print -r -- "$piped"; } \
      | command claude -p "$@" | _cq_render
  else
    print -r -- "$prompt" | command claude -p "$@" | _cq_render
  fi
}

_cq_in_repo() {
  git rev-parse --git-dir >/dev/null 2>&1 && return 0
  print -u2 "${1}: pas un dépôt git"
  return 2
}

# Les lockfiles noient un diff sans rien apprendre au modèle.
_cq_diff_excludes=(':(exclude)*.lock' ':(exclude)*-lock.json' ':(exclude)pnpm-lock.yaml' ':(exclude)yarn.lock')

# ── 1. Question rapide — aucun outil, aucun CLAUDE.md, aucun MCP ────────────
# cq "différence entre COPY et ADD dans un Dockerfile"
# git log --oneline -20 | cq "résume ce qui a bougé"
claude-quick-ask() {
  (( $# )) || { print -u2 "usage: cq <question>   (accepte aussi un pipe)"; return 2; }
  _cq_run "$*" \
    --safe-mode --model "$CQ_ASK_MODEL" --effort "$CQ_ASK_EFFORT" --name 'cq:ask' \
    --append-system-prompt 'Réponds en français, directement, sans préambule ni conclusion. Quelques phrases ou une liste courte. Donne les commandes exactes quand elles répondent à la question.' \
    --tools ""
}

# ── 2. Question sur le code du dossier courant — lecture seule ──────────────
# cqr "où est géré le refresh du token keycloak ?"
claude-quick-read() {
  (( $# )) || { print -u2 "usage: cqr <question sur le dossier courant>"; return 2; }
  _cq_run "$*" \
    --model "$CQ_CODE_MODEL" --effort "$CQ_CODE_EFFORT" --name 'cq:read' \
    --append-system-prompt 'Réponds en français, sans préambule. Cite tes sources au format chemin:ligne. Ne modifie aucun fichier.' \
    --tools Read Grep Glob
}

# ── 3. Modification rapide — applique les éditions sans demander ────────────
# cqe "passe les @Input() de user-card.component.ts en input()"
claude-quick-edit() {
  (( $# )) || { print -u2 "usage: cqe <modification à appliquer dans le dossier courant>"; return 2; }
  _cq_run "$*" \
    --model "$CQ_CODE_MODEL" --effort "$CQ_CODE_EFFORT" --name 'cq:edit' \
    --permission-mode acceptEdits \
    --append-system-prompt "Applique exactement la modification demandée, rien de plus : pas de refacto opportuniste, pas de fichier annexe. Termine par la liste des fichiers touchés. Réponds en français." \
    --allowedTools 'Read,Edit,Write,Grep,Glob' \
    --tools Read Edit Write Grep Glob
}

# ── 4. Correction d'une erreur collée au pipe ───────────────────────────────
# pnpm nx build dashboard 2>&1 | cqf
claude-quick-fix() {
  [[ -t 0 ]] && { print -u2 "usage: <commande qui échoue> 2>&1 | cqf [précision]"; return 2; }
  local err; err=$(cat)
  [[ -n ${err//[[:space:]]/} ]] || { print -u2 "cqf: rien reçu sur stdin"; return 2; }
  print -r -- "$err" | _cq_run "Diagnostique l'erreur ci-dessous, survenue dans le dépôt courant, puis corrige-la. ${*:-}" \
    --model "$CQ_CODE_MODEL" --effort "$CQ_CODE_EFFORT" --name 'cq:fix' \
    --permission-mode acceptEdits \
    --append-system-prompt "Français. Donne la cause en une phrase, puis applique le correctif minimal. Si la cause est incertaine, ne modifie rien et dis ce qu'il faut vérifier." \
    --allowedTools 'Read,Edit,Write,Grep,Glob' \
    --tools Read Edit Write Grep Glob
}

# ── 5. Message de commit à partir de l'index ────────────────────────────────
# git add -p && git commit -m "$(cqc)"
claude-quick-commit() {
  _cq_in_repo cqc || return 2
  git diff --staged --quiet -- . $_cq_diff_excludes \
    && { print -u2 "cqc: rien de significatif dans l'index (git add d'abord)"; return 2; }
  { print -r -- "Rédige le message du commit correspondant au diff ci-dessous, en Conventional Commits. N'affiche que le message, rien d'autre : un titre <type>(<scope>): <sujet> de 72 caractères maximum à l'impératif, puis, seulement s'il apporte quelque chose, une ligne vide et 1 à 3 puces expliquant le pourquoi. Pas de bloc de code, pas de commentaire."
    git diff --staged -- . $_cq_diff_excludes
  } | command claude -p --safe-mode --model "$CQ_CODE_MODEL" --effort low --name 'cq:commit' --tools ""
}

# ── 6. Revue rapide d'un diff — lecture seule ───────────────────────────────
# cqv            → diff du working tree vs HEAD
# cqv main       → diff vs main
claude-quick-review() {
  _cq_in_repo cqv || return 2
  local base=${1:-HEAD}
  local diff; diff=$(git diff "$base" -- . $_cq_diff_excludes) || return 2
  [[ -n $diff ]] || { print -u2 "cqv: aucun changement face à $base"; return 2; }
  print -r -- "$diff" | _cq_run "Relis le diff ci-dessous (base: $base). Signale les bugs, régressions et écarts aux conventions du dépôt, du plus grave au plus anodin, chacun avec son chemin:ligne. Si tu ne trouves rien de sérieux, dis-le en une ligne plutôt que d'inventer des remarques de forme." \
    --model "$CQ_DEEP_MODEL" --effort "$CQ_CODE_EFFORT" --name 'cq:review' \
    --append-system-prompt 'Français. Pas de résumé du diff, uniquement les problèmes.' \
    --tools Read Grep Glob
}

# ── 7. Gros sujet — session interactive, mode plan, modèle le plus fort ─────
# cqd "comment découper le module de paiement"
claude-quick-deep() {
  if (( $# )); then
    command claude --model "$CQ_DEEP_MODEL" --effort "$CQ_DEEP_EFFORT" --permission-mode plan "$*"
  else
    command claude --model "$CQ_DEEP_MODEL" --effort "$CQ_DEEP_EFFORT" --permission-mode plan
  fi
}

# ── Raccourcis ──────────────────────────────────────────────────────────────
alias cq='claude-quick-ask'
alias cqr='claude-quick-read'
alias cqe='claude-quick-edit'
alias cqf='claude-quick-fix'
alias cqc='claude-quick-commit'
alias cqv='claude-quick-review'
alias cqd='claude-quick-deep'

# Sessions interactives (cc est déjà le compilateur C, on ne le masque pas)
alias cl='claude'
alias clc='claude --continue'
alias clr='claude --resume'
