#!/bin/bash

_nmgr_completions() {
	local cur cword actions targets jobs words
	_init_completion || return

	if [[ $cur == -* ]]; then
		options="$(nmgr --list-options)"
		mapfile -t COMPREPLY < <(compgen -W "$options" -- "$cur")
		return
	fi

	local arg_count=0
	for word in "${words[@]:1:$((cword - 1))}"; do
		if [[ $word != -* ]]; then
			((arg_count++))
		fi
	done

	case $arg_count in
		0)
			actions="$(nmgr --list-actions)"
			mapfile -t COMPREPLY < <(compgen -W "$actions" -- "$cur")
			;;
		1)
			targets="$(nmgr --list-targets | sort)"
			jobs="$(nmgr list all | sort)"
			mapfile -t COMPREPLY < <(compgen -W "$targets $jobs" -- "$cur")
			;;
	esac
}

complete -o nosort -F _nmgr_completions nmgr
