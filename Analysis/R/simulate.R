# simulate.R
# Synthetic data with the same columns and codes as the de-identified files, used
# to test the analysis code before it touches the real data (Section 6). Nothing
# here reads a real response: column names come from the codebooks, and every
# value is generated. Known effects are planted so the tests can check that the
# code recovers them with the right sign.
# Requires config.R.

# Planted effects on the scored scale, in latent-SD units (see sim_item()).
SIM_EFFECTS <- list(
  AllowedReason = c(t = -0.8, a = 0, `a:t` = -0.4),
  Jury = c(t = -0.6), CostReason = c(t = -0.2), ReduceMarket = c(t = -0.3),
  MorallyWrong = c(v = 0.2, t = -0.4), Unfairness = c(v = 0.2, t = -0.4),
  RightsViolation = c(v = 0.2, t = -0.5), VictimRivera = c(v = 0.3, t = -0.3),
  ObjectKnowledge = c(), Punishment = c(t = -0.3), Payment = c(v = 0.35, t = -0.4),
  FinancialHarm = c(v = 0.35), ReputationHarm = c(v = 0.35, `a:v` = 0.2),
  EmotionalDistress = c(v = 0.35), OverallHarm = c(v = 0.35, t = -0.3)
)
# Baseline (latent mean) per item: AllowedReason sits near the restrictive end, as described in Section 4.
SIM_BASE <- c(AllowedReason = 0.9, Jury = 0.9, CostReason = 0.2, ReduceMarket = 0.1,
              MorallyWrong = 0.3, Unfairness = 0.4, RightsViolation = 0.5, VictimRivera = 0.4,
              ObjectKnowledge = 0.8, Punishment = -0.3, Payment = 0.6,
              FinancialHarm = -0.2, ReputationHarm = -0.5, EmotionalDistress = 0, OverallHarm = 0)

codebook_columns <- function(study, root) {
  cb <- read.csv(file.path(root, "Data", sprintf("Study%d_codebook.csv", study)),
                 stringsAsFactors = FALSE, check.names = FALSE)
  cb$column
}

# Ordinal item from a latent normal: scored categories 1..k, then converted to
# the raw export direction (reversed items: raw = k + 1 - scored).
sim_item <- function(item, a, v, t, trait, k) {
  e <- SIM_EFFECTS[[item]]; e <- if (is.null(e)) numeric(0) else e
  get <- function(nm) if (nm %in% names(e)) e[[nm]] else 0
  t0 <- ifelse(is.na(t), 0, t)
  # Codes are +/- 0.5, so a planted difference D between levels enters as D * a
  # (main effect) and a planted difference of differences D enters as D * a * t.
  lat <- SIM_BASE[[item]] + get("a") * a + get("v") * v + get("t") * t0 +
    get("a:t") * a * t0 + get("a:v") * a * v +
    0.6 * trait + stats::rnorm(length(a), 0, 0.8)   # latent SD = 1
  cuts <- stats::qnorm(seq_len(k - 1) / k)
  scored <- findInterval(lat, cuts) + 1
  if (item %in% names(REVERSED)) REVERSED[[item]] - scored else scored
}

simulate_study <- function(study, n, seed, root) {
  set.seed(seed)
  cols <- codebook_columns(study, root)
  d <- as.data.frame(matrix(NA_character_, nrow = n, ncol = length(cols),
                            dimnames = list(NULL, cols)), stringsAsFactors = FALSE)
  d$pid <- sprintf("SIM%d_%04d", study, seq_len(n))
  start <- as.Date(if (study == 1) "2025-10-17" else "2025-11-05")
  span <- if (study == 1) 35 else 14
  days <- sort(sample(0:span, n, replace = TRUE))
  d$StartDate <- as.character(start + days)
  d$QualtricsStatus <- "0"
  assigned <- stats::runif(n) > (if (study == 1) 0.03 else 0.15)
  d$Type <- ifelse(assigned, sample(CELLS, n, replace = TRUE), NA)
  if (study == 2) {
    tc <- ifelse(assigned, sample(c("High", "Low"), n, replace = TRUE), NA)
    d$TransformCondition <- tc
    d$TransformText <- ifelse(is.na(tc), NA,
      ifelse(tc == "High",
             "In the new artwork, Martinez used a portion of Rivera's photograph as one element in a larger work.",
             "In the new artwork, Martinez used Rivera's complete photograph with only minor brightness adjustments."))
  }
  for (cl in CELLS) {
    k <- assigned & d$Type == cl
    k[is.na(k)] <- FALSE
    stem <- sub(" Page Submit$", "", sub("_Page Submit$", "", CELL_TIMER[[cl]]))
    d[k, paste0(stem, "_First Click")] <- sprintf("%.3f", stats::runif(sum(k), 1, 5))
    d[k, paste0(stem, "_Last Click")]  <- sprintf("%.3f", stats::runif(sum(k), 20, 60))
    d[k, CELL_TIMER[[cl]]]             <- sprintf("%.3f", stats::runif(sum(k), 25, 90))
    d[k, paste0(stem, "_Click Count")] <- as.character(sample(0:6, sum(k), replace = TRUE))
  }
  finished <- assigned & stats::runif(n) < 0.92
  d$Finished <- ifelse(finished, "1", "0")
  d$Progress <- ifelse(finished, "100", as.character(sample(5:95, n, replace = TRUE)))
  d$`Duration (in seconds)` <- as.character(round(stats::rlnorm(n, log(480), 0.4)))
  d$Consent <- "1"; d$AttentionCheck1 <- "1"
  d$WhoNewCheck <- ifelse(assigned, ifelse(stats::runif(n) < 0.95, "1", "2"), NA)
  d$ReasonWhyCheck <- ifelse(assigned, ifelse(stats::runif(n) < 0.95, "2", "3"), NA)
  a <- ifelse(grepl("^Famous_", d$Type), 0.5, -0.5)
  v <- ifelse(grepl("_LessFamous$", d$Type), 0.5, -0.5)
  t <- if (study == 2) ifelse(d$TransformCondition == "High", 0.5, -0.5) else rep(NA_real_, n)
  if (study == 2) {
    correct <- ifelse(t > 0, "1", "2"); wrong <- ifelse(t > 0, "2", "1")
    d$WorkTransform <- ifelse(assigned, ifelse(stats::runif(n) < 0.97, correct, wrong), NA)
  }
  trait <- stats::rnorm(n)
  for (it in RATING_ITEMS) {
    k <- max(RAW_RANGE[[it]])
    d[[it]] <- ifelse(finished, as.character(sim_item(it, a, v, t, trait, k)), NA)
  }
  d$ArtistStatus <- ifelse(finished, as.character(pmin(5, pmax(1, round(3 + 1.2 * a + stats::rnorm(n, 0, 0.9))))), NA)
  d$PowertoStop  <- ifelse(finished, as.character(pmin(5, pmax(1, round(2.5 - 0.8 * v + stats::rnorm(n, 0, 0.9))))), NA)
  d$Resources    <- ifelse(finished, as.character(pmin(5, pmax(1, round(3 + 0.6 * a + 0.6 * v + stats::rnorm(n, 0, 0.9))))), NA)
  d$Seriousness  <- ifelse(finished, ifelse(stats::runif(n) < 0.94, "4", "1"), NA)
  d$Age <- ifelse(finished, sample(c(as.character(18:29), "30+"), n, replace = TRUE,
                                   prob = c(10, 20, 22, 22, 10, 5, 3, 2, 2, 1, 1, 1, 1)), NA)
  d$Gender <- ifelse(finished, sample(c("1", "2", "3", "4"), n, replace = TRUE, prob = c(20, 76, 2, 2)), NA)
  d$Race <- ifelse(finished, sample(c("1", "2", "4", "6", "7", "1,4"), n, replace = TRUE), NA)
  d$NativeLanguage <- ifelse(finished, sample(c("English", "english", "Spanish", "Mandarin", "Korean"), n,
                                              replace = TRUE, prob = c(60, 15, 10, 10, 5)), NA)
  d$ArtTraining <- ifelse(finished, sample(c("1", "4", "5", "6", "7"), n, replace = TRUE, prob = c(45, 28, 18, 6, 3)), NA)
  d$CopyrightFamiliar <- ifelse(finished, sample(as.character(1:(if (study == 2) 5 else 4)), n, replace = TRUE), NA)
  d$repeat_response <- if (study == 2) ifelse(assigned & stats::runif(n) < 0.2, "1", "0") else "0"
  d$repeat_response[!assigned] <- "0"
  if (study == 2) d$in_2025_interim <- ifelse(days <= 4 & stats::runif(n) < 0.6, "1", "0")
  d$Explain_Ruling <- ifelse(finished, sim_explanation(a, v, t, as.numeric(d$Jury), study), NA)
  d[, cols]
}

# Synthetic explanations. Phrases depend on condition and verdict so the text
# pipeline has something to find; ~5% are under three words.
sim_explanation <- function(a, v, t, jury_raw, study) {
  n <- length(a)
  pick <- function(x) x[sample.int(length(x), 1)]
  vapply(seq_len(n), function(i) {
    if (stats::runif(1) < 0.05) return(pick(c("no", "ok", "not fair")))
    favors_rivera <- !is.na(jury_raw[i]) && jury_raw[i] <= 2
    s <- c(if (favors_rivera) pick(c("Martinez did not ask Rivera for permission.",
                                     "Rivera owns the photograph and should have been asked.",
                                     "Using someone's work without consent is wrong."))
           else pick(c("The new work is transformative enough to count as fair use.",
                       "Martinez added enough of his own creativity.",
                       "Art builds on other art all the time.")))
    if (study == 2 && !is.na(t[i]) && stats::runif(1) < 0.6)
      s <- c(s, if (t[i] > 0) pick(c("He changed the image a lot and combined it with other images.",
                                     "The final piece looks very different from the original."))
                else pick(c("It is basically a copy with a signature.",
                            "The work looks nearly identical to the photograph.")))
    if (v[i] > 0 && stats::runif(1) < 0.4) s <- c(s, pick(c("Rivera is a small artist and could lose income.",
                                                            "An unknown photographer is hurt more by this.")))
    if (a[i] > 0 && stats::runif(1) < 0.3) s <- c(s, "Martinez is famous and should know better.")
    if (stats::runif(1) < 0.5) s <- c(s, pick(c("He should pay Rivera.", "He should give credit.",
                                                "They should share the profits.")))
    paste(s, collapse = " ")
  }, character(1))
}
