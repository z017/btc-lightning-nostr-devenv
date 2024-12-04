FROM scsibug/nostr-rs-relay:0.9.0 AS build

FROM debian:stable-slim as run

COPY --from=build /usr/src/app/nostr-rs-relay /usr/local/bin/nostr-rs-relay
RUN chmod a+x /usr/local/bin/nostr-rs-relay

RUN apt-get update -y \
  && apt-get install -y curl gosu \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install nak nostr tool
RUN BIN_URL=$(curl -s https://api.github.com/repos/fiatjaf/nak/releases/latest | grep -oP '"browser_download_url":\s*"\K[^"]+' | grep linux-amd64) \
  && TMP_DIR=$(mktemp -d) \
  && cd $TMP_DIR \
  && curl -SLO $BIN_URL \
  && install ${BIN_URL##*/} /usr/local/bin/nak \
  && cd - \
  && rm -rf $TMP_DIR

COPY entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh

COPY config.toml /home/dev/.nostr_relay/config.toml
RUN mkdir -p /home/dev/.nostr_relay/db

ENV RUST_LOG=info,nostr_rs_relay=info

WORKDIR "/home/dev"

ENTRYPOINT ["/entrypoint.sh"]

CMD ["nostr-rs-relay", "--config", "/home/dev/.nostr_relay/config.toml"]
