#!/usr/bin/env zsh
# Commit with gum prompt if no message provided
function gaa() {
  local title
  if [[ -z "$1" ]]; then
    title=$(gum input --placeholder "Commit message...")
  else
    title="$1"
  fi
  git add . && git commit -m "$title" && git push
}
