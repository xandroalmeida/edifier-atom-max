#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
mkdir -p .build/ModuleCache
xcrun swiftc -module-cache-path "$PWD/.build/ModuleCache" Sources/Localization.swift Sources/EdifierProtocol.swift Sources/AppState.swift Tests/main.swift -o .build/protocol-tests
.build/protocol-tests

# Every L("…") key used in the code must exist in all three languages, and vice versa.
used=$(grep -ohE 'L\("[^"]+"' Sources/*.swift | sed -E 's/^L\("//; s/"$//' | sort -u)
for lang in en pt-BR es; do
    file="Resources/$lang.lproj/Localizable.strings"
    plutil -lint -s "$file"
    plutil -lint -s "Resources/$lang.lproj/InfoPlist.strings"
    defined=$(sed -nE 's/^"([^"]+)" = ".*";$/\1/p' "$file" | sort -u)
    if [[ "$used" != "$defined" ]]; then
        print -u2 "Traduções divergentes em $file:"
        diff <(print -r -- "$used") <(print -r -- "$defined") >&2 || true
        exit 1
    fi
done
print "Traduções completas: en, pt-BR, es."
