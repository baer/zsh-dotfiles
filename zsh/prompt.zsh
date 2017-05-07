autoload colors && colors

####################################################################################################
#                                          Git
####################################################################################################

if (( $+commands[git] ))
then
  git="$commands[git]"
else
  git="/usr/bin/git"
fi

git_branch() {
  echo $($git symbolic-ref HEAD 2>/dev/null)
}

git_dirty() {
  if $(! $git status -s &> /dev/null)
  then
    echo ""
  else
    if [[ $($git status --porcelain) == "" ]]
    then
      echo "on %{$fg_bold[green]%}$(git_prompt_info)%{$reset_color%}"
    else
      echo "on %{$fg_bold[red]%}$(git_prompt_info) ✗%{$reset_color%}"
    fi
  fi
}

git_prompt_info () {
 ref=$(git_branch) || return
# echo "(%{\e[0;33m%}${ref#refs/heads/}%{\e[0m%})"
 echo "${ref#refs/heads/}"
}

unpushed () {
  $git cherry -v @{upstream} 2>/dev/null
}

need_push () {
  if [[ $(unpushed) == "" ]]
  then
    echo " "
  else
    echo " with %{$fg_bold[magenta]%}unpushed%{$reset_color%} "
  fi
}

git_prompt () {
  echo " $(git_dirty)$(need_push)"
}

####################################################################################################
#                                          JavaScript
####################################################################################################

nvm_prompt() {
  $(type nvm >/dev/null 2>&1) || return

  local nvm_prompt
  nvm_prompt=$(nvm current 2>/dev/null)
  [[ "${nvm_prompt}x" == "x" ]] && return
  echo "%{$fg_bold[yellow]%}Node $nvm_prompt%{$reset_color%}"
}

npm_prompt() {
  $(type npm >/dev/null 2>&1) || return

  local npm_prompt
  npm_prompt=$(npm --version 2>/dev/null)
  echo "%{$fg_bold[yellow]%}npm $npm_prompt%{$reset_color%}"
}

####################################################################################################
#                                   Working Directory
####################################################################################################

# http://stevelosh.com/blog/2010/02/my-extravagant-zsh-prompt/#current-directory
collapse_pwd () {
  echo $(pwd | sed -e "s,^$HOME,~,")
}

directory_name() {
  echo "%{$fg_bold[cyan]%}$(collapse_pwd)%{$reset_color%}"
}

####################################################################################################
#                                          Misc.
####################################################################################################

user_name () {
  echo "%{$fg[magenta]%}%n%{$reset_color%}"
}

host () {
  echo "%{$fg[yellow]%}%m%{$reset_color%}"
}

####################################################################################################

export PROMPT=$'\n$(user_name) at $(host) in $(directory_name)$(git_prompt)\n› '

set_prompt () {
  export RPROMPT="%{$fg_bold[cyan]%}$(nvm_prompt) / $(npm_prompt)%{$reset_color%}"
}

precmd() {
  title "zsh" "%m" "%55<...<%~"
  set_prompt
}
