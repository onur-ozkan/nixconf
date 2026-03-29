bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# defaults
export FZF_DEFAULT_COMMAND='rg --hidden -l "" -g "!.git"'
