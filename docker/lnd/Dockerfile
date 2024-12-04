FROM polarlightning/lnd:0.18.3-beta

COPY entrypoint.sh /entrypoint.sh
RUN chmod a+x /entrypoint.sh

COPY lnd.conf /home/lnd/.lnd/lnd.conf
