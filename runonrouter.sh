#!/bin/sh
set -e;

ADDR="$1";
SRC="$2";
FILENAME=$(basename "$SRC");
ARGS="${*:3}";

echo "Usage: $(basename $0) <user>@<router.ip> <filename> [ARG1=VAL1 ARG2=VAL2 ARGn=VALn]";
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

ARGS="FILENAME=\"$FILENAME\" $ARGS"

echo "Script:  $SRC";
echo "Args:    $ARGS";
echo "---";
echo "Copying script to router..";
scp "$SRC" "$ADDR:/tmp/$FILENAME";

echo "Running script on router..";
echo "run: $ARGS /tmp/$FILENAME";
ssh "$ADDR" "$ARGS /tmp/$FILENAME";
