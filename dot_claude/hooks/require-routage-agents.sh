#!/bin/bash
# PreToolUse : refuse de lancer un subagent (Agent, Workflow) ou de modifier
# un fichier de subagent (.claude/agents/*.md) tant que le skill
# routage-agents n'a pas été chargé avec succès dans la session.
# Ne s'applique pas dans un subagent (agent_id) ni dans une session --agent
# (agent_type) : ces agents n'ont pas forcément l'outil Skill et resteraient
# bloqués sans recours.

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
AGENT=$(printf '%s' "$INPUT" | jq -r '(.agent_id // "") + (.agent_type // "")')
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty')

[ -n "$AGENT" ] && exit 0

case "$TOOL" in
  Agent|Workflow) ;;
  Write|Edit)
    FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
    case "$FILE_PATH" in
      */.claude/agents/*.md) ;;
      *) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
esac

# Transcript illisible : on ne bloque pas, faute de pouvoir vérifier.
[ -r "$TRANSCRIPT" ] || exit 0

# Preuves de chargement acceptées, lues au niveau racine de chaque ligne
# (le modèle ne peut pas y écrire) :
# - résultat réussi de l'outil Skill, posé par Claude Code ;
# - message de l'utilisateur contenant la commande /routage-agents.
LOADED=$(grep -F 'routage-agents' "$TRANSCRIPT" | jq -c '
  select(
    (.toolUseResult | type == "object"
      and .success == true and .commandName == "routage-agents")
    or
    (.type == "user" and .message.role == "user"
      and ([.message.content
            | if type == "string" then . else (.[]? | select(.type == "text") | .text) end]
           | any(contains("<command-name>/routage-agents</command-name>"))))
  )' 2>/dev/null | head -1)

[ -n "$LOADED" ] && exit 0

jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "Charger d'\''abord le skill routage-agents (outil Skill ou /routage-agents), choisir le modèle selon ses règles, puis relancer cette action."
  }
}'
