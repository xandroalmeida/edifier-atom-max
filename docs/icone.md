# Ícone do Atom Control

Criado em 18/11/2026 usando o gerador de imagens integrado (`image_gen`), com transparência solicitada. A imagem original foi copiada para o projeto sem alteração visual.

- Original: `Resources/AtomControl-icon.png` (1254 × 1254, canal alfa).
- Ícone do app: `Resources/AtomControl.icns`.
- Conversão: `zsh scripts/build-icon.sh`, com dez representações de 16 a 1024 pixels. Usa `sips` e `iconutil`; se o encoder de `iconutil` estiver indisponível, um utilitário Swift empacota os mesmos PNGs em ICNS e valida a leitura de todas as representações com ImageIO. Nenhuma dependência é acrescentada ao app.
- Uso: `CFBundleIconFile` no bundle. Os indicadores de modo da barra de menus continuam usando SF Symbols.

## Prompt final

Use case: logo-brand. Asset type: production macOS application icon for Atom Control, a tiny native menu-bar app controlling noise cancellation on Edifier over-ear headphones. Create a single polished 1024x1024 app icon, not a mockup. A bold, easily recognized front-view pair of sculpted over-ear headphones in satin silver and graphite, enclosing a small clean cyan soundwave that tapers to silence, suggesting active noise cancellation. Native macOS visual language, restrained soft dimensionality, precise rounded geometry, subtle glass and metal highlights, excellent legibility at 32 pixels. Dark charcoal rounded-square macOS-style tile, gentle tonal depth, generous consistent inset around the headphones, tile centered occupying about 88% of the canvas. Transparent pixels outside the rounded-square tile, actual alpha transparency. Straight-on orthographic composition, balanced and centered. No letters, no text, no brand logos, no watermark, no extra objects, no scene, no presentation frame, no dramatic external shadow. The icon should feel calm, premium and at home beside built-in Mac utilities.
