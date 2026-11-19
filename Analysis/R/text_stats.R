# text_stats.R
# Statistical tests of the text features (registered plan, Section 7).
# Requires config.R and models.R (for coef_table / fit_lm and the effect codes).

suppressPackageStartupMessages({
  library(vegan)
  library(logistf)
  library(MASS)
  library(glmnet)
})

read_embeddings <- function(dir, key, version, pids) {
  path <- file.path(dir, sprintf("%s__%s.parquet", key, version))
  e <- as.data.frame(arrow::read_parquet(path))
  m <- match(pids, e$pid)
  if (anyNA(m)) stop(path, ": embeddings missing for ", sum(is.na(m)), " responses")
  X <- as.matrix(e[m, setdiff(names(e), "pid")])
  X / sqrt(rowSums(X^2))
}

# Cosine distance between rows of an L2-normalized matrix. (pmax(0, M) would drop
# M's dimensions, so negatives from rounding are clamped in place.)
cosine_dist <- function(X) {
  M <- 1 - tcrossprod(X)
  M[M < 0] <- 0
  diag(M) <- 0
  stats::as.dist(M)
}

# ---- T1-T3 (Section 7.4) ------------------------------------------------------------
# PERMANOVA on cosine distances with the three main effects, each tested
# marginally; a dispersion test beside each factor.
permanova_T <- function(X, meta, perms, seed) {
  D <- cosine_dist(X)
  set.seed(seed)
  ad <- vegan::adonis2(D ~ a + v + t, data = meta, permutations = perms, by = "margin")
  facs <- c(T1 = "a", T2 = "v", T3 = "t"); fnames <- c(a = "artist", v = "victim", t = "transform")
  do.call(rbind, lapply(names(facs), function(T) {
    f <- facs[[T]]
    set.seed(seed)
    bd <- vegan::betadisper(D, factor(meta[[fnames[[f]]]]))
    pt <- vegan::permutest(bd, permutations = 999)
    data.frame(test = T, term = f, factor = fnames[[f]], n = nrow(X),
               F = ad[f, "F"], R2 = ad[f, "R2"], p = ad[f, "Pr(>F)"],
               dispersion_F = pt$tab[1, "F"], dispersion_p = pt$tab[1, "Pr(>F)"], stringsAsFactors = FALSE)
  }))
}

permanova_interactions <- function(X, meta, perms, seed) {
  set.seed(seed)
  ad <- vegan::adonis2(cosine_dist(X) ~ a * v * t, data = meta, permutations = perms, by = "terms")
  r <- as.data.frame(ad); r$term <- rownames(ad)
  r[grepl(":", r$term), c("term", "F", "R2", "Pr(>F)")]
}

# ---- Firth logistic models for 0/1 text codes ---------------------------------------
firth_terms <- function(y, meta, study, covars = NULL, label = "") {
  rhs <- if (study == 2) "a * v * t" else "a * v"
  if (length(covars)) rhs <- paste(rhs, "+", paste(covars, collapse = " + "))
  dd <- data.frame(y = as.integer(y), meta)
  dd <- dd[stats::complete.cases(dd[, c("y", "a", "v", if (study == 2) "t", covars)]), ]
  terms <- TERMS[[as.character(study)]]
  if (length(unique(dd$y)) < 2) {
    return(data.frame(code = label, term = terms, n = nrow(dd), prevalence = mean(dd$y), estimate = NA,
                      ci_low = NA, ci_high = NA, p = NA, note = "no variation; not estimable", stringsAsFactors = FALSE))
  }
  f <- logistf::logistf(stats::as.formula(paste("y ~", rhs)), data = dd)
  i <- match(terms, names(f$coefficients))
  data.frame(code = label, term = terms, n = nrow(dd), prevalence = mean(dd$y),
             estimate = unname(f$coefficients[i]), ci_low = unname(f$ci.lower[i]), ci_high = unname(f$ci.upper[i]),
             p = unname(f$prob[i]), note = "Firth logistic; estimate = log-odds difference (codes as in config.R)",
             stringsAsFactors = FALSE)
}

# ---- Counts and proportions (Section 7.6) ------------------------------------------------
# Negative binomial with log(total words) offset; Poisson with HC0 errors if it
# fails (Section 9). Passive voice: quasi-binomial over finite-verb clauses.
count_model <- function(count, words, meta, study, label) {
  rhs <- if (study == 2) "a * v * t" else "a * v"
  dd <- data.frame(count = count, words = words, meta)
  dd <- dd[dd$words > 0, ]
  terms <- TERMS[[as.character(study)]]
  f <- tryCatch(MASS::glm.nb(stats::as.formula(paste("count ~", rhs, "+ offset(log(words))")), data = dd),
                error = function(e) NULL, warning = function(w) NULL)
  if (is.null(f)) {
    f <- stats::glm(stats::as.formula(paste("count ~", rhs, "+ offset(log(words))")), family = stats::poisson(), data = dd)
    V <- sandwich::vcovHC(f, type = "HC0"); method <- "Poisson, robust SE (fallback, Section 9)"
  } else { V <- stats::vcov(f); method <- "negative binomial, log(words) offset" }
  b <- stats::coef(f)[terms]; se <- sqrt(diag(V))[terms]
  data.frame(feature = label, term = terms, n = nrow(dd), estimate = b, se = se,
             p = 2 * stats::pnorm(-abs(b / se)), rate_ratio = exp(b), method = method, stringsAsFactors = FALSE)
}

passive_model <- function(passive, clauses, meta, study) {
  rhs <- if (study == 2) "a * v * t" else "a * v"
  dd <- data.frame(passive = passive, clauses = clauses, meta); dd <- dd[dd$clauses > 0, ]
  f <- stats::glm(stats::as.formula(paste("cbind(passive, clauses - passive) ~", rhs)),
                  family = stats::quasibinomial(), data = dd)
  terms <- TERMS[[as.character(study)]]
  cf <- summary(f)$coefficients[terms, , drop = FALSE]
  data.frame(feature = "passive_clauses", term = terms, n = nrow(dd), estimate = cf[, 1], se = cf[, 2],
             p = cf[, 4], rate_ratio = exp(cf[, 1]), method = "quasi-binomial over finite-verb clauses",
             stringsAsFactors = FALSE)
}

# ---- Ridge: do explanations carry the verdict? (Section 7.7) ----------------------------
ridge_r2 <- function(X, y, folds, seed) {
  set.seed(seed)
  fid <- sample(rep(seq_len(folds), length.out = length(y)))
  cv <- glmnet::cv.glmnet(X, y, alpha = 0, foldid = fid, keep = TRUE)
  pred <- cv$fit.preval[, match(cv$lambda.min, cv$lambda)]
  list(r2 = 1 - sum((y - pred)^2) / sum((y - mean(y))^2), pred = pred)
}

ridge_table <- function(X, y, folds, B, perms, seed, label) {
  ok <- !is.na(y); X <- X[ok, , drop = FALSE]; y <- y[ok]
  r <- ridge_r2(X, y, folds, seed)
  set.seed(seed)
  boot <- replicate(B, { i <- sample.int(length(y), replace = TRUE)
    1 - sum((y[i] - r$pred[i])^2) / sum((y[i] - mean(y[i]))^2) })
  null <- vapply(seq_len(perms), function(k) ridge_r2(X, sample(y), folds, seed + k)$r2, numeric(1))
  data.frame(label = label, n = length(y), r2_out_of_sample = r$r2,
             r2_ci_low = unname(stats::quantile(boot, 0.025)), r2_ci_high = unname(stats::quantile(boot, 0.975)),
             permuted_mean = mean(null), permuted_95th = unname(stats::quantile(null, 0.95)),
             p_permutation = (1 + sum(null >= r$r2)) / (1 + perms), permutations = perms, stringsAsFactors = FALSE)
}

# ---- Structural topic model (Section 7.6) ----------------------------------------------------
stm_prepare <- function(texts, meta, seed) {
  set.seed(seed)
  pr <- stm::textProcessor(texts, metadata = meta, customstopwords = "mask", verbose = FALSE)   # drop the mask token
  stm::prepDocuments(pr$documents, pr$vocab, pr$meta, lower.thresh = 2, verbose = FALSE)
}

stm_search_K <- function(texts, meta, Ks, seed) {
  out <- stm_prepare(texts, meta, seed)
  set.seed(seed)
  sk <- stm::searchK(out$documents, out$vocab, K = Ks, prevalence = ~ a + v + t + study,
                     data = out$meta, init.type = "Spectral", verbose = FALSE)
  r <- as.data.frame(lapply(sk$results, unlist))
  r[, c("K", "heldout", "semcoh", "exclus", "residual")]
}

stm_effects <- function(texts, meta, K, seed) {
  out <- stm_prepare(texts, meta, seed)
  set.seed(seed)
  fit <- stm::stm(out$documents, out$vocab, K = K, prevalence = ~ a + v + t + study,
                  data = out$meta, init.type = "Spectral", seed = seed, verbose = FALSE)
  # No left-hand side: estimateEffect then uses all K topics. (With a left-hand
  # side it reads as.character(formula)[2], which returns NA once logistf has
  # loaded formula.tools, whose as.character method returns a single string.)
  ee <- stm::estimateEffect(~ a + v + t + study, fit, metadata = out$meta, uncertainty = "Global")
  stopifnot(length(ee$topics) == K)
  s <- summary(ee)
  eff <- do.call(rbind, lapply(seq_len(K), function(k) {
    cf <- s$tables[[k]]
    data.frame(topic = k, term = rownames(cf), estimate = cf[, 1], se = cf[, 2], p = cf[, 4], stringsAsFactors = FALSE)
  }))
  lab <- stm::labelTopics(fit, n = 10)
  words <- data.frame(topic = seq_len(K), prob = apply(lab$prob, 1, paste, collapse = ", "),
                      frex = apply(lab$frex, 1, paste, collapse = ", "), stringsAsFactors = FALSE)
  list(effects = eff[eff$term != "(Intercept)", ], words = words, n_docs = length(out$documents))
}
