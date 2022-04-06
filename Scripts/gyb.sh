#!/bin/sh

#  gyb.sh
#  LuCI
#
#  Created by CGH on 2022/4/6.
#

DIR=$(dirname "$0")
GENERATED=$DIR/Generated
ROOT=$(dirname "$DIR")
GYB_PY=$DIR/gyb.py
if [[ ! -f $GYB_PY ]]; then
    echo "gyb.py not exists, download from web"
    curl -fsSL -o $GYB_PY https://github.com/apple/swift/raw/main/utils/gyb.py
    chmod +x $GYB_PY
fi

mkdir -p $GENERATED

export $(cat $ROOT/secrets.env)
$GYB_PY -o $GENERATED/Secrets.swift $DIR/secrets.gyb
