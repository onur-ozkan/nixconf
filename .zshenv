bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# bash scripts
PATH="$HOME/.local/bin:$PATH"

# dwmblock scripts
PATH="$HOME/.local/bin/statusbar:$PATH"

# defaults
export TERM=screen-256color
export EDITOR=vim
export TERMINAL=st
export FZF_DEFAULT_COMMAND='rg --hidden -l "" -g "!.git"'
