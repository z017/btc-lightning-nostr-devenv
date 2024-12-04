#!/bin/sh
set -e

# containers on linux share file permissions with hosts.
# assigning the same uid/gid from the host user
# ensures that the files can be read/write from both sides
if ! id dev > /dev/null 2>&1; then
  USERID=${USERID:-1000}
  GROUPID=${GROUPID:-1000}

  echo "adding user dev ($USERID:$GROUPID)"
  groupadd -f -g $GROUPID dev
  useradd -M -u $USERID -g $GROUPID dev
  chown -R $USERID:$GROUPID /home/dev
fi

if [ $(echo "$1" | cut -c1) = "-" ]; then
  echo "$0: assuming arguments for nostr-rs-relay"

  set -- nostr-rs-relay "$@"
fi

if [ "$1" = "nostr-rs-relay"  ] || [ "$1" = "nak" ]; then
  echo "Running as dev user: $@"
  exec gosu dev "$@"
fi

echo "$@"
exec "$@"
