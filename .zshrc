# Created by Onur Ozkan for 5.8

HISTSIZE=10000               # How many lines of history to keep in memory
SAVEHIST=10000               # Number of history entries to save to disk
HISTDUP=erase                # Erase duplicates in the history file
HISTFILE=~/.zsh_history      # Where to save history to disk
setopt    appendhistory      # Append history to the history file (no overwriting)
setopt    sharehistory       # Share history across terminals
setopt    incappendhistory   # Immediately append to the history file, not just when a term is killed

# Load version control information
autoload -Uz vcs_info
precmd() { vcs_info }

# Format the vcs_info_msg_0_ variable
zstyle ':vcs_info:git:*' formats '%F{#87af5f} %b%f'

# Set up the prompt (with git branch name)
setopt PROMPT_SUBST

ZSH_THEME_GIT_PROMPT_AHEAD="%{$fg_no_bold[cyan]%}->"
PROMPT='%F{#87af5f} %f %F{#f7ca88}%~%f ${vcs_info_msg_0_} $ '
