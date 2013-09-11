#!/bin/sh
set -e;

ADDR="$1";
SRC="$2";
FILENAME=$(basename "$SRC");
echo $FILENAME
ARGS="${*:3}";

scp "$SRC" "$ADDR:/tmp/$FILENAME";
ssh "$ADDR" "chmod +x /tmp/$FILENAME && /tmp/$FILENAME $ARGS";
