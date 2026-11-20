# Changes after registration

The registered plan (OSF, 19 November 2026, Section 9) says any change after registration is listed with its reason. This file lists each one.

## 1. Firth fallback in the 4–5 vs 1–3 logistic check (19 November 2026)

**What.** One robustness check splits reverse-scored AllowedReason at 4–5 vs 1–3 and fits a logistic regression (plan, Section 6). The code was meant to switch to Firth logistic regression if the ordinary fit separated, but it switched only when R issued a warning.

**What happened.** In the first real-data run (commit 112f145), two of the eight Study 2 cells answered 4–5 throughout (28 of 28 and 26 of 26). R's fit converged without a warning, giving a coefficient of −9.8 for transformation with a standard error of 444, so the check's C1 and C5 rows were uninterpretable.

**Change.** Because the model has one parameter per cell, ordinary estimates exist only if every cell has both outcomes. The code now checks the cells directly and uses Firth's method when any cell has only one outcome (commit e6cad5f; a test reproduces the case). This is the fallback the plan's Section 9 calls for when a planned model cannot be fit.

**Effect.** Only that check changed. The analysis was rerun on the fixed code; the other 20 output tables are byte-identical to the first run. With Firth's method, the check agrees with C1 (log-odds −2.42, Holm p = 2.5 × 10⁻⁷), and no check changes any confirmatory result. The first run's output is kept in `Analysis/output/real/superseded/`.

## 2. Reason codebook: a thirteenth code and rules for hard cases (19 November 2026)

**What.** The plan lists twelve reason codes (Section 7.5) and lets the two human coders refine the codebook on the development set.

**What happened.** The coders coded 20 development responses for calibration (items P01–P20, never used in any result; no condition information). Seven of the 20 gave a reason no code covered: Martinez's work depends on Rivera's photograph or effort ("the foundation to Martinez's artwork", "would have no artwork made without it", "Rivera did most of the hard work"); two of those responses received no code at all. The coders also disagreed where the definitions were silent: whether a statement that Martinez did not pay counts, how money mentioned inside a remedy is coded, and whether a reason in the story but not in the explanation is coded.

**Change.** Before any of the 200 independent-coding responses were coded, the codebook (`Analysis/text_frozen/codebook.md`, revision 1) added code 13, *reliance* (Martinez's work depends on Rivera's photograph or effort), extended *remedy* to include that Martinez did not pay Rivera, and added five written rules for hard cases. The twelve registered codes keep their names and definitions. The language-model coders receive the same codebook.

**Effect.** Reliance is analyzed like the registered codes: it is used only if it passes the same κ ≥ .70 gate, and, like every reason-code result, it is exploratory. Results for it are reported as an added code.
