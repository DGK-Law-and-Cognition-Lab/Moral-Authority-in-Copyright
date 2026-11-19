# Tests for the rating-analysis code. Run from the repository root:
#   Rscript -e 'testthat::test_dir("Analysis/tests")'
# No test reads a real response: they use hand-made rows and simulated data.

library(testthat)
find_root <- function() {
  p <- normalizePath(".")
  while (!file.exists(file.path(p, "Analysis", "R", "config.R"))) {
    np <- dirname(p); if (np == p) stop("repository root not found"); p <- np
  }
  p
}
root <- find_root()
for (f in c("config.R", "prepare.R", "models.R", "simulate.R")) source(file.path(root, "Analysis", "R", f))

toy <- function(n, study = 2) {
  d <- data.frame(pid = paste0("T", seq_len(n)), Type = rep(CELLS, length.out = n), stringsAsFactors = FALSE)
  for (col in CELL_TIMER) d[[col]] <- NA_real_
  for (i in seq_len(n)) d[i, CELL_TIMER[[d$Type[i]]]] <- 30
  d$Finished <- 1; d$WhoNewCheck <- 1; d$ReasonWhyCheck <- 2; d$repeat_response <- 0; d$Seriousness <- 4
  if (study == 2) {
    d$TransformCondition <- rep(c("High", "Low"), length.out = n)
    d$TransformText <- ifelse(d$TransformCondition == "High", paste(TRANSFORM_TEXT_START[["High"]], "of..."),
                              paste(TRANSFORM_TEXT_START[["Low"]], "photograph..."))
    d$WorkTransform <- ifelse(d$TransformCondition == "High", 1, 2)
    d$in_2025_interim <- 0
  }
  for (it in names(RAW_RANGE)) d[[it]] <- 3
  d$ArtTraining <- 1; d$CopyrightFamiliar <- 2; d$Gender <- 2
  d
}

test_that("reversed items are scored k - raw; others are unchanged; composites are means", {
  d <- toy(4); d$AllowedReason <- c(1, 2, 4, 5); d$ReduceMarket <- c(1, 3, 4, 6); d$Jury <- c(5, 1, 2, 3)
  d$CostReason <- c(2, 2, 2, 2); d$Payment <- c(1, 2, 3, 5)
  d[, MORAL_ITEMS] <- matrix(c(1, 2, 3, 4), nrow = 4, ncol = 4, byrow = TRUE)
  d <- score(flag_inclusion(d, 2), 2)
  expect_equal(d$AllowedReason, c(5, 4, 2, 1))
  expect_equal(d$ReduceMarket, c(6, 4, 3, 1))
  expect_equal(d$Jury, c(1, 5, 4, 3))
  expect_equal(d$CostReason, c(4, 4, 4, 4))
  expect_equal(d$AllowedReason_raw, c(1, 2, 4, 5))
  expect_equal(d$Payment, c(1, 2, 3, 5))
  expect_equal(d$Moral, rep(2.5, 4))
})

test_that("out-of-range raw values stop the analysis", {
  d <- toy(4); d$Payment[2] <- 6
  expect_error(score(flag_inclusion(d, 2), 2), "Payment")
})

test_that("ArtTraining 1,4,5,6,7 is recoded to 1-5", {
  d <- toy(5); d$ArtTraining <- c(1, 4, 5, 6, 7)
  d <- score(flag_inclusion(d, 2), 2)
  expect_equal(d$ArtTraining5, 1:5)
})

test_that("each inclusion rule excludes exactly the rows it should", {
  d <- toy(10)
  d$Finished[1] <- 0
  d$WhoNewCheck[2] <- 2
  d$ReasonWhyCheck[3] <- 3
  d$repeat_response[4] <- 1
  d$Seriousness[5] <- 1
  d$Seriousness[6] <- NA                                  # missing is not "No": kept
  d[7, CELL_TIMER[[d$Type[7]]]] <- NA                     # own timer empty
  other <- setdiff(CELLS, d$Type[8]); d[8, CELL_TIMER[[other[1]]]] <- 12   # a second timer filled
  d$TransformText[9] <- paste(TRANSFORM_TEXT_START[[setdiff(c("High", "Low"), d$TransformCondition[9])]], "x")
  d <- flag_inclusion(d, 2)
  expect_equal(d$included, c(FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE))
})

test_that("a Study 2 row without a valid transformation condition is not assigned", {
  d <- toy(4); d$TransformCondition[2] <- NA; d$TransformCondition[3] <- "Medium"
  d <- flag_inclusion(d, 2)
  expect_equal(d$assigned, c(TRUE, FALSE, FALSE, TRUE))
})

test_that("effect codes follow the registered sign conventions", {
  d <- toy(8); d <- add_codes(flag_inclusion(d, 2), 2)
  i <- match("Famous_LessFamous", d$Type)
  expect_equal(c(d$a[i], d$v[i]), c(0.5, 0.5))          # famous artist, unknown photographer
  j <- match("LessFamous_Famous", d$Type)
  expect_equal(c(d$a[j], d$v[j]), c(-0.5, -0.5))
  expect_equal(d$t[d$TransformCondition == "High"][1], 0.5)
  expect_true(all(d$worktransform_correct))
})

set.seed(11)
unbalanced <- function() {
  g <- expand.grid(a = c(-0.5, 0.5), v = c(-0.5, 0.5), t = c(-0.5, 0.5))
  reps <- sample(5:20, nrow(g), replace = TRUE)
  d <- g[rep(seq_len(nrow(g)), reps), ]
  d$y <- 2 + 0.3 * d$a - 0.7 * d$t + 0.5 * d$a * d$t + stats::rnorm(nrow(d), 0, 1 + (d$t > 0))
  d
}

test_that("coefficients are differences of unweighted marginal means", {
  d <- unbalanced()
  fit <- lm(y ~ a * v * t, data = d)
  m <- aggregate(y ~ a + v + t, data = d, FUN = mean)
  mm <- function(f, lv) mean(m$y[m[[f]] == lv])
  expect_equal(unname(coef(fit)["a"]), mm("a", 0.5) - mm("a", -0.5), tolerance = 1e-10)
  expect_equal(unname(coef(fit)["t"]), mm("t", 0.5) - mm("t", -0.5), tolerance = 1e-10)
  eff_a_at <- function(tt) mean(m$y[m$a == 0.5 & m$t == tt]) - mean(m$y[m$a == -0.5 & m$t == tt])
  expect_equal(unname(coef(fit)["a:t"]), eff_a_at(0.5) - eff_a_at(-0.5), tolerance = 1e-10)
})

test_that("HC3 Wald tests equal car::Anova Type III with sum contrasts and HC3", {
  d <- unbalanced(); d$y2 <- d$y
  ours <- coef_table(lm(y2 ~ a * v * t, data = d), 2, "y2")
  d$A <- factor(d$a); d$V <- factor(d$v); d$T <- factor(d$t)
  op <- options(contrasts = c("contr.sum", "contr.poly")); on.exit(options(op))
  fit2 <- lm(y2 ~ A * V * T, data = d)
  an <- car::Anova(fit2, type = 3, vcov. = sandwich::vcovHC(fit2, type = "HC3"))
  map <- c(a = "A", v = "V", t = "T", `a:v` = "A:V", `a:t` = "A:T", `v:t` = "V:T", `a:v:t` = "A:V:T")
  for (tm in names(map)) {
    expect_equal(ours$p[ours$term == tm], an[map[[tm]], "Pr(>F)"], tolerance = 1e-8, info = tm)
    expect_equal(ours$F[ours$term == tm], an[map[[tm]], "F"], tolerance = 1e-8, info = tm)
  }
  ss <- car::Anova(fit2, type = 3)               # ordinary Type III sums of squares
  for (tm in names(map)) {
    eta_ss <- ss[map[[tm]], "Sum Sq"] / (ss[map[[tm]], "Sum Sq"] + ss["Residuals", "Sum Sq"])
    expect_equal(ours$eta2_partial[ours$term == tm], eta_ss, tolerance = 1e-8, info = paste("eta2", tm))
  }
  expect_equal(ours$d, ours$estimate / ours$resid_sd)
})

test_that("TOST: equivalence holds exactly when the 90% CI is inside the bounds", {
  set.seed(3)
  for (i in 1:200) {
    est <- runif(1, -0.4, 0.4); se <- runif(1, 0.02, 0.2); df <- sample(30:300, 1)
    r <- tost(est, se, df)
    expect_equal(r$tost_p < 0.05, r$ci90_within_bounds)
  }
  r <- tost(0, 0.05, 200)
  expect_lt(r$tost_p, 0.001)
  expect_equal(r$tost_p_lower, stats::pt(0.25 / 0.05, 200, lower.tail = FALSE))
})

sim2 <- simulate_study(2, 20000, 99, root)
tmp <- tempfile(fileext = ".csv"); write.csv(sim2, tmp, row.names = FALSE, na = "")
big <- local({
  d <- read.csv(tmp, colClasses = "character", check.names = FALSE, na.strings = "")
  for (v in c("Finished", "WhoNewCheck", "ReasonWhyCheck", "Seriousness", "repeat_response", RATING_ITEMS,
              PERCEPTION_ITEMS, "ArtTraining", "CopyrightFamiliar", "Gender", unname(CELL_TIMER),
              "WorkTransform", "in_2025_interim")) d[[v]] <- as.numeric(d[[v]])
  d$study <- 2
  score(add_codes(flag_inclusion(d, 2), 2), 2)
})
big_s <- analysis_sample(big)

test_that("the simulated file has exactly the real files' columns", {
  expect_identical(names(sim2), codebook_columns(2, root))
  expect_identical(names(simulate_study(1, 50, 1, root)), codebook_columns(1, root))
})

test_that("confirmatory tests recover the planted effects with the registered signs", {
  cf <- run_confirmatory(big_s)
  g <- function(tst, col) cf[[col]][cf$test == tst]
  expect_lt(g("C1", "estimate"), 0)                      # planted: high transformation lowers restriction
  expect_true(g("C1", "supported"))
  expect_gt(g("C2", "estimate"), 0); expect_true(g("C2", "supported"))
  expect_gt(g("C3", "estimate"), 0); expect_true(g("C3", "supported"))
  expect_true(g("C4", "ci90_within_bounds"))            # planted artist effect = 0
  expect_true(g("C4", "supported"))
  expect_equal(g("C4", "p_family"), g("C4", "tost_p"))   # the Holm family uses the TOST p for C4
  expect_lt(g("C5", "estimate"), 0)                      # planted negative artist x transformation
  expect_true(g("C5", "ordinal_agrees"))
  expect_equal(cf$p_holm, p.adjust(cf$p_family, "holm"))
  un <- attr(cf, "unseen_table")
  expect_equal(nrow(un), 5); expect_equal(un$n[1], sum(big_s$in_2025_interim == 0))
  expect_true(g("C4", "ci_holm_low") <= g("C4", "ci90_low"))   # Holm-level CI is at least as wide
})

test_that("robustness checks and full tables run and have the expected shape", {
  cf <- run_confirmatory(big_s)
  rb <- run_robustness(big, cf)
  expect_equal(nrow(rb), 5 * 5)
  expect_true(all(c("sign_flip", "crosses_05", "changes") %in% names(rb)))
  tab <- all_terms(big_s, 2)
  expect_equal(nrow(tab), length(c(PRIMARY, SECONDARY)) * 7)
  expect_true(all(is.na(tab$ord_p[tab$outcome %in% c("Moral", "Harm")])))
  expect_equal(sum(!is.na(tab$p_holm_primary_family)), 4 * 7)
})
