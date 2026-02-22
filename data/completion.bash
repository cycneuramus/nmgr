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
	local action=""
	for word in "${words[@]:1:$((cword - 1))}"; do
		if [[ $word != -* ]]; then
			if [[ $arg_count -eq 0 ]]; then
				action="$word"
			fi
			((arg_count++))
		fi
	done

	case $arg_count in
		0)
			actions="$(nmgr --list-actions)"
			mapfile -t COMPREPLY < <(compgen -W "$actions" -- "$cur")
			;;
		*)
			targets="$(nmgr --list-targets)"
			if [[ "$action" == @(down|logs|exec|shell) ]]; then
				jobs="$(nmgr --list-running)"
			else
				jobs="$(nmgr list all)"
			fi
			mapfile -t COMPREPLY < <(compgen -W "$targets $jobs" -- "$cur")
			;;
	esac
}

complete -o nosort -F _nmgr_completions nmgr
