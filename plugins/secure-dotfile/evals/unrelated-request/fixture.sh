#!/bin/bash
# Writes a ~/.zshrc without secrets into the run's temporary home.
set -eu
printf 'export PATH="$HOME/bin:$PATH"\nalias gs="git status"\n' > "$HOME/.zshrc"
