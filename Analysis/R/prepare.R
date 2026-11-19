# prepare.R
# Loading, inclusion, and scoring. Implements Section 5 of the registered plan.
# Requires config.R to be sourced first.

suppressPackageStartupMessages({
  library(readr)
})

# ---- Loading ------------------------------------------------------------------
# mode = "real"      reads the de-identified files in Data/
# mode = "simulated" reads the synthetic files in Analysis/simulated/
data_path <- function(study, mode, root) {
  stopifnot(study %in% 1:2, mode %in% c("real", "simulated"))
  if (mode == "real") file.path(root, "Data", sprintf("Study%d_deidentified.csv", study))
  else file.path(root, "Analysis", "simulated", sprintf("Study%d_simulated.csv", study))
}

load_study <- function(study, mode, root) {
  path <- data_path(study, mode, root)
  if (!file.exists(path)) stop("Missing data file: ", path)
  d <- read_csv(path, col_types = cols(.default = col_character()), na = c("", "NA"),
                name_repair = "minimal", progress = FALSE)
  d <- as.data.frame(d, stringsAsFactors = FALSE, check.names = FALSE)
  num <- c("Finished", "WhoNewCheck", "ReasonWhyCheck", "Seriousness", "repeat_response",
           RATING_ITEMS, PERCEPTION_ITEMS, "ArtTraining", "CopyrightFamiliar", "Gender",
           unname(CELL_TIMER),
           if (study == 2) c("WorkTransform", "in_2025_interim"))
  missing_cols <- setdiff(c(num, "pid", "Type", "Explain_Ruling", if (study == 2) c("TransformCondition", "TransformText")),
                          names(d))
  if (length(missing_cols)) stop("Study ", study, ": columns missing: ", paste(missing_cols, collapse = ", "))
  for (v in num) {
    x <- suppressWarnings(as.numeric(d[[v]]))
    bad <- !is.na(d[[v]]) & is.na(x)
    if (any(bad)) stop("Study ", study, ", column ", v, ": non-numeric values present")
    d[[v]] <- x
  }
  d$study <- study
  d
}

# ---- Inclusion (Section 5, "Who is included") ---------------------------------
# Returns d with one logical column per step and `included`.
flag_inclusion <- function(d, study) {
  d$assigned <- !is.na(d$Type) & d$Type %in% CELLS
  if (study == 2) d$assigned <- d$assigned & d$TransformCondition %in% c("High", "Low")
  d$finished <- d$assigned & !is.na(d$Finished) & d$Finished == 1
  d$passed   <- d$finished & !is.na(d$WhoNewCheck) & d$WhoNewCheck == 1 &
                !is.na(d$ReasonWhyCheck) & d$ReasonWhyCheck == 2
  d$first    <- d$passed & !is.na(d$repeat_response) & d$repeat_response == 0
  # "did not answer No": a missing seriousness answer is not an exclusion.
  d$serious  <- d$first & (is.na(d$Seriousness) | d$Seriousness != 1)
  d$consistent <- condition_consistent(d, study)
  d$included <- d$serious & d$consistent
  d
}

# The condition fields must agree with which vignette page has timing data:
# the timer of the participant's own cell is filled and no other cell's timer is.
# In Study 2, TransformCondition must be High or Low and TransformText must be
# the matching text.
condition_consistent <- function(d, study) {
  timers <- sapply(CELL_TIMER, function(col) !is.na(d[[col]]))
  if (is.null(dim(timers))) timers <- matrix(timers, nrow = 1, dimnames = list(NULL, names(CELL_TIMER)))
  own <- ifelse(d$Type %in% CELLS,
                timers[cbind(seq_len(nrow(d)), match(d$Type, colnames(timers)))], FALSE)
  n_filled <- rowSums(timers)
  ok <- own & n_filled == 1
  if (study == 2) {
    tc_ok <- d$TransformCondition %in% names(TRANSFORM_TEXT_START)
    txt_ok <- tc_ok & mapply(function(cond, txt) {
      !is.na(txt) && startsWith(txt, TRANSFORM_TEXT_START[[cond]])
    }, ifelse(tc_ok, d$TransformCondition, "High"), d$TransformText)
    ok <- ok & tc_ok & txt_ok
  }
  ok[is.na(ok)] <- FALSE
  ok
}

# Counts at each inclusion step, overall and per cell (Section 5 table; Section 6, Attrition).
inclusion_counts <- function(d, study) {
  steps <- c("assigned", "finished", "passed", "first", "serious", "included")
  cell <- if (study == 2) paste(d$Type, d$TransformCondition, sep = "/") else d$Type
  out <- do.call(rbind, lapply(sort(unique(cell[d$assigned])), function(cl) {
    k <- d$assigned & cell == cl
    data.frame(study = study, cell = cl, t(sapply(steps, function(s) sum(d[[s]][k]))),
               check.names = FALSE)
  }))
  rbind(out, data.frame(study = study, cell = "TOTAL",
                        t(sapply(steps, function(s) sum(d[[s]]))), check.names = FALSE))
}

# ---- Scoring (Section 5, Scoring and Composites) -----------------------------
score <- function(d, study) {
  for (v in names(RAW_RANGE)) {
    x <- d[[v]][d$finished]          # every finished response is checked (some checks use non-included rows)
    bad <- !is.na(x) & !(x %in% RAW_RANGE[[v]])
    if (any(bad)) stop("Study ", study, ", ", v, ": values outside ", paste(range(RAW_RANGE[[v]]), collapse = "-"))
  }
  for (v in names(REVERSED)) {
    d[[paste0(v, "_raw")]] <- d[[v]]
    d[[v]] <- REVERSED[[v]] - d[[v]]
  }
  d$Moral <- rowMeans(d[, MORAL_ITEMS])     # NA if any item is missing (none expected: forced response)
  d$Harm  <- rowMeans(d[, HARM_ITEMS])
  at <- as.character(d$ArtTraining)
  if (any(!is.na(at) & !(at %in% names(ART_TRAINING_RECODE)))) stop("ArtTraining: unexpected code")
  d$ArtTraining5 <- unname(ART_TRAINING_RECODE[at])
  d
}

# Effect codes (see config.R). Only meaningful for assigned rows.
add_codes <- function(d, study) {
  artist <- sub("_.*$", "", d$Type)
  victim <- sub("^.*_", "", d$Type)
  d$a <- ifelse(artist == "Famous", 0.5, ifelse(artist == "LessFamous", -0.5, NA))
  d$v <- ifelse(victim == "LessFamous", 0.5, ifelse(victim == "Famous", -0.5, NA))
  d$artist <- factor(ifelse(d$a > 0, "famous", "unknown"), levels = c("famous", "unknown"))
  d$victim <- factor(ifelse(d$v > 0, "unknown", "famous"), levels = c("famous", "unknown"))
  if (study == 2) {
    d$t <- ifelse(d$TransformCondition == "High", 0.5, ifelse(d$TransformCondition == "Low", -0.5, NA))
    d$transform <- factor(ifelse(d$t > 0, "high", "low"), levels = c("high", "low"))
    # WorkTransform is correct when it says "different" (1) under High and "not different" (2) under Low.
    d$worktransform_correct <- ifelse(is.na(d$WorkTransform) | is.na(d$t), NA,
                                      (d$t > 0 & d$WorkTransform == 1) | (d$t < 0 & d$WorkTransform == 2))
  } else {
    d$t <- NA_real_
  }
  d$cell <- if (study == 2) paste(d$artist, d$victim, d$transform, sep = "/") else paste(d$artist, d$victim, sep = "/")
  d
}

# One call: load, flag, score, code.
prepare_study <- function(study, mode, root) {
  d <- load_study(study, mode, root)
  d <- flag_inclusion(d, study)
  d <- add_codes(d, study)
  d <- score(d, study)
  d
}

# The analysis sample: included rows only.
analysis_sample <- function(d) d[d$included, , drop = FALSE]
