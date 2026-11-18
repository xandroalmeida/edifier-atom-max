#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/ModuleCache
xcrun swiftc -module-cache-path "$PWD/.build/ModuleCache" Sources/EdifierProtocol.swift Sources/AppState.swift Tests/main.swift -o .build/protocol-tests
.build/protocol-tests
