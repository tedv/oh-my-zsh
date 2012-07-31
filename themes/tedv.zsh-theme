# https://github.com/tedv zsh theme

# Store intermediate prompt data used in formatting in this table.
typeset -A PD

command_title () {
    ### this function sets the current command name in title bars, tabs, and screen lists
    ## inspired by: http://www.semicomplete.com/blog/2006/Jun/29
    if [[ -n ${SHELL_NAME} ]]
    then
	# allow the $cmnd_name to be set manually and override automatic values
	# to set the shell's title to "foo";	export SHELL_NAME=foo
	# to return to normal operation;	unset SHELL_NAME
	cmnd_name="${SHELL_NAME}"
    elif [[ 'fg' == "${${(Qz)@}[1]}" ]]
    then
	# this is a poor hack to replace 'fg' with a more sensical command
	# it really only works properly if only one job is suspended
	cmnd_name="${(qvV)jobtexts}"
    else
	# get the $cmnd_name from the current command being executed
	local cmnd_name="${1}"
    fi
    # make nonprintables visible
    # convert literal newline into "; " & literal tab into space
    cmnd_name="${(QV)${cmnd_name//$'\t'/ }//$'\n'/; }"
    # truncate the $cmnd_name
    cmnd_name="%80>...>${cmnd_name//\%/\%\%}%<<"
    [[ "${USERNAME}" != "${LOGNAME}" ]] && cmnd_name="${USERNAME}: ${cmnd_name}"
    # if the shell is running on an ssh connection, prefix the command with "$HOST: "
    [[ -n "${SSH_CONNECTION}" ]] && cmnd_name="${HOST}: ${cmnd_name}"
    ## add prefix, if defined
    [[ -n "${SHELL_PREFIX}" ]] && cmnd_name="${SHELL_PREFIX}: ${cmnd_name}"
    # don't confuse the display any more than required
    #	we'll put this back, if required, below
    setopt NO_PROMPT_SUBST LOCAL_OPTIONS
    case ${TERM} in
	xterm*)
	    print -Pn "\e]0;[${COLORTERM:-${TERM}}] ${(q)cmnd_name}\a" > ${TTY} # plain xterm title & icon name
	    ;;
	screen)
	    print -Pn "\ek${(q)cmnd_name}\e\\" > ${TTY} # screen title
	    ## for best results, see: http://smasher.org/zsh/screenrc
	    ## and modify to suit
	    ;;
	rxvt*)
	    print -Pn "\e]62;[${COLORTERM:-${TERM}}] ${(q)cmnd_name}\a" > ${TTY} # (m)rxvt title & icon name
	    print -Pn "\e]61;${(q)cmnd_name}\a" > ${TTY} # mrxvt tab name
	    ## there's no good way for the shell to know if it's running in rxvt or mrxvt.
	    ## this assumes mrxvt, but shouldn't hurt anything in rxvt.
	    ;;
    esac
}

# Determine how many CPUs are on this machine, to help color the load average.
count_cpus () {
    cpu_count=0

    ## linux
    [[ ${OSTYPE} == linux* ]] && { while read proc_cpu_count
	  do
        [[ ${proc_cpu_count} == processor* ]] && cpu_count=$[${cpu_count}+1]
	  done < /proc/cpuinfo
	  echo $cpu_count
      return 0
    }

    ## cygwin
    [[ 'cygwin' == ${OSTYPE} && -n ${NUMBER_OF_PROCESSORS} ]] && {
	  cpu_count=${NUMBER_OF_PROCESSORS}
	  echo $cpu_count
      return 0
    }

    ## FreeBSD, OpenBSD... (and darwin? not tested)
    { sysctl -n hw.ncpu 2> /dev/null | read cpu_count } && {
	  echo $cpu_count
      return 0
    }

    ## if all else fails, assume 1 CPU
    echo 1
    return 0
}
PD[cpu_count]=$(count_cpus)

# Determine the load average.
get_load () {
   # Look up the most recent load average.
   load="${${=$(uptime 2> /dev/null)}[-3,-3]:-?}"

   # Trim off the comma and everything after it, using regular expressions.
   load="${load/%${~:-,*}/}"
   echo $load
}

# Color the load average based on total CPU use.
color_load () {
   # Color based on load average.
   if [[ "${PD[cpu_count]}" -gt $1 ]]
   then
       echo "%{%F{green}%}$1"
   elif [[ $[${PD[cpu_count]} * 2] -ge $1 ]]
   then
       echo "%{%F{yellow}%}$1"
   else
       echo "%{%F{red}%}$1"
   fi
}

# Generate prompt text.
setup_prompt () {
  setopt PROMPT_SUBST

  # Change default highlighting when root.
  if [ `/usr/bin/id -u` = '0' ]; then
    PD[default_color]="red"
  else
    PD[default_color]="green"
  fi

  # Get the most recent load average and color it.
  PD[load]=$(get_load)
  local load_width=$[${#${PD[load]}} + 2]
  PD[load]=$(color_load ${PD[load]})
  PD[load]="%{%F{white}%}[${PD[load]}%{%F{white}%}]"

  # Determine how much spacing to add between the path and the load average,
  # in order to right justify the load.
  local termwidth=$[${COLUMNS}-1]
  local path_width="${#${(%):-%~ }}"
  local spacing_width=$[$termwidth - $load_width - $path_width]
  PD[path_load_spacing]="${(r:${spacing_width}:: :)}"

  PD[COLUMNS]=${COLUMNS}
}

precmd () {
  setup_prompt
}

# Redraw the prompt when the window size changes
TRAPWINCH () {
    zle || return 0
    [[ ${PD[COLUMNS]} -gt ${COLUMNS} ]] && echoti cud1
    setup_prompt
    zle reset-prompt
}
[[ 'cygwin' == ${OSTYPE} && 'xterm' == ${TERM} ]] && {    
    unset -f TRAPWINCH
}

# Update the prompt every 30 seconds or so.
# This can be invoked manually with a "kill -ALRM" to the shell.
TMOUT=$[(${RANDOM}%15)+25]
TRAPALRM () {
    zle && setup_prompt && zle reset-prompt
    TMOUT=$[(${RANDOM}%15)+25]
}

[[ 'dumb' == ${TERM} ]] && {
    unset -f TRAPWINCH TRAPALRM
    unset TMOUT
}


TTY_LINE=$(print -P '%l')
command_title "${ZSH_NAME} (${TTY_LINE})"

ZSH_THEME_GIT_PROMPT_PREFIX="%{%B%F{white}%}[%{%B%F{yellow}%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{%B%F{white}%}]%{%f%k%b%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{%F{green}%}✓"
ZSH_THEME_GIT_PROMPT_DIRTY="%{%F{red}%}✗"
ZSH_THEME_GIT_PROMPT_AHEAD="%{%B%F{yellow}%}↑"

ZSH_THEME_GIT_PROMPT_ADDED="%{%B%F{green}%}✚"
ZSH_THEME_GIT_PROMPT_MODIFIED="%{%B%F{blue}%}✹"
ZSH_THEME_GIT_PROMPT_DELETED="%{%B%F{red}%}✖"
ZSH_THEME_GIT_PROMPT_RENAMED="%{%B%F{magenta}%}➜"
ZSH_THEME_GIT_PROMPT_UNMERGED="%{%B%F{yellow}%}═"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{%B%F{cyan}%}✭"

PROMPT='%{%F{${PD[default_color]}}%B%K{black}%}%~ ${PD[path_load_spacing]}${PD[load]}%E%{%f%k%b%}
%{%B%F{white}%}[%{%F{cyan}%}%D{%H:%M}%{%F{white}%}] %{%F{${PD[default_color]}}%}%#%{%f%k%b%} '
RPROMPT='$(git_prompt_ahead)$(git_prompt_status) $(git_prompt_info)%{%f%k%b%}'
