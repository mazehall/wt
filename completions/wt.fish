# Dynamic project/worktree suggestions share wt's current-project resolver.
function __wt_current_project
    wt __complete current 2>/dev/null
end

function __wt_has_current_project
    set -l project (__wt_current_project)
    test (count $project) -gt 0
end

function __wt_no_current_project
    not __wt_has_current_project
end

function __wt_first_argument
    set -l words (commandline -opc)
    test (count $words) -eq 2
end

function __wt_after_repo_option
    set -l words (commandline -opc)
    set -l word_count (count $words)
    test $word_count -ge 3; and test "$words[$word_count]" = --repo
end

function __wt_source_candidates
    set -l prefix (commandline -ct)
    wt __complete projects "$prefix" sources 2>/dev/null
end

function __wt_hub_candidates
    set -l prefix (commandline -ct)
    wt __complete projects "$prefix" hubs 2>/dev/null
end

function __wt_rm_second_argument
    set -l words (commandline -opc)
    set -l positional (string match -rv -- '^-' $words[3..-1])
    test (count $positional) -eq 1
end

function __wt_rm_first_argument
    set -l words (commandline -opc)
    set -l positional (string match -rv -- '^-' $words[3..-1])
    test (count $positional) -eq 0
end

function __wt_rm_first_candidates
    set -l project (__wt_current_project)
    set -l prefix (commandline -ct)
    if test (count $project) -gt 0
        wt __complete worktrees "$project[1]" "$prefix" 2>/dev/null
    end
    wt __complete projects "$prefix" hubs 2>/dev/null
end

function __wt_rm_second_candidates
    set -l words (commandline -opc)
    set -l positional (string match -rv -- '^-' $words[3..-1])
    set -l repo "$positional[1]"
    wt __complete worktrees "$repo" (commandline -ct) 2>/dev/null
end

complete -c wt -f
complete -c wt -n '__fish_use_subcommand' -a 'init sync new list rm prune'

complete -c wt -n '__wt_first_argument; and __fish_seen_subcommand_from init' -a '(__wt_source_candidates)' -d project
complete -c wt -n '__wt_first_argument; and __fish_seen_subcommand_from sync list prune' -a '(__wt_hub_candidates)' -d project
complete -c wt -n '__wt_first_argument; and __fish_seen_subcommand_from sync' -l all -d 'Fetch every hub'

complete -c wt -n '__wt_first_argument; and __fish_seen_subcommand_from new; and __wt_no_current_project' -a '(__wt_hub_candidates)' -d project
complete -c wt -n '__fish_seen_subcommand_from new' -l repo -d 'Select a project explicitly'
complete -c wt -n '__fish_seen_subcommand_from new' -l branch -r -d 'Branch name'
complete -c wt -n '__fish_seen_subcommand_from new' -l base -r -d 'Base ref'
complete -c wt -n '__wt_after_repo_option; and __fish_seen_subcommand_from new' -a '(__wt_hub_candidates)' -d project

complete -c wt -n '__wt_rm_first_argument; and __fish_seen_subcommand_from rm' -a '(__wt_rm_first_candidates)' -d 'project or worktree'
complete -c wt -n '__fish_seen_subcommand_from rm; and __wt_rm_second_argument' -a '(__wt_rm_second_candidates)' -d worktree
complete -c wt -n '__fish_seen_subcommand_from rm' -s f -l force -d 'Discard uncommitted changes'
