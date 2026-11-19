# 01_simulate_data.R
# Writes synthetic versions of the two de-identified files to Analysis/simulated/.
# They have the real files' columns and codes, the same number of rows, and
# planted effects (see R/simulate.R). The analysis is run on them first, as the
# registered plan requires (Section 6). Run from the repository root:
#   Rscript Analysis/01_simulate_data.R

for (f in c("config.R", "simulate.R")) source(file.path("Analysis", "R", f))
dir.create(file.path("Analysis", "simulated"), showWarnings = FALSE)
for (s in 1:2) {
  n <- if (s == 1) 276 else 599
  d <- simulate_study(s, n, seed = SEED + s, root = ".")
  path <- file.path("Analysis", "simulated", sprintf("Study%d_simulated.csv", s))
  write.csv(d, path, row.names = FALSE, na = "")
  cat(sprintf("Study %d: %d simulated rows written to %s\n", s, nrow(d), path))
}
