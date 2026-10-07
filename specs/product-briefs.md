# Product briefs and prototype acceptance

The complete source Markdown files remain in the user's `DEEPSEEK` folder; this index records the accepted functional boundaries for the public prototype repository.

| App | Product core and local acceptance | Prototype-only gap to resolve before distribution |
|---|---|---|
| Ateliê de Colorir | Select a demo vector drawing, fill regions, undo, export a PNG, reopen saved exports offline. | Original brief calls for 24 licensed drawings and 12 colors; current demonstration uses a single authored geometric flower and six colors. |
| Crime Idle | Tap, buy six fictional businesses, observe foreground/offline accrual capped at eight hours, claim eligible missions once. | Original brief also expects three districts and 12 missions; prototype data is a smaller visible slice. |
| Detetive na Testa | Play a timed round with a local deck, no duplicate cards in a round, tilt plus large tap controls and results. | Original brief calls for 200 reviewed cards across four categories; bundled demo deck is smaller and requires editorial review. Core Motion behavior needs a physical-device check. |
| Manager de Futebol Brasileiro | Seeded 8-team double round-robin, persistent round/seed, results-derived table and explicit tie-break ordering. | Original brief asks for 16 athletes per club, roster/tactics and transfer market; current roster is a UI demonstration, not a complete management simulation. |
| Meu QR Pix Offline | Generate a static BR Code locally, calculate CRC16, render QR, copy identical payload and retain generated drafts marked “não pago”. | Synthetic receiver is only for UI/testing. Validate against official vectors and scan with multiple real banking apps before distribution. |
| Leitor PDF de Bolso | Open local PDFs through Files, bundle a generated sample PDF, render/search text, mark a page and restore reading position. | OCR is excluded. Verify secure document access, password handling and import edge cases on device. |
| Brasília Política — Contexto | Browse, search and favorite an offline editorial-style package; show its archive/demo date. | Current six articles are explicitly fictitious. Original brief requires 20+ original, signed, dated and reviewed pieces with verified sources. |
| Diário do Sono | Start/end a manual session, rate it, add a note, recover in-progress sessions, review and clear local records. | Microphone is not included. No diagnosis or clinical measurements; longer-term editing/retention policy needs product review. |
| Hall das Lendas | Browse six legend cards in a 3D showcase, collection grid with rarity filter, free daily loaner card (24h), one-time purchases per card or the full set through StoreKit 2 with restore; simulated store in tests and captures. | Real people's names and likenesses require licensing before any sale. No paid random packs by design (consumer-protection and App Review rules for loot boxes). Products must be created in App Store Connect; prices shown in tests are placeholders. |
| Quebra-Cabeças de Bolso | Play a solvable 3×3/4×4/6×6 sliding puzzle, persist every move and timer, record best time. | Current number mosaic is a functional interaction prototype; the original brief asks for 30 licensed images and image-piece puzzles. |

## Release readiness distinction

The CI gate in this repository proves compilation, tests and deterministic simulator capture for these prototypes. It does not certify the original content quantities, rights, physical sensor behavior, Pix bank compatibility, App Review compliance or App Store readiness. Keep every demo label in place until the corresponding replacement content and checks are approved.
