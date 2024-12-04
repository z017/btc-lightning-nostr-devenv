#!/usr/bin/env bash
#
# Nostr utilities.
#
# This should only be sourced, not executed directly
[[ -n "$BASH_VERSION" ]] || fatal "This file must be sourced from bash."
[[ "$(caller 2>/dev/null | awk '{print $1}')" != "0" ]] || fatal "This file must be sourced, not executed."

# -----------------------------------------------------------------------------

nak() {
  docker_compose exec --user dev nostr_relay nak "$@"
}

public_key_from_private_key() {
  local private_key="$1"
  nak key public "$private_key"
}