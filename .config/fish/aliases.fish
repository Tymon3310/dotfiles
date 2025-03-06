# -----------------------------------------------------
# ABBREVIATIONS
# -----------------------------------------------------

# General
abbr -a c clear
abbr -a nf fastfetch
abbr -a pf fastfetch
abbr -a ff fastfetch
alias ls='eza -a --icons'
alias ll='eza -al --icons'
alias lt='eza -a --tree --level=1 --icons'
abbr -a sd 'systemctl poweroff'
abbr -a v '$EDITOR'
abbr -a vi '$EDITOR'
abbr -a vim '$EDITOR'
abbr -a icat 'kitten icat'
abbr -a cat bat

# -----------------------------------------------------
# GIT ABBREVIATIONS
# -----------------------------------------------------

abbr -a gs 'git status'
abbr -a ga 'git add'
abbr -a gc 'git commit -m'
abbr -a gp 'git push'
abbr -a gpl 'git fetch && git pull'
abbr -a gst 'git stash'
abbr -a gsp 'git stash; git pull'
abbr -a gcheck 'git checkout'
abbr -a gcred 'git config credential.helper store'
abbr -a gfo 'git fetch origin'
abbr -a guncommit 'git reset --soft HEAD~1'

function gaa
    git add .
    git commit -m "$argv"
    git push
end

# -----------------------------------------------------
# SCRIPT ABBREVIATIONS
# -----------------------------------------------------

abbr -a ascii '~/.config/hypr/scripts/ascii-text.sh'
abbr -a matrix 'unimatrix -a -f -s 95'

# -----------------------------------------------------
# SYSTEM ABBREVIATIONS
# -----------------------------------------------------

# System
abbr -a update-grub 'sudo grub-mkconfig -o /boot/grub/grub.cfg'
abbr -a pacunl 'sh ~/.config/hypr/scripts/unlock-pacman.sh'
abbr -a dg 'sudo downgrade'
abbr -a vsc code-insiders

# Pacman
abbr -a pacupg 'sudo pacman -Syu'
abbr -a pacin 'sudo pacman -S'
abbr -a paclean 'sudo pacman -Sc'
abbr -a pacins 'sudo pacman -U'
abbr -a paclr 'sudo pacman -Scc'
abbr -a pacre 'sudo pacman -R'
abbr -a pacrem 'sudo pacman -Rns'
abbr -a pacrep 'pacman -Si'
abbr -a pacreps 'pacman -Ss'
abbr -a pacloc 'pacman -Qi'
abbr -a paclocs 'pacman -Qs'
abbr -a pacinsd 'sudo pacman -S --asdeps'
abbr -a pacmir 'sudo pacman -Syy'
abbr -a paclsorphans 'sudo pacman -Qdt'
abbr -a pacfileupg 'sudo pacman -Fy'
abbr -a pacfiles 'pacman -F'
abbr -a pacls 'pacman -Ql'
abbr -a pacown 'pacman -Qo'
abbr -a pacupd 'sudo pacman -Sy'

function pacrmorphans
    sudo pacman -Rs (pacman -Qtdq)
end

# Yay
if command -v yay &>/dev/null
    abbr -a yaconf 'yay -Pg'
    abbr -a yaclean 'yay -Sc'
    abbr -a yaclr 'yay -Scc'
    abbr -a yaupg 'yay -Syu'
    abbr -a yasu 'yay -Syu --noconfirm'
    abbr -a yain 'yay -S'
    abbr -a yains 'yay -U'
    abbr -a yare 'yay -R'
    abbr -a yarem 'yay -Rns'
    abbr -a yarep 'yay -Si'
    abbr -a yareps 'yay -Ss'
    abbr -a yaloc 'yay -Qi'
    abbr -a yalocs 'yay -Qs'
    abbr -a yalst 'yay -Qe'
    abbr -a yaorph 'yay -Qtd'
    abbr -a yainsd 'yay -S --asdeps'
    abbr -a yamir 'yay -Syy'
    abbr -a yaupd 'yay -Sy'
end

# Flatpak
if command -v flatpak &>/dev/null
    abbr -a fpk flatpak
    abbr -a fpkin 'flatpak install'
    abbr -a fpkup 'flatpak update'
    abbr -a fpkupg 'flatpak update -y'
    abbr -a fpkls 'flatpak list'
    abbr -a fpkre 'flatpak uninstall'
    abbr -a fpkrem 'flatpak uninstall --delete-data'
    abbr -a fpkinfo 'flatpak info'
    abbr -a fpkrun 'flatpak run'
    abbr -a fpkrps 'flatpak search'
    abbr -a fpkrmu 'flatpak uninstall --unused -y'
    abbr -a fpkrpo 'flatpak remote-list'
    abbr -a fpkhis 'flatpak history'
    abbr -a fpkover 'flatpak override'
    abbr -a fpkrpa 'flatpak remote-add'
    abbr -a fpkrpr 'flatpak remote-remove'
    abbr -a fpkreps 'flatpak search'
    abbr -a fpkclean 'flatpak uninstall --unused -y'
end
