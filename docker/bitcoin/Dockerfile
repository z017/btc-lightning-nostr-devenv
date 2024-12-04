FROM polarlightning/bitcoind:27.0

# install geth-hdwallet to derive private keys from mnemonics
RUN BIN_URL=$(curl -s https://api.github.com/repos/miguelmota/go-ethereum-hdwallet/releases/latest | grep -oP '"browser_download_url":\s*"\K[^"]+' | grep linux_amd64) \
  && TMP_DIR=$(mktemp -d) \
  && cd $TMP_DIR \
  && curl -SLO $BIN_URL \
  && tar -xzf ${BIN_URL##*/} \
  && install geth-hdwallet /usr/local/bin/hdwallet \
  && cd - \
  && rm -rf $TMP_DIR

COPY entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh

COPY bitcoin.conf /home/bitcoin/.bitcoin/bitcoin.conf
