#!/bin/sh
set -e;

ADDR="$1";
SRC="$2";
FILENAME=$(basename "$SRC");
ARGS="${*:3}";

echo "Usage: $(basename $0) <user>@<router.ip> <script.filename> [arg1 [arg2]]";
echo "---";
if [ $# -lt 2 ]; then
  echo "At least two arguments mandatory.";
  exit 1;
fi;
echo "Address: $ADDR";

if [ "$SRC" = "" ] || [ ! -f "$SRC" ]; then
  echo "File \"$SRC\" not found.";
  exit 1;
fi;

echo "Script:  $SRC";
echo "Args:    $ARGS";

echo "Copying script to router..";
scp "$SRC" "$ADDR:/tmp/$FILENAME";

echo "Running script on router..";
ssh "$ADDR" "sh /tmp/$FILENAME $ARGS";
