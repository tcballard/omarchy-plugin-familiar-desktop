#!/usr/bin/env bash
# Sourced by setup entry points. Only a new installation adopts this default.
familiar_prepare_bar_placement() {
  local state="${XDG_STATE_HOME:-$HOME/.local/state}/familiar-desktop"
  local config="${XDG_CONFIG_HOME:-$HOME/.config}"
  if [[ ! -e "$config/omarchy/familiar-titlebars/owner.json" ]]; then
    mkdir -p "$state"
    touch "$state/bar-placement-pending"
  fi
}

familiar_apply_bar_placement() {
  local state="${XDG_STATE_HOME:-$HOME/.local/state}/familiar-desktop"
  local config="${XDG_CONFIG_HOME:-$HOME/.config}"
  local id='io.github.tcballard.familiar-desktop'
  [[ -e "$state/bar-placement-pending" ]] || return 0
  # Keep the default on the right even if Agents was moved to another section.
  if jq -e '.bar.layout.right // [] | any(.[]; (if type == "object" then .id else . end) == "omarchy.agents")' "$config/omarchy/shell.json" >/dev/null 2>&1; then
    if timeout --kill-after=2 10 omarchy bar move "$id" --before omarchy.agents; then
      rm -f "$state/bar-placement-pending"
      return 0
    fi
  fi
  if timeout --kill-after=2 10 omarchy bar move "$id" --section right --index 0; then
    rm -f "$state/bar-placement-pending"
  else
    echo 'Familiar is ready; its default bar position could not be applied. Retry setup to apply it.'
  fi
}
