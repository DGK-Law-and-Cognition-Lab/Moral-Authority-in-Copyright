# Development-stage choices for the text analyses

The registered plan (Section 7.1) requires every tunable text-analysis choice to be made on the **development set** (all of Study 1 and the Study 2 responses in the 2025 interim file), frozen, and committed with its date **before** the test set (the 164 unseen Study 2 responses) is analyzed. Development work never looks at differences between conditions.

| File | What is settled here |
|---|---|
| `text_config.json` | masking list; uptake, word, and party-mention lists; model IDs and pinned revisions; number of STM topics; dictionary files and their SHA-256 |
| `codebook.md` | the reason codes, stance, and sentiment definitions (the prompt text for every language-model coder, and the definitions on the human coders' sheets) |
| `anchors.json` | anchor sentences for the semantic axes |
| `coding_sample_dev.csv` | the human-coding items: 200 development responses for independent coding (`D001`-`D200`, stratified by study and condition cell) and other development responses for calibration (`P01`-`P20`, round 1; `P21`-`P40`, round 2). Drawn with `coding_sheets.py draw-dev` and `draw-calibration` |
| `human_codes_dev.csv` | the two human coders' independent codes for the 200 (`pid, coder`, the reason codes as 0/1, `stance`) |
| `human_codes_dev_consensus.csv` | the same 200 after the coders resolve disagreements (`pid`, codes, `stance`) |
| `human_codes_test.csv` | one coder's codes for a random 100 test responses, made after the freeze (`pid`, codes, `stance`) |
| `dictionaries/` | the official MFD 2.0 (`.dic`, OSF) and eMFD (`.csv`, GitHub) files. They are not stored in the repository: `textlib.dictionary_file` downloads each from the source recorded in `text_config.json` and checks its SHA-256 (recorded 19 Nov 2026) |

## Order

1. **Coding sheets.** `python3 Analysis/python/coding_sheets.py sheets-dev OUTDIR` writes a calibration workbook (20 items, both coders) and one workbook per coder (the 200 items). Conditions are never shown; the definitions come from `codebook.md`.
2. **Calibration.** The coders code the 20 calibration items, discuss them, and agree on any changes to the definitions in `codebook.md`. Then rerun step 1 so the 200-item sheets show the final codebook (the items do not change). For more practice, `coding_sheets.py draw-calibration N` adds round N of 20 new development responses. Round 1 led to codebook revision 1 (a 13th code, *reliance*, and rules for hard cases; `Docs/Changes after registration.md`, entry 2); round 2 lets the coders practice with it.
3. **Independent coding.** Each coder codes the 200 alone. `coding_sheets.py import-dev SHEET_A SHEET_B` writes `human_codes_dev.csv` and reports kappa before any discussion. The coders then resolve disagreements in a consensus workbook, imported with the third argument to `import-dev`.
4. **Other development choices** (alongside steps 2 and 3): settle the masking, uptake, word, and party lists from development-set word frequencies; settle the anchors; choose the number of STM topics (`06_text_statistics.Rmd`, `stage = "development"`: held-out likelihood, semantic coherence, exclusivity); pin the model revisions; set the Gemini model ID; record whether the primary coder is `gpt-oss-120b` or, if no 80 GB GPU is available, `gpt-oss-20b`.
5. **Commit the codebook and model settings** before any language-model coding (plan, Section 7.5).
6. **Development run.** Run notebooks 03 to 05 with `MODE = "real"`. Until the configuration is frozen they process only the development set; notebook 05 codes it with every model and computes the reliability gate.
7. **Freeze.** Remove "DRAFT" from `codebook.md`, run `python3 Analysis/python/freeze_text_config.py`, then commit and push `Analysis/text_frozen/`.
8. **Test-set human check.** One coder codes a random 100 test responses (`human_codes_test.csv`).
9. **Test run.** Run notebooks 03 to 05 and `06_text_statistics.Rmd` (`stage = "test"`) with `MODE = "real"`. Each checks that the configuration is frozen, that the frozen files match their recorded SHA-256, and that they are committed.

## Running the notebooks in Colab

The notebooks clone this repository from GitHub into the Colab session (so the freeze check can verify the commit), mount Google Drive, and read the data from and write the results to a copy of this repository kept in Google Drive. Before the first run, add these Colab Secrets (key icon in the left bar) and turn on each notebook's access to them:

| Secret | Value |
|---|---|
| `DRIVE_FOLDER` | the folder of your Drive copy of this repository, relative to My Drive |
| `ANTHROPIC_API_KEY` | for the Claude check coder (notebook 05) |
| `GEMINI_API_KEY` | for the Gemini embeddings and check coder (notebooks 04, 05) |
| `VOYAGE_API_KEY` | for the Voyage embeddings (notebook 04) |

The setup cell stops if the Drive copy's `text_input.csv` differs from the committed one. Results land in the Drive copy's `Analysis/output/<mode>/text/`; copy them into the repository and commit them. Notebook 04 needs a GPU runtime for `Qwen3-Embedding-8B`; notebook 05 needs a GPU with about 80 GB for `gpt-oss-120b`.
