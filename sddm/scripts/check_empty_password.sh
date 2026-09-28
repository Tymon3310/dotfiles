#!/bin/sh
# Portable empty-authtok check for pam_exec expose_authtok:
# Returns 0 (success) if the authtok on stdin is empty (e.g. face authentication probe),
# or 1 (failure) if a non-empty password was provided.
first_byte=$(head -c 1 2>/dev/null | tr -d '\0')
if [ -z "$first_byte" ]; then
    exit 0
else
    exit 1
fi
