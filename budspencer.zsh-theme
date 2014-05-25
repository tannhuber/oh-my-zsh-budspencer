# vim: ft=zsh ts=2 sw=2 sts=2
#
# Budspencer theme
#
# Code snippets were stolen from agnoster theme and Paul Goscicki's zsh prompt
# http://paulgoscicki.com/archives/2012/09/vi-mode-indicator-in-zsh-prompt/
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://github.com/Lokaltog/powerline-fonts).
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# This theme is for people working in vi mode and want to see, at a glance,
# whether they are in INSERT, NORMAL or REPLACE mode. In addition, budspencer
# theme provides a noticeable prompt in order to find commands quickly when
# scrolling back within the terminal.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'
SEGMENT_SEPARATOR=''

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  local user=`whoami`

  if [[ "$user" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment 235 default "%(!.%{%F{166}%}.)$user@%m"
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  local ref dirty mode repo_path
  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git show-ref --head -s --abbrev |head -n1 2> /dev/null)"
    if [[ -n $dirty ]]; then
      prompt_segment 61 0
    else
      prompt_segment 241 0
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr '✚'
    zstyle ':vcs_info:git:*' unstagedstr '●'
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info
    echo -n "${ref/refs\/heads\// }${vcs_info_msg_0_%% }${mode}"
  fi
}

prompt_hg() {
  local rev status
  if $(hg id >/dev/null 2>&1); then
    if $(hg prompt >/dev/null 2>&1); then
      if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
        # if files are not added
        prompt_segment 241 0
        st='±'
      elif [[ -n $(hg prompt "{status|modified}") ]]; then
        # if any modification
        prompt_segment 136 0
        st='±'
      else
        # if working copy is clean
        prompt_segment 241 0
      fi
      echo -n $(hg prompt "☿ {rev}@{branch}") $st
    else
      st=""
      rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(hg id -b 2>/dev/null)
      if `hg st | grep -Eq "^\?"`; then
        prompt_segment 160 0
        st='±'
      elif `hg st | grep -Eq "^(M|A)"`; then
        prompt_segment 136 0
        st='±'
      else
        prompt_segment 64 0
      fi
      echo -n "☿ $rev@$branch" $st
    fi
  fi
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment 33 0 "(`basename $virtualenv_path`)"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{160}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{166}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{37}%}⚙"

  [[ -n "$symbols" ]] && prompt_segment 0 default "$symbols"
}

set_vi_mode() {
  case "$1" in
    "i")
      fgcolor=136
      cursorcolor="#b58900"
      ZSH_VI_MODE="INSERT"
      ;;
    "n")
      fgcolor=33
      cursorcolor="#268bd2"
      ZSH_VI_MODE="NORMAL"
      ;;
    "r")
      fgcolor=160
      cursorcolor="#dc322f"
      ZSH_VI_MODE="REPLACE"
      ;;
  esac
  dir_mode="%{%F{$fgcolor}%}%{%K{$fgcolor}%}%{%F{0}%}%} %~ %{$reset_color%}"
  vim_mode="%{%K{$fgcolor}%}%{%F{0}%}"
  echo -ne "\033]12;$cursorcolor\007"
}

vi-edit-command-line() {
  set_vi_mode "i"
  edit-command-line
}
zle -N vi-edit-command-line
bindkey -M vicmd "v" vi-edit-command-line

function zle-keymap-select {
if [ "$KEYMAP" = "vicmd" ]
then
  set_vi_mode "n"
else
  if [[ "$ZLE_STATE" = *overwrite* ]]
  then
    set_vi_mode "r"
  else
    set_vi_mode "i"
  fi
fi
zle reset-prompt
}
zle -N zle-keymap-select

function zle-line-finish {
set_vi_mode "i"
}
zle -N zle-line-finish

function TRAPINT() {
set_vi_mode "i"
return $(( 128 + $1 ))
}

function prompt_mode() {
prompt_segment ${fgcolor} 0
print -n ${vim_mode}${ZSH_VI_MODE}
}

# Main prompt
build_prompt() {
  RETVAL=$?
  prompt_status
  prompt_virtualenv
  prompt_context
  prompt_mode
  prompt_git
  prompt_hg
  prompt_end
}

set_vi_mode "i"
PROMPT='%{%f%b%k%}$(build_prompt) '
RPROMPT='${dir_mode}'
