#!/bin/zsh
# Tests, builds and installs Atom Control into Applications, then opens it.
# Usage: zsh scripts/install.sh            (installs to /Applications, or ~/Applications if not writable)
#        zsh scripts/install.sh --uninstall
set -euo pipefail
cd "${0:A:h:h}"
NAME="Atom Control.app"
BUNDLE_ID="br.com.local.AtomControl"

quit_running() {
    if pgrep -x AtomControl >/dev/null; then
        osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
        for _ in {1..20}; do pgrep -x AtomControl >/dev/null || break; sleep 0.25; done
        pkill -x AtomControl 2>/dev/null || true
    fi
}

if [[ "${1:-}" == "--uninstall" ]]; then
    quit_running
    for dir in /Applications "$HOME/Applications"; do
        [[ -d "$dir/$NAME" ]] || continue
        if ! rm -rf "$dir/$NAME" 2>/dev/null; then
            DST="$dir/$NAME" osascript -e 'do shell script "rm -rf " & quoted form of (system attribute "DST") with administrator privileges'
        fi
        print "Removido: $dir/$NAME"
    done
    pkgutil --pkgs | grep -qx "$BUNDLE_ID.installer" && sudo -n pkgutil --forget "$BUNDLE_ID.installer" >/dev/null 2>&1 || true
    defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
    print "Atom Control desinstalado."
    exit 0
fi

major=$(sw_vers -productVersion | cut -d. -f1)
if (( major < 13 )); then
    print -u2 "Erro: requer macOS 13 ou posterior (este Mac: $(sw_vers -productVersion))."
    exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
    print -u2 "Erro: compilador Swift não encontrado. Rode 'xcode-select --install', conclua a instalação e execute este script de novo."
    exit 1
fi

print "==> 1/4 Testes"
zsh scripts/test.sh
print "==> 2/4 Compilação"
zsh scripts/build.sh

print "==> 3/4 Instalação"
TARGET=/Applications
if [[ ! -w "$TARGET" ]]; then
    TARGET="$HOME/Applications"
    mkdir -p "$TARGET"
fi
quit_running
if ! { rm -rf "$TARGET/$NAME" && ditto "dist/$NAME" "$TARGET/$NAME"; } 2>/dev/null; then
    # A copy installed by the .pkg belongs to root: ask for the admin password in a macOS dialog.
    print "Uma versão anterior pertence ao administrador; o macOS vai pedir sua senha."
    SRC="$PWD/dist/$NAME" DST="$TARGET/$NAME" USR="$(id -un)" osascript -e '
        set src to system attribute "SRC"
        set dst to system attribute "DST"
        set usr to system attribute "USR"
        do shell script "rm -rf " & quoted form of dst & " && ditto " & quoted form of src & " " & quoted form of dst & " && chown -R " & quoted form of usr & " " & quoted form of dst with administrator privileges'
fi
codesign --verify --strict "$TARGET/$NAME"
print "Instalado em: $TARGET/$NAME"

print "==> 4/4 Abrindo"
open "$TARGET/$NAME"
print "Pronto. Procure o ícone de fone na barra de menus e permita o acesso ao Bluetooth se o macOS pedir."
