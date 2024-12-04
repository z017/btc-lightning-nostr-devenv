#!/usr/bin/env bash
#
# Lnd utilities.
#
# This should only be sourced, not executed directly
[[ -n "$BASH_VERSION" ]] || fatal "This file must be sourced from bash."
[[ "$(caller 2>/dev/null | awk '{print $1}')" != "0" ]] || fatal "This file must be sourced, not executed."

# -----------------------------------------------------------------------------

lncli() {
  local lnd_service_name=$1
  shift # shift first argument so we can use $@
  docker_compose exec --user lnd $lnd_service_name lncli --network=regtest "$@"
}

lightning_init() {
  lightning_sync
  lightning_fund
  lightning_open_channels
}

lightning_sync() {
  lnd_wait_for_sync dev_lnd
  lnd_wait_for_sync alice_lnd
  lnd_wait_for_sync bob_lnd
}

lnd_wait_for_sync() {
  local lnd_service_name=$1
  while true; do
    if [[ "$(lncli $lnd_service_name getinfo 2>&1 | jq -r '.synced_to_chain' 2> /dev/null)" == "true" ]]; then
      break
    fi
    info "waiting for $lnd_service_name to sync..."
    sleep 1
  done
}

lightning_fund() {
  local fund_confirms=3

  for i in 0 1 2; do
    lnd_fund_node dev_lnd
    lnd_fund_node alice_lnd
    lnd_fund_node bob_lnd
  done

  info "mining $fund_confirms blocks"
  bitcoin_cli -generate $fund_confirms > /dev/null

  lightning_sync
}

lnd_fund_node() {
  local lnd_service_name=$1
  local address=$(lncli $lnd_service_name newaddress p2wkh | jq -r .address)
  info "funding node$(log_key node $lnd_service_name)$(log_key address $address)"
  bitcoin_cli -named sendtoaddress address=$address amount=30 fee_rate=100 > /dev/null
}

lightning_open_channels() {
  lnd_open_channel dev_lnd alice_lnd $(lnd_node_pubkey alice_lnd)
  lnd_open_channel alice_lnd bob_lnd $(lnd_node_pubkey bob_lnd)
  lnd_open_channel bob_lnd dev_lnd $(lnd_node_pubkey dev_lnd)

  lightning_sync
}

lnd_node_pubkey() {
  local lnd_service_name=$1
  lncli $lnd_service_name getinfo | jq -r '.identity_pubkey'
}

lnd_open_channel() {
  local from_lnd_service_name=$1
  local to_service_name=$2
  local to_service_pubkey=$3

  local channel_confirms=6
  local channel_size=24000000 # 0.024 btc
  local balance_size=12000000 # 0.12 btc

  lncli $from_lnd_service_name connect $to_service_pubkey@$to_service_name > /dev/null
  info "open channel from $from_lnd_service_name to $to_service_name"
  lncli $from_lnd_service_name openchannel $to_service_pubkey $channel_size $balance_size > /dev/null

  info "mining $channel_confirms blocks"
  bitcoin_cli -generate $channel_confirms > /dev/null

  lnd_wait_for_channel $from_lnd_service_name
}

lnd_wait_for_channel() {
  local lnd_service_name=$1
  while true; do
    local pending=$(lncli $lnd_service_name pendingchannels | jq -r '.pending_open_channels | length')
    if [[ "$pending" == "0" ]]; then
      break
    fi
    info "$lnd_service_name pending channels: $pending"
    sleep 1
  done
}
