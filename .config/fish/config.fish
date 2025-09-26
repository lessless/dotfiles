if status is-interactive
    # Commands to run in interactive sessions can go herei
    fzf --fish | source
    alias dfiles='/usr/local/bin/git --git-dir=$HOME/.myconf/ --work-tree=$HOME'
    source (/usr/local/bin/starship init fish --print-full-init | psub)
end
/usr/local/bin/mise activate fish | source
