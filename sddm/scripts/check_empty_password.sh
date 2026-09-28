#!/bin/sh
# Helper for SDDM PAM stack:
# Returns 0 (success) if the authtok on stdin is empty (e.g. face authentication probe),
# or 1 (failure) if a non-empty password was provided.
IFS= read -r pass || true
if [ -z "$pass" ]; then
    exit 0
else
    exit 1
fi
