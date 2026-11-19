# Changes after registration

The registered plan (OSF, 19 November 2026, Section 9) says any change after registration is listed with its reason. This file lists each one.

## 1. Firth fallback in the 4–5 vs 1–3 logistic check (19 November 2026)

**What.** One robustness check splits reverse-scored AllowedReason at 4–5 vs 1–3 and fits a logistic regression (plan, Section 6). The code was meant to switch to Firth logistic regression if the ordinary fit separated, but it switched only when R issued a warning.

**What happened.** In the first real-data run (commit 112f145), two of the eight Study 2 cells answered 4–5 throughout (28 of 28 and 26 of 26). R's fit converged without a warning, giving a coefficient of −9.8 for transformation with a standard error of 444, so the check's C1 and C5 rows were uninterpretable.

**Change.** Because the model has one parameter per cell, ordinary estimates exist only if every cell has both outcomes. The code now checks the cells directly and uses Firth's method when any cell has only one outcome (commit e6cad5f; a test reproduces the case). This is the fallback the plan's Section 9 calls for when a planned model cannot be fit.

**Effect.** Only that check changed. The analysis was rerun on the fixed code; the other 20 output tables are byte-identical to the first run. With Firth's method, the check agrees with C1 (log-odds −2.42, Holm p = 2.5 × 10⁻⁷), and no check changes any confirmatory result. The first run's output is kept in `Analysis/output/real/superseded/`.
