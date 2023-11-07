bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

alias vim="nvim"
alias sudo="doas"

# bash scripts
PATH="$HOME/.local/bin:$PATH"

# dwmblock scripts
PATH="$HOME/.local/bin/statusbar:$PATH"

# rust
PATH="$HOME/.cargo/bin:$PATH"

# golang
export PATH="$PATH:$HOME/go/bin/"
export GOPATH="$HOME/go"

# defaults
export TERM=screen-256color
export EDITOR=nvim
export TERMINAL=st
export FZF_DEFAULT_COMMAND='rg --hidden -l "" -g "!.git"'

# Enable drm for qutebrowser
export QTWEBENGINE_CHROMIUM_FLAGS="--widevine-path=/usr/lib/chromium/libwidevinecdm.so --disable-gpu-vsync"
