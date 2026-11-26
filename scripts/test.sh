#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache
swiftc -module-cache-path .build/module-cache iAnguis/Core/*.swift iAnguis/UI/GameModel.swift Tests/main.swift -o .build/engine-tests
.build/engine-tests
