#!/bin/sh
# tpm, le gestionnaire de plugins tmux. Le .tmux.conf le charge depuis
# ~/.config/tmux/plugins/. Les plugins eux-mêmes s'installent avec <C-a> I.
set -eu

TPM="$HOME/.config/tmux/plugins/tpm"

if [ -d "$TPM" ]; then
    printf '\033[1;34m::\033[0m tpm déjà présent\n'
else
    printf '\033[1;34m::\033[0m Clone de tpm\n'
    git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM"
fi
