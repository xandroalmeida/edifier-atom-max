# Instructions for AI agents

Goal: compile, test and install **Atom Control** (a macOS menu-bar app for the EDIFIER Atom Max headphones) on the user's Mac. Reply to the user in their own language.

## Steps

1. **Check the Mac.** `sw_vers -productVersion` must be 13 or later. Apple silicon and Intel are both fine.
2. **Check the Swift compiler.** Run `xcrun --find swiftc`. If it fails, run `xcode-select --install`, tell the user to click **Install** in the dialog that appears, wait for them to confirm it finished, then check again. Do not install Homebrew, Xcode from the App Store or any other dependency.
3. **Install.** From the repository root run:
   ```sh
   zsh scripts/install.sh
   ```
   It runs the tests, builds `dist/Atom Control.app`, quits any running copy, installs into `/Applications` (or `~/Applications` if `/Applications` is not writable) and opens the app. If an older copy belongs to root (installed via `.pkg`), macOS shows a password dialog: tell the user to type their Mac password there. Never run `sudo` yourself.
4. **Tell the user what to do next:**
   - look for the headphones icon in the menu bar (top right of the screen);
   - click **Allow** when macOS asks for Bluetooth access;
   - turn on the Atom Max; if it is not found, close the EDIFIER ConneX app on the phone/Mac and click **Connect to headphones**;
   - optional: enable **Launch at login** in the app's menu.

## If something fails

- Test or build errors: show the user the last lines of output. Do not edit source code, disable tests or change signing settings to make it pass unless the user asks.
- `xcrun: error: invalid active developer path`: Command Line Tools are missing → step 2.
- Uninstall: `zsh scripts/install.sh --uninstall`.

## Rules

- No network access is needed after cloning; the project has no external dependencies.
- Do not run `scripts/package.sh` unless the user asks for a `.pkg` installer.
- Technical details: [docs/documentacao-tecnica.md](docs/documentacao-tecnica.md).
