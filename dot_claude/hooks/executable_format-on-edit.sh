#!/bin/bash
# Format files after Claude edits them.
# Detects the project's formatter (Biome, Prettier, dprint)
# and runs it on the modified file.

# Read the tool result from stdin to get the file path.
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only format known file types.
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.scss|*.html|*.vue|*.svelte|*.md)
    ;;
  *)
    exit 0
    ;;
esac

# Find the project root (nearest package.json or git root).
DIR=$(dirname "$FILE_PATH")
PROJECT_ROOT=""
while [ "$DIR" != "/" ]; do
  if [ -f "$DIR/package.json" ] || [ -d "$DIR/.git" ]; then
    PROJECT_ROOT="$DIR"
    break
  fi
  DIR=$(dirname "$DIR")
done

if [ -z "$PROJECT_ROOT" ]; then
  exit 0
fi

# Detect and run the formatter.
if [ -f "$PROJECT_ROOT/biome.json" ] || [ -f "$PROJECT_ROOT/biome.jsonc" ]; then
  npx @biomejs/biome format --write "$FILE_PATH" 2>/dev/null
elif [ -f "$PROJECT_ROOT/.prettierrc" ] || [ -f "$PROJECT_ROOT/.prettierrc.json" ] || [ -f "$PROJECT_ROOT/.prettierrc.js" ] || [ -f "$PROJECT_ROOT/.prettierrc.yaml" ] || [ -f "$PROJECT_ROOT/prettier.config.js" ] || [ -f "$PROJECT_ROOT/prettier.config.mjs" ]; then
  npx prettier --write "$FILE_PATH" 2>/dev/null
elif [ -f "$PROJECT_ROOT/dprint.json" ]; then
  npx dprint fmt "$FILE_PATH" 2>/dev/null
fi

exit 0
