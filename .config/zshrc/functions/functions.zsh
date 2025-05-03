#!/usr/bin/env zsh

function gaa() {
  local title
  if [[ -z "$1" ]]; then
    title=$(gum input --placeholder "Commit message...")
  else
    title="$1"
  fi
  git add . && git commit -m "$title" && git push
}

_installlibs() {
    /usr/bin/cat ~/.personal/commonlibs.txt | \
  gum choose --cursor.foreground '#09F' --selected.foreground '#0FF' --no-limit --header 'Which libs do You need?' | \
  xargs -d '\n' -r -- \
  sh -c 'gum spin --spinner dot --title "Installing selected packages..." --spinner.foreground "#09F" -- pip install "$@"' sh
}

_makevenv() {
    if [ -d ".venv" ]; then
        echo 'Venv already exists, activating'
        source .venv/bin/activate
        return 0
    fi

    gum spin --title "Creating venv..." --spinner.foreground "#09F" -- python -m venv .venv
    source .venv/bin/activate
    gum spin --title "Upgrading pip..." --spinner.foreground "#09F" -- pip install --upgrade pip

    echo 'Venv created and activated'

    gum confirm "Do You want to install common libraries?" --selected.background '#09F' && _installlibs || echo 'Not installing libraries'

    return 0
}

mkcd() {
    mkdir $1
    cd $1
}

cd() {
  if [[ -n "$1" && -z "${1//.}" && ${#1} -ge 2 ]]; then
    if [[ "$1" == ".." ]]; then
        builtin cd "$@"
        return $?
    fi

    local target=".."
    for (( i=3; i <= ${#1}; i++ )); do
      target="$target/.."
    done
    builtin cd "$target" "$@[2,-1]"
    return $?
  else
    builtin cd "$@"
    return $?
  fi
}
