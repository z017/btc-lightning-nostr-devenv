#!/usr/bin/env bash
#
# Bitcoin utilities.
#
# This should only be sourced, not executed directly
[[ -n "$BASH_VERSION" ]] || fatal "This file must be sourced from bash."
[[ "$(caller 2>/dev/null | awk '{print $1}')" != "0" ]] || fatal "This file must be sourced, not executed."

# -----------------------------------------------------------------------------

bitcoin_cli() {
  docker_compose exec --user bitcoin bitcoin bitcoin-cli -regtest -rpcport=18443 -rpcuser=bitcoin -rpcpassword=bitcoin "$@"
}

hdwallet() {
  docker_compose exec --user bitcoin bitcoin hdwallet "$@"
}

private_key_from_mnemonic_path() {
  local mnemonic="${@:1:$#-1}"
  local path="${$#-1}"
  hdwallet -mnemonic "$mnemonic" -path "$path" | grep "private key:" | awk '{print $3}'
}

bitcoin_load_wallet() {
  local wallet_name="$1"

  # if wallet already loaded, return
  bitcoin_cli -rpcwallet=$wallet_name getwalletinfo &>/dev/null && return

  # load wallet and create it if not exists
  info "load $wallet_name wallet"
  bitcoin_cli createwallet $wallet_name &>/dev/null || bitcoin_cli loadwallet $wallet_name
}

bitcoin_init() {
  docker_wait_for_healthy_service bitcoin

  bitcoin_load_wallet dev

  local blockcount=$(bitcoin_cli getblockcount 2>/dev/null)
  if [[ $blockcount -le 0 ]]; then
    info "mine first 150 blocks with dev wallet"
    bitcoin_cli -rpcwallet=dev -generate 150 > /dev/null
  fi
}

bitcoin_generate_txs_for_fee_rate_estimation() {
  if [[ $(bitcoin_cli estimatesmartfee 6 | jq ".errors | length") -gt 0 ]]; then
    info generate txs for fee rate estimation
    while [[ $(bitcoin_cli estimatesmartfee 6 | jq ".errors | length") -gt 0 ]]; do
      # generate randomly between 20 and 30 transactions with a fee rate between 1 and 25
      local i=0
      local range=$(($RANDOM % 11 + 20))
      while [[ $i -lt $range ]]; do
        local address=$(bitcoin_cli -rpcwallet=dev getnewaddress)
        bitcoin_cli -named -rpcwallet=dev sendtoaddress address=$address amount=0.01 fee_rate=$(( $RANDOM % 25 + 1 ))
        ((++i))
      done
      # generate block
      info generate block
      bitcoin_cli -rpcwallet=dev -generate 1 > /dev/null
    done
  fi
  local fee_rate_estimation=$(bitcoin_cli estimatesmartfee 6 | jq ".feerate")
  info "approximate fee per kb needed for a transaction to begin confirmation within 6 blocks: $fee_rate_estimation"
}