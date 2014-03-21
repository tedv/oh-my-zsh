dir=$(dirname $0)
source $dir/../git/git.plugin.zsh
source $dir/git-prompt.sh

function git_prompt_info() {
  dirty="$(parse_git_dirty)"
  __git_ps1 "${ZSH_THEME_GIT_PROMPT_PREFIX//\%/%%}%s${dirty//\%/%%}${ZSH_THEME_GIT_PROMPT_SUFFIX//\%/%%}"
}

function parse_git_dirty() {
  if [[ $(git diff --shortstat 2> /dev/null | tail -n1) != "" ]]; then
    echo "$ZSH_THEME_GIT_PROMPT_DIRTY"
  else
    echo "$ZSH_THEME_GIT_PROMPT_CLEAN"
  fi
}
