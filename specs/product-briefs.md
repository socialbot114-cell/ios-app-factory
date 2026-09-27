# Product briefs and prototype acceptance

The complete source Markdown files remain in the user's `DEEPSEEK` folder; this index records the accepted functional boundaries for the public prototype repository.

| App | Product core and local acceptance | Prototype-only gap to resolve before distribution |
|---|---|---|
| Ateliê de Colorir | Resume a locally saved drawing, fill regions, undo, export a PNG, reopen saved exports offline. | Original brief calls for a gallery of 24 licensed drawings and 12 colors; current demonstration uses one authored geometric flower and six colors. |
| Crime Idle | Tap, buy six fictional businesses in district-gated progression, gain city income multipliers from opening 3 districts, buy x1/x10 atomically, earn capped offline income and claim 12 data-driven missions once. | Businesses and story remain a small demo; active contracts, progress/settings screen and broader content from the product brief are not implemented. |
| Detetive na Testa | Play a 60-second round with a 41-card local deck across four selectable categories, no repeats within a round, tilt plus large tap controls and results. | Original brief calls for 200 reviewed cards; current categorized deck is a demonstrative sample. Core Motion behavior needs a physical-device check. |
| Manager de Futebol Brasileiro | Offline career with selectable fictional club, 16 generated athletes per club, 3 formations, 6 tactical styles with trade-offs, weekly training focus/intensity, condition and player development, deterministic round simulation, event commentary and shot/possession reports, local free-agent market, persistent career and results-derived standings/champions. | Match engine is a lightweight score/event model; no negotiation with AI clubs, staff/injuries, live match control or licensed real-world database. |
| Meu QR Pix Offline | Generate a static BR Code locally, calculate CRC16, render QR, copy identical payload and retain generated drafts marked “não pago”. | Synthetic receiver is only for UI/testing. Validate against official vectors and scan with multiple real banking apps before distribution. |
| Leitor PDF de Bolso | Open local PDFs through Files, bundle a generated sample PDF, render/search text with previous/next result navigation, mark a page and restore reading position. | OCR is excluded. Verify secure document access, password handling and import edge cases on device. |
| Brasília Política — Contexto | Browse, search and favorite an offline editorial-style package; show its archive/demo date. | Current six articles are explicitly fictitious. Original brief requires 20+ original, signed, dated and reviewed pieces with verified sources. |
| Diário do Sono | Start/end a manual session, rate it, add a note, recover in-progress sessions, review and clear local records. | Microphone is not included. No diagnosis or clinical measurements; longer-term editing/retention policy needs product review. |
| Quebra-Cabeças de Bolso | Play solvable 3×3/4×4/6×6 number or picture sliding puzzles, persist moves/timer, keep separate best times, confirm replacement of active progress and include one original vector illustration. | The original brief asks for a 30-image collection; current image mode contains one locally drawn illustration. |

## Release readiness distinction

The CI gate in this repository proves compilation, tests and deterministic simulator capture for these prototypes. It does not certify the original content quantities, rights, physical sensor behavior, Pix bank compatibility, App Review compliance or App Store readiness. Keep every demo label in place until the corresponding replacement content and checks are approved.
