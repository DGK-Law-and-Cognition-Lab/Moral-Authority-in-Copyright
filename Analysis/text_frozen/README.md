# Development-stage choices for the text analyses

The registered plan (Section 7.1) requires every tunable text-analysis choice to be made on the **development set** (all of Study 1 and the Study 2 responses in the 2025 interim file), frozen, and committed with its date **before** the test set (the 164 unseen Study 2 responses) is analyzed. Development work never looks at differences between conditions.

| File | What is settled here |
|---|---|
| `text_config.json` | masking list; uptake, word, and party-mention lists; model IDs and pinned revisions; number of STM topics; dictionary files and their SHA-256 |
| `codebook.md` | the reason codes, stance, and sentiment definitions (the prompt text for every language-model coder) |
| `anchors.json` | anchor sentences for the semantic axes |
| `human_codes_dev.csv` | the two human coders' independent codes for a stratified random 200 development responses (`pid, coder`, the 12 codes as 0/1, `stance`) |
| `human_codes_dev_consensus.csv` | the same 200 responses after the coders resolve disagreements (`pid`, codes, `stance`) |
| `human_codes_test.csv` | one coder's codes for a random 100 test responses, made after the freeze (`pid`, codes, `stance`) |
| `dictionaries/` | the official MFD 2.0 (`.dic`) and eMFD (`.csv`) files |

## Steps

1. Run `02_ratings_analysis.Rmd` and notebooks 03 to 05 with `MODE = "real"`. Until the configuration is frozen they process only the development set.
2. Settle the lists, codebook, and anchors on the development set, using word frequencies and the coders' work, never condition differences.
3. Choose the number of STM topics: render `06_text_statistics.Rmd` with `stage = "development"` and pick K from held-out likelihood, semantic coherence, and exclusivity; write it to `text_config.json`.
4. Pin the model revisions, set the Gemini model ID, add the dictionary files with their source and SHA-256, and remove "DRAFT" from `codebook.md`.
5. Run `python3 Analysis/python/freeze_text_config.py`, then commit and push `Analysis/text_frozen/`.
6. Code the 100 test responses by hand (`human_codes_test.csv`), then run notebooks 03 to 05 and `06_text_statistics.Rmd` (stage `test`) in real mode. Each checks that the configuration is frozen, that the frozen files match their recorded SHA-256, and that they are committed.
