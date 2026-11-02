_wt_complete() {
    local current command_name candidates candidate
    current="${COMP_WORDS[COMP_CWORD]}"
    command_name="${COMP_WORDS[1]}"
    COMPREPLY=()

    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=( $(compgen -W 'init sync new list rm completion prune' -- "$current") )
        return
    fi

    case "$command_name" in
        completion)
            COMPREPLY=( $(compgen -W 'fish bash zsh' -- "$current") ) ;;
        init)
            candidates="$(wt __complete projects "$current" sources 2>/dev/null)"
            COMPREPLY=( $(compgen -W "$candidates" -- "$current") ) ;;
        sync|list|prune)
            candidates="$(wt __complete projects "$current" hubs 2>/dev/null)"
            [ "$command_name" != sync ] || candidates="all $candidates"
            COMPREPLY=( $(compgen -W "$candidates" -- "$current") ) ;;
        new|rm)
            case "$current" in
                -* ) COMPREPLY=( $(compgen -W '--repo --branch --base --force -f' -- "$current") ) ;;
                * )
                    candidates="$(wt __complete projects "$current" hubs 2>/dev/null)"
                    COMPREPLY=( $(compgen -W "$candidates" -- "$current") ) ;;
            esac ;;
    esac
}
complete -F _wt_complete wt
