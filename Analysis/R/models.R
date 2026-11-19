# models.R
# Rating-outcome models (Section 6 of the registered plan).
# Requires config.R and prepare.R.

suppressPackageStartupMessages({
  library(sandwich)
  library(ordinal)
  library(effectsize)
})

rhs <- function(study) if (study == 2) "a * v * t" else "a * v"

# ---- Linear model with HC3 (Section 6, Models) ----------------------------------
fit_lm <- function(d, outcome, study) {
  vars <- c(outcome, "a", "v", if (study == 2) "t")
  dd <- d[stats::complete.cases(d[, vars]), vars]
  lm(stats::as.formula(paste(outcome, "~", rhs(study))), data = dd)
}

# One row per model term: estimate (difference in unweighted marginal means, or
# difference of differences), HC3 SE, t, p, 95% CI, d (estimate / residual SD),
# and partial eta squared with a 95% CI. Tests and CIs use HC3 errors. Partial
# eta squared is the usual Type III quantity, SS_term / (SS_term + SS_error),
# which for a 1-df term equals F / (F + df) with the ordinary OLS F.
coef_table <- function(fit, study, outcome) {
  V <- sandwich::vcovHC(fit, type = "HC3")
  b <- coef(fit); se <- sqrt(diag(V)); se_ols <- sqrt(diag(stats::vcov(fit)))
  df <- fit$df.residual; sig <- stats::sigma(fit); q <- stats::qt(0.975, df)
  do.call(rbind, lapply(TERMS[[as.character(study)]], function(tm) {
    est <- unname(b[tm]); s <- unname(se[tm]); tval <- est / s
    Fv <- tval^2
    F_ols <- (est / unname(se_ols[tm]))^2
    eta <- effectsize::F_to_eta2(F_ols, df = 1, df_error = df, ci = 0.95, alternative = "two.sided")
    data.frame(study = study, outcome = outcome, term = tm, label = TERM_LABELS[[tm]],
               n = stats::nobs(fit), estimate = est, se_hc3 = s, t = tval, df = df,
               p = 2 * stats::pt(-abs(tval), df),
               ci_low = est - q * s, ci_high = est + q * s,
               d = est / sig, d_ci_low = (est - q * s) / sig, d_ci_high = (est + q * s) / sig,
               F = Fv, F_ols = F_ols, eta2_partial = eta$Eta2_partial, eta2_ci_low = eta$CI_low, eta2_ci_high = eta$CI_high,
               resid_sd = sig, stringsAsFactors = FALSE)
  }))
}

# ---- Ordinal (proportional-odds) model -------------------------------------------
# Returns a table of the same terms on the latent (log-odds) scale. If the model
# does not converge, the fallback in Section 9 applies (the linear result is
# used) and `status` says so.
fit_clm <- function(d, outcome, study) {
  vars <- c(outcome, "a", "v", if (study == 2) "t")
  dd <- d[stats::complete.cases(d[, vars]), vars]
  dd$y <- factor(dd[[outcome]], levels = sort(unique(dd[[outcome]])), ordered = TRUE)
  fit <- tryCatch(ordinal::clm(stats::as.formula(paste("y ~", rhs(study))), data = dd, link = "logit"),
                  error = function(e) e)
  fit
}

# Convergence rule. A fit is accepted if ordinal::clm reports convergence
# (code 0), or if Newton's method stopped only because the step factor reached
# its minimum while the gradient is negligible relative to the sample size
# (max|gradient| / n < 1e-6) and the Hessian is well conditioned (cond.H < 1e6).
# The second case is a floating-point limit of the absolute gradient tolerance
# (1e-6) in large samples; at the study's sample sizes the default converges.
clm_status <- function(fit) {
  if (inherits(fit, "error")) return(list(ok = FALSE, status = paste("error:", conditionMessage(fit))))
  code <- fit$convergence$code
  g <- max(abs(fit$gradient)); n <- fit$nobs
  if (identical(as.integer(code), 0L)) return(list(ok = TRUE, status = "converged"))
  if (grepl("step factor reduced below minimum", fit$message) && g / n < 1e-6 && is.finite(fit$cond.H) && fit$cond.H < 1e6)
    return(list(ok = TRUE, status = sprintf("converged (step-factor limit; max|grad|/n = %.1e)", g / n)))
  list(ok = FALSE, status = sprintf("not converged (%s; max|grad| = %.1e)", fit$message, g))
}

ordinal_table <- function(d, outcome, study) {
  fit <- suppressWarnings(fit_clm(d, outcome, study))
  terms <- TERMS[[as.character(study)]]
  st <- clm_status(fit)
  if (!st$ok) {
    return(data.frame(study = study, outcome = outcome, term = terms, ord_estimate = NA_real_,
                      ord_se = NA_real_, ord_z = NA_real_, ord_p = NA_real_,
                      ord_status = paste(st$status, "- linear result used (Section 9)"),
                      stringsAsFactors = FALSE))
  }
  cf <- summary(fit)$coefficients
  data.frame(study = study, outcome = outcome, term = terms,
             ord_estimate = cf[terms, "Estimate"], ord_se = cf[terms, "Std. Error"],
             ord_z = cf[terms, "z value"], ord_p = cf[terms, "Pr(>|z|)"],
             ord_status = st$status, stringsAsFactors = FALSE)
}

# ---- Equivalence (C4) -------------------------------------------------------------
tost <- function(est, se, df, bound = EQUIV_BOUND) {
  p_low  <- stats::pt((est + bound) / se, df, lower.tail = FALSE)   # H0: est <= -bound
  p_high <- stats::pt((est - bound) / se, df, lower.tail = TRUE)    # H0: est >= +bound
  q <- stats::qt(0.95, df)
  data.frame(tost_p_lower = p_low, tost_p_upper = p_high, tost_p = max(p_low, p_high),
             ci90_low = est - q * se, ci90_high = est + q * se,
             ci90_within_bounds = (est - q * se > -bound) & (est + q * se < bound))
}

# ---- Confirmatory tests C1-C5 (Section 6) ----------------------------------------
# `d2` is the analysis sample of Study 2 (or a robustness variant of it).
# `scale` = "linear" (registered), "ordinal" or "logistic" (robustness checks);
# under ordinal/logistic, tests on outcomes without that model (Harm, and the
# C4 equivalence test) keep their linear result, as stated in the output.
confirmatory_core <- function(d2, scale = "linear") {
  rows <- lapply(seq_len(nrow(CONFIRMATORY)), function(i) {
    ct <- CONFIRMATORY[i, ]
    lin <- coef_table(fit_lm(d2, ct$outcome, 2), 2, ct$outcome)
    lin <- lin[lin$term == ct$term, ]
    r <- data.frame(test = ct$test, outcome = ct$outcome, term = ct$term, label = lin$label,
                    predicted = ct$predicted, n = lin$n, scale = "linear",
                    estimate = lin$estimate, se = lin$se_hc3, p_two_sided = lin$p,
                    ci_low = lin$ci_low, ci_high = lin$ci_high, d = lin$d, df = lin$df,
                    stringsAsFactors = FALSE)
    if (ct$test == "C4") r <- cbind(r, tost(lin$estimate, lin$se_hc3, lin$df))
    if (scale == "ordinal" && ct$outcome %in% SINGLE_ITEM_OUTCOMES && ct$test != "C4") {
      o <- ordinal_table(d2, ct$outcome, 2); o <- o[o$term == ct$term, ]
      if (!is.na(o$ord_p)) { r$scale <- "ordinal"; r$estimate <- o$ord_estimate; r$se <- o$ord_se; r$p_two_sided <- o$ord_p }
    }
    if (scale == "logistic" && ct$outcome == "AllowedReason" && ct$test != "C4") {
      g <- logistic_term(d2, ct$term)
      r$scale <- g$scale; r$estimate <- g$estimate; r$se <- g$se; r$p_two_sided <- g$p
    }
    r
  })
  out <- do.call(rbind, lapply(rows, function(r) {
    keep <- c("test", "outcome", "term", "label", "predicted", "n", "scale", "estimate", "se",
              "p_two_sided", "ci_low", "ci_high", "d", "df")
    extra <- setdiff(names(r), keep)
    full <- r[, keep]
    for (e in c("tost_p_lower", "tost_p_upper", "tost_p", "ci90_low", "ci90_high", "ci90_within_bounds"))
      full[[e]] <- if (e %in% extra) r[[e]] else NA
    full
  }))
  # The p value that enters the Holm family: two-sided for C1, C2, C3, C5; TOST for C4.
  out$p_family <- ifelse(out$test == "C4", out$tost_p, out$p_two_sided)
  out$p_holm <- stats::p.adjust(out$p_family, method = "holm")
  # The CI that matches C4's Holm level: Holm compares C4's p with alpha / (m - rank + 1).
  k4 <- which(out$test == "C4")
  if (length(k4) && !is.na(out$tost_p[k4])) {
    rank4 <- rank(out$p_family, ties.method = "first")[k4]
    a4 <- ALPHA / (nrow(out) - rank4 + 1)
    q4 <- stats::qt(1 - a4, out$df[k4])
    out$holm_alpha_c4 <- NA; out$holm_alpha_c4[k4] <- a4
    out$ci_holm_low <- NA; out$ci_holm_high <- NA
    out$ci_holm_low[k4] <- out$estimate[k4] - q4 * out$se[k4]
    out$ci_holm_high[k4] <- out$estimate[k4] + q4 * out$se[k4]
  }
  out$sign_matches_prediction <- ifelse(is.na(out$predicted), NA, sign(out$estimate) == out$predicted)
  out
}

# Reverse-scored AllowedReason split at 4-5 vs 1-3 (Section 6, checks). Logistic
# regression; Firth's method if the ordinary fit separates.
# The model is saturated in the 8 cells, so ordinary estimates exist only if every
# cell has both outcomes. A cell with all 0s or all 1s (quasi-separation) can
# converge without any warning from glm, so the cells are checked directly.
logistic_separated <- function(dd) {
  cells <- table(interaction(dd$a, dd$v, dd$t, drop = TRUE), factor(dd$restrict, levels = 0:1))
  any(cells == 0)
}

logistic_term <- function(d2, term) {
  dd <- d2[stats::complete.cases(d2[, c("AllowedReason", "a", "v", "t")]), ]
  dd$restrict <- as.integer(dd$AllowedReason >= 4)
  warn <- NULL
  g <- withCallingHandlers(stats::glm(restrict ~ a * v * t, family = stats::binomial(), data = dd),
                           warning = function(w) { warn <<- conditionMessage(w); invokeRestart("muffleWarning") })
  if (logistic_separated(dd) ||
      (!is.null(warn) && grepl("fitted probabilities numerically 0 or 1|did not converge", warn))) {
    f <- logistf::logistf(restrict ~ a * v * t, data = dd)
    i <- which(names(f$coefficients) == term)
    return(list(scale = "logistic (Firth)", estimate = unname(f$coefficients[i]),
                se = sqrt(diag(f$var))[i], p = unname(f$prob[i])))
  }
  cf <- summary(g)$coefficients
  list(scale = "logistic", estimate = cf[term, "Estimate"], se = cf[term, "Std. Error"],
       p = cf[term, "Pr(>|z|)"])
}

run_confirmatory <- function(d2) {
  main <- confirmatory_core(d2)
  # Unseen subset: the 164 analyzed responses not in the 2025 interim file.
  uns <- d2[!is.na(d2$in_2025_interim) & d2$in_2025_interim == 0, ]
  un <- confirmatory_core(uns)
  main$n_unseen <- un$n
  main$estimate_unseen <- un$estimate
  main$p_two_sided_unseen <- un$p_two_sided
  main$same_sign_unseen <- sign(un$estimate) == sign(main$estimate)
  # C5 must also agree in sign and significance (p < .05) with the ordinal model.
  # If the ordinal model cannot be fit, Section 9's fallback applies: the linear
  # result stands, ordinal_agrees is NA, and ordinal_status says why.
  o <- ordinal_table(d2, "AllowedReason", 2); o <- o[o$term == "a:t", ]
  main$ordinal_estimate <- ifelse(main$test == "C5", o$ord_estimate, NA)
  main$ordinal_p <- ifelse(main$test == "C5", o$ord_p, NA)
  main$ordinal_status <- ifelse(main$test == "C5", o$ord_status, NA)
  main$ordinal_agrees <- ifelse(main$test == "C5",
                                if (is.na(o$ord_p)) NA else (sign(o$ord_estimate) == sign(main$estimate[main$test == "C5"]) && o$ord_p < ALPHA),
                                NA)
  # What counts as supported (Section 6). Applied literally to every test,
  # including the same-sign rule for C4.
  main$supported <- main$p_holm < ALPHA &
    (is.na(main$sign_matches_prediction) | main$sign_matches_prediction) &
    main$same_sign_unseen &
    (is.na(main$ordinal_agrees) | main$ordinal_agrees)
  main$verdict <- ifelse(main$test == "C4",
                         ifelse(main$supported, "equivalence supported (|artist effect| < 0.25)",
                                ifelse(main$p_two_sided < ALPHA, "no equivalence; two-sided test shows a difference (see p_two_sided)",
                                       "inconclusive: neither equivalence nor a difference")),
                         ifelse(main$supported, "supported", "not supported"))
  attr(main, "unseen_table") <- un        # the full C1-C5 table on the unseen subset (Section 8)
  main
}

# Robustness checks (Section 6): rerun C1-C5 on each variant and flag changes.
# A check changes a result if it flips the sign of the estimate or moves the
# Holm-adjusted p across .05.
compare_to_primary <- function(primary, variant, name) {
  data.frame(check = name, test = primary$test,
             primary_scale = primary$scale, check_scale = variant$scale,
             primary_estimate = primary$estimate, check_estimate = variant$estimate,
             primary_p_holm = primary$p_holm, check_p_holm = variant$p_holm,
             primary_n = primary$n, check_n = variant$n,
             sign_flip = sign(primary$estimate) != sign(variant$estimate),
             crosses_05 = (primary$p_holm < ALPHA) != (variant$p_holm < ALPHA),
             changes = sign(primary$estimate) != sign(variant$estimate) |
               (primary$p_holm < ALPHA) != (variant$p_holm < ALPHA),
             stringsAsFactors = FALSE)
}

# Sample variants for the checks. Study 1 has no WorkTransform item.
robustness_samples <- function(d) {
  out <- list(
    nonserious_included = d[d$first & d$consistent, ],
    # "All finished first responses, ignoring the comprehension checks" (Section 6), read
    # literally: this sample also keeps responders who said they were not serious.
    all_finished_first_no_checks = d[d$finished & !is.na(d$repeat_response) & d$repeat_response == 0 & d$consistent, ]
  )
  if ("worktransform_correct" %in% names(d))
    out$without_worktransform_failures <- d[d$included & !is.na(d$worktransform_correct) & d$worktransform_correct, ]
  out
}

run_robustness <- function(d_all2, primary) {
  d2 <- analysis_sample(d_all2)
  out <- list(
    ordinal = compare_to_primary(primary, confirmatory_core(d2, "ordinal"), "ordinal models"),
    logistic = compare_to_primary(primary, confirmatory_core(d2, "logistic"), "AllowedReason split 4-5 vs 1-3 (logistic)")
  )
  for (nm in names(rs <- robustness_samples(d_all2))) {
    out[[nm]] <- compare_to_primary(primary, confirmatory_core(rs[[nm]]), nm)
  }
  do.call(rbind, out)
}

# ---- All terms x all outcomes (Section 6, Secondary results) ----------------------
all_terms <- function(d, study) {
  outs <- c(PRIMARY, SECONDARY)
  tab <- do.call(rbind, lapply(outs, function(o) coef_table(fit_lm(d, o, study), study, o)))
  tab$outcome_type <- ifelse(tab$outcome %in% PRIMARY, "primary", "secondary")
  # Holm across all terms and the four primary outcomes (registered family).
  tab$p_holm_primary_family <- NA_real_
  k <- tab$outcome_type == "primary"
  tab$p_holm_primary_family[k] <- stats::p.adjust(tab$p[k], "holm")
  # Analogous family for the secondary outcomes (labeled; not named in the plan).
  tab$p_holm_secondary_family <- NA_real_
  tab$p_holm_secondary_family[!k] <- stats::p.adjust(tab$p[!k], "holm")
  # Ordinal models for every single-item outcome.
  ord <- do.call(rbind, lapply(intersect(outs, SINGLE_ITEM_OUTCOMES), function(o) ordinal_table(d, o, study)))
  tab <- merge(tab, ord, by = c("study", "outcome", "term"), all.x = TRUE, sort = FALSE)
  tab$ord_same_sign <- sign(tab$ord_estimate) == sign(tab$estimate)
  # Interaction claim rule: linear and ordinal agree in sign and both p < .05.
  is_int <- grepl(":", tab$term)
  # Composites (Moral, Harm) have no ordinal model in the plan; read literally, the
  # rule cannot be met for them, so no composite interaction is claimed. If a
  # single item's ordinal model fails, Section 9's fallback applies and the claim
  # rests on the linear model alone (noted).
  single <- tab$outcome %in% SINGLE_ITEM_OUTCOMES
  ord_failed <- single & is.na(tab$ord_p)
  tab$interaction_claim <- ifelse(!is_int, NA,
                                  ifelse(!single, FALSE,
                                         ifelse(ord_failed, tab$p < ALPHA,
                                                tab$p < ALPHA & tab$ord_p < ALPHA & tab$ord_same_sign)))
  tab$interaction_claim_note <- ifelse(is_int & !single, "composite: no ordinal model; rule cannot be met",
                                       ifelse(is_int & ord_failed, "ordinal model not converged; linear fallback (Section 9)", ""))
  tab[order(match(tab$outcome, outs), match(tab$term, TERMS[[as.character(study)]])), ]
}

# ---- Descriptives -------------------------------------------------------------------
cell_means <- function(d, study, outcomes) {
  do.call(rbind, lapply(outcomes, function(o) {
    do.call(rbind, lapply(sort(unique(d$cell)), function(cl) {
      x <- d[[o]][d$cell == cl]
      data.frame(study = study, outcome = o, cell = cl, n = sum(!is.na(x)),
                 mean = mean(x, na.rm = TRUE), sd = stats::sd(x, na.rm = TRUE), stringsAsFactors = FALSE)
    }))
  }))
}

factor_means <- function(d, study, outcomes) {
  fs <- c("artist", "victim", if (study == 2) "transform")
  do.call(rbind, lapply(outcomes, function(o) do.call(rbind, lapply(fs, function(f) {
    do.call(rbind, lapply(levels(d[[f]]), function(lv) {
      x <- d[[o]][d[[f]] == lv]
      data.frame(study = study, outcome = o, factor = f, level = lv, n = sum(!is.na(x)),
                 mean = mean(x, na.rm = TRUE), sd = stats::sd(x, na.rm = TRUE), stringsAsFactors = FALSE)
    }))
  }))))
}

composite_alpha <- function(d, study) {
  a <- function(items) suppressWarnings(psych::alpha(d[, items], check.keys = FALSE, warnings = FALSE)$total$raw_alpha)
  data.frame(study = study, composite = c("Moral", "Harm"),
             items = c(paste(MORAL_ITEMS, collapse = ", "), paste(HARM_ITEMS, collapse = ", ")),
             cronbach_alpha = c(a(MORAL_ITEMS), a(HARM_ITEMS)))
}

worktransform_table <- function(d2) {
  do.call(rbind, lapply(sort(unique(d2$cell)), function(cl) {
    x <- d2$worktransform_correct[d2$cell == cl]
    data.frame(cell = cl, n = sum(!is.na(x)), n_correct = sum(x, na.rm = TRUE),
               share_correct = mean(x, na.rm = TRUE))
  }))
}

# ---- Attrition (Section 6) ------------------------------------------------------------
attrition_tests <- function(d, study) {
  steps <- c("finished", "passed", "first", "serious", "included")
  prev <- c("assigned", steps[-length(steps)])
  set.seed(SEED)
  rows <- lapply(seq_along(steps), function(i) {
    at <- d[d[[prev[i]]], ]
    if (all(at[[steps[i]]])) {
      return(data.frame(study = study, step = paste(prev[i], "->", steps[i]), n_at_start = nrow(at),
                        n_dropped = 0L, chisq = NA_real_, df = NA_real_, p = NA_real_,
                        method = "no exclusions at this step", stringsAsFactors = FALSE))
    }
    tb <- table(at$cell, factor(at[[steps[i]]], levels = c(FALSE, TRUE)))
    ct <- suppressWarnings(stats::chisq.test(tb))
    small <- any(ct$expected < 5)
    if (small) ct <- stats::chisq.test(tb, simulate.p.value = TRUE, B = 1e4)
    data.frame(study = study, step = paste(prev[i], "->", steps[i]), n_at_start = nrow(at),
               n_dropped = sum(!at[[steps[i]]]), chisq = unname(ct$statistic),
               df = if (small) NA else unname(ct$parameter), p = ct$p.value,
               method = if (small) "chi-squared, Monte Carlo p (B = 10,000; expected counts < 5)" else "chi-squared",
               stringsAsFactors = FALSE)
  })
  overall_at <- d[d$assigned, ]
  tb <- table(overall_at$cell, factor(overall_at$included, levels = c(FALSE, TRUE)))
  ct <- stats::chisq.test(tb, simulate.p.value = TRUE, B = 1e4)
  rbind(do.call(rbind, rows),
        data.frame(study = study, step = "assigned -> included (overall)", n_at_start = nrow(overall_at),
                   n_dropped = sum(!overall_at$included), chisq = unname(ct$statistic), df = NA,
                   p = ct$p.value, method = "chi-squared, Monte Carlo p (B = 10,000)"))
}

# ---- Pooled fame effects (Section 6, secondary) -----------------------------------------
pooled_fame <- function(tab1, tab2) {
  do.call(rbind, lapply(intersect(unique(tab1$outcome), unique(tab2$outcome)), function(o) {
    do.call(rbind, lapply(c("a", "v"), function(tm) {
      r1 <- tab1[tab1$outcome == o & tab1$term == tm, ]; r2 <- tab2[tab2$outcome == o & tab2$term == tm, ]
      y <- c(r1$estimate, r2$estimate); se <- c(r1$se_hc3, r2$se_hc3); w <- 1 / se^2
      est <- sum(w * y) / sum(w); s <- sqrt(1 / sum(w)); Q <- sum(w * (y - est)^2)
      data.frame(outcome = o, term = tm, label = TERM_LABELS[[tm]],
                 estimate_study1 = y[1], estimate_study2 = y[2], pooled_estimate = est, pooled_se = s,
                 ci_low = est - 1.959964 * s, ci_high = est + 1.959964 * s,
                 z = est / s, p = 2 * stats::pnorm(-abs(est / s)),
                 Q = Q, Q_df = 1, Q_p = stats::pchisq(Q, 1, lower.tail = FALSE), stringsAsFactors = FALSE)
    }))
  }))
}

# ---- Exploratory moderators (Section 6) ---------------------------------------------------
moderators <- function(d, study) {
  mods <- c(ArtTraining5 = "Art training (1-5)", CopyrightFamiliar = "Copyright familiarity")
  facs <- c("a", "v", if (study == 2) "t")
  do.call(rbind, lapply(names(mods), function(m) do.call(rbind, lapply(PRIMARY, function(o) {
    vars <- c(o, "a", "v", if (study == 2) "t", m)
    dd <- d[stats::complete.cases(d[, vars]), vars]
    dd$m_c <- dd[[m]] - mean(dd[[m]])
    f <- stats::as.formula(paste(o, "~", rhs(study), "+ m_c +", paste0("m_c:", facs, collapse = " + ")))
    fit <- lm(f, data = dd); V <- sandwich::vcovHC(fit, type = "HC3")
    tms <- paste0(facs, ":m_c"); tms <- ifelse(tms %in% names(coef(fit)), tms, paste0("m_c:", facs))
    data.frame(study = study, moderator = mods[[m]], outcome = o, term = tms,
               estimate = coef(fit)[tms], se_hc3 = sqrt(diag(V))[tms], n = stats::nobs(fit),
               p = 2 * stats::pt(-abs(coef(fit)[tms] / sqrt(diag(V))[tms]), fit$df.residual),
               stringsAsFactors = FALSE)
  }))))
}
