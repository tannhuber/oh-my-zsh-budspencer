##################################################
# vim: ft=zsh ts=2 sw=2 sts=2
#
# File:
#       terencehill.zsh-theme
#
# Description:
#       Terencehill theme for oh-my-zsh
#
# Maintainer:
#       Joseph Tannhuber
#
# Sections:
#    -> Color definitions
#    -> Prompt components
#    -> Show prompt
##################################################

##################################################
# => Color definitions
##################################################
# INSERT mode color
INSCOL=136
INSCURSCOL="#b58900"

# NORMAL mode color
NORMCOL=33
NORMCURSCOL="#268bd2"

# REPLACE mode color
REPCOL=160
REPCURSCOL="#dc322f"

##################################################
# => Prompt components
##################################################
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  local user=`whoami`

  if [[ "$user" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    print -n "%(!.%{%F{166}%}.)$user@%m ▷ "
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
      print -n "%F{61}%"
    else
      print -n "%F{241}%"
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
    echo -n "${ref/refs\/heads\//  }${vcs_info_msg_0_%% }${mode} ▷ "
  fi
}

prompt_hg() {
  local rev status
  if $(hg id >/dev/null 2>&1); then
    if $(hg prompt >/dev/null 2>&1); then
      if [[ $(hg prompt "{status|unknown}") = "?" ]]; then
        # if files are not added
        print -n "%F{241}%"
        st='±'
      elif [[ -n $(hg prompt "{status|modified}") ]]; then
        # if any modification
        print -n "%F{$INSCOL}%"
        st='±'
      else
        # if working copy is clean
        print -n "%F{241}%"
      fi
      echo -n $(hg prompt "☿ {rev}@{branch}") $st "▷ "
    else
      st=""
      rev=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(hg id -b 2>/dev/null)
      if `hg st | grep -Eq "^\?"`; then
        print -n "%F{$REPCOL}%"
        st='±'
      elif `hg st | grep -Eq "^(M|A)"`; then
        print -n "%F{$INSCOL}%"
        st='±'
      else
        print -n "%F{64}%"
      fi
      echo -n "☿ $rev@$branch" $st "▷ "
    fi
  fi
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    print -n "(`basename $virtualenv_path`) ▷ "
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{$REPCOL}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{166}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{37}%}⚙"

  [[ -n "$symbols" ]] && print -n "$symbols "
}

# Vi mode indicators
set_vi_mode() {
  case "$1" in
    "i")
      indcol=$INSCOL
      cursorcolor="$INSCURSCOL"
      zsh_vi_mode="INSERT"
      ;;
    "n")
      indcol=$NORMCOL
      cursorcolor="$NORMCURSCOL"
      zsh_vi_mode="NORMAL"
      ;;
    "r")
      indcol=$REPCOL
      cursorcolor="$REPCURSCOL"
      zsh_vi_mode="REPLACE"
      ;;
  esac
  dir_mode="%{%F{$indcol}%}◁ %~%{$reset_color%}"
  vim_mode="%{%F{$indcol}%}"
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
print -n "${vim_mode}${zsh_vi_mode} ▷ "
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
}

##################################################
# => Show prompt
##################################################
KEYTIMEOUT=1
set_vi_mode "i"
PROMPT='%{%f%b%k%}$(build_prompt)'
RPROMPT='${dir_mode}'
