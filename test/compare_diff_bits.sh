#!/bin/bash

if [ $# -ne 1 ]; then
  echo "usage: compare_diff_bits.sh <apk>"
  exit 1
fi

APK=$1

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

DIFF_HASH="$(hg log -l1 -T{node})"
DIFF_OUT="$(mktemp).diff.apk"

hg up -q -r 'ancestor(master, .)'

if [ $? -ne 0 ]; then
  echo "Failed to hg up to base commit"
  exit 1
fi

BASE_HASH="$(hg log -l1 -T{node})"
BASE_OUT="$(mktemp).base.apk"

echo "Will compare base $BASE_HASH to diff $DIFF_HASH"

echo "Redexing with base $BASE_HASH"

buck build native/redex:redex-all 2> /dev/null > /dev/null

if [ $? -ne 0 ]; then
  echo "Failed to build base redex"
  exit 1
fi

native/redex/facebook/fb-redex  --redex-binary buck-out/gen/native/redex/redex-all  -c native/redex/facebook/config/fb4a.config --o $BASE_OUT $APK 2> /dev/null > /dev/null

if [ $? -ne 0 ]; then
  echo "Failed to redex apk with base"
  exit 1
fi

hg up -q -r $DIFF_HASH

if [ $? -ne 0 ]; then
  echo "Failed to hg up to diff commit"
  exit 1
fi

echo "Redexing with diff $DIFF_HASH"

buck build native/redex:redex-all 2> /dev/null > /dev/null

if [ $? -ne 0 ]; then
  echo "Failed to build diff redex"
  exit 1
fi

native/redex/facebook/fb-redex  --redex-binary buck-out/gen/native/redex/redex-all  -c native/redex/facebook/config/fb4a.config --o $DIFF_OUT $APK 2> /dev/null > /dev/null

if [ $? -ne 0 ]; then
  echo "Failed to redex apk with diff"
  exit 1
fi

echo "Comparing bits of base apk $BASE_OUT to diff apk $DIFF_OUT"

ESC="\x1b["
RESET="39;49;00m"
RED="31;01m"
GREEN="32;01m"

$SCRIPT_PATH/compare_bits.sh $BASE_OUT $DIFF_OUT 2> /dev/null > /dev/null

if [ $? -ne 0 ]; then
    echo -e $ESC$RED"Diff changes the output APK relative to base."$ESC$RESET
else
    echo -e $ESC$GREEN"Diff does not change the output APK relative to base."$ESC$RESET
fi
