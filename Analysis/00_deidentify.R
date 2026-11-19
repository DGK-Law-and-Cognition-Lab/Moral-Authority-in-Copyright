# 00_deidentify.R
#
# Turns the raw Qualtrics numeric exports into the de-identified files posted in
# Data/. Run it from the repository root, on a machine that has the raw exports.
# The raw exports and the private ID key never enter this repository.
#
#   Rscript Analysis/00_deidentify.R <raw_dir> <private_dir> [<interim_file>]
#
#   <raw_dir>      folder holding Study 1/Study1_Values.csv and Study 2/Study2_Values.csv
#   <private_dir>  folder (outside the repository) for the ResponseId key and the
#                  free-text screening report
#   <interim_file> optional: the 2025 interim Study 2 analysis file (has a ResponseId
#                  column). Study 2 then gets a column in_2025_interim (1 = the
#                  response was in that file, 0 = never seen), used for the
#                  plan's unseen-subset checks.
#
# What it does, per study:
#   1. Reads the three Qualtrics header rows (export name, question text, ImportId).
#   2. Names columns by export name, made unique by ImportId where names repeat.
#      The two columns named "Status" become QualtricsStatus (response type) and
#      ArtistStatus (the item "How much status does Martinez have", QID38).
#   3. Drops direct and indirect identifiers: IP address, location, recipient
#      fields, external reference, SONA id, consent date, end and recorded
#      timestamps, distribution channel, user language.
#   4. Replaces StartDate with the date only, and ResponseId with a study-specific
#      participant id (S1_0001 ...). The ResponseId key goes to <private_dir>.
#   5. Top-codes Age at 30 ("30+") and drops columns that are empty for every
#      response (unused or never-displayed questions).
#   6. Flags free-text answers that may identify someone (e-mail, phone number,
#      URL, "my name", long digit strings) and writes a report to <private_dir>
#      for a person to read before anything is posted. It never prints the text.
#   7. Flags repeat responses (repeat_response; see flag_repeats below).
#   8. Writes Data/StudyN_deidentified.csv and Data/StudyN_codebook.csv.
#
# No exclusions, recoding of rating items, or analysis happen here. Those live in
# the analysis scripts, which read the de-identified files.

suppressPackageStartupMessages({
  library(readr)
})

args <- commandArgs(trailingOnly = TRUE)
if (!(length(args) %in% 2:3)) {
  stop("Usage: Rscript Analysis/00_deidentify.R <raw_dir> <private_dir> [<interim_file>]")
}
raw_dir     <- args[1]
private_dir <- args[2]
interim_ids <- if (length(args) == 3) {
  read_csv(args[3], col_types = cols(.default = "c"), progress = FALSE)$ResponseId
} else NULL
out_dir     <- "Data"
dir.create(private_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
if (startsWith(normalizePath(private_dir), normalizePath("."))) {
  stop("<private_dir> must be outside the repository.")
}

AGE_TOP_CODE <- 30

# ImportIds of columns that are removed outright.
DROP_IMPORT_IDS <- c(
  "endDate", "recordedDate", "ipAddress",
  "recipientLastName", "recipientFirstName", "recipientEmail",
  "externalDataReference", "locationLatitude", "locationLongitude",
  "distributionChannel", "userLanguage",
  "id",                   # SONA participant id
  "QID1720292888_TEXT"    # consent date typed by the participant
)

FREE_TEXT <- c("Explain_Ruling", "ProcedureUnclear", "SharingAnything", "NativeLanguage")

# Debrief comment boxes. The analysis plan does not use them, and they are where
# participants volunteer personal details (one typed a student ID), so they are
# screened and then left out of the public files.
DROP_FREE_TEXT <- c("ProcedureUnclear", "SharingAnything")

# Replaced with "[REDACTED]" in the free text that is kept.
REDACT_PATTERNS <- c(
  "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
  "https?://\\S+|www\\.\\S+",
  "\\(?\\b[0-9]{3}\\)?[-. ]?[0-9]{3}[-. ]?[0-9]{4}\\b",
  "[0-9]{6,}"
)

FLAG_PATTERNS <- c(
  email  = "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
  phone  = "\\(?\\b[0-9]{3}\\)?[-. ]?[0-9]{3}[-. ]?[0-9]{4}\\b",
  url    = "https?://|www\\.",
  myname = "\\bmy name\\b|\\bi am called\\b|\\bmy (e-?mail|number|phone)\\b",
  digits = "[0-9]{6,}",
  sona   = "\\bsona\\b|\\bstudent id\\b|\\bbruin ?id\\b|\\buid\\b"
)

read_qualtrics <- function(path) {
  hdr <- read_csv(path, col_names = FALSE, n_max = 3, col_types = cols(.default = "c"),
                  progress = FALSE)
  dat <- read_csv(path, col_names = FALSE, skip = 3, col_types = cols(.default = "c"),
                  na = character(), progress = FALSE)
  names_raw <- unlist(hdr[1, ], use.names = FALSE)
  text      <- unlist(hdr[2, ], use.names = FALSE)
  import_id <- sub('^\\{"ImportId":"([^"]+)".*$', "\\1", unlist(hdr[3, ], use.names = FALSE))
  list(dat = as.data.frame(dat), names = names_raw, text = text, import_id = import_id)
}

make_names <- function(nm, import_id) {
  out <- nm
  out[nm == "Status" & import_id == "status"] <- "QualtricsStatus"
  out[nm == "Status" & import_id == "QID38"]  <- "ArtistStatus"
  dup <- duplicated(out) | duplicated(out, fromLast = TRUE)
  out[dup] <- paste0(out[dup], "__", import_id[dup])
  out
}

# Marks every response that is not a person's first exposure to a vignette.
# A response is a repeat if (a) its SONA id already appeared on an earlier
# response that reached a vignette, or (b) it has no SONA id and an earlier
# response from the same IP address reached a vignette within the previous
# 3 hours. In Study 2, no two different SONA ids ever started within 3 hours
# of each other on the same IP, so (b) identifies the same person.
# Computed here because the SONA id and IP address are removed below.
flag_repeats <- function(d, window_hours = 3) {
  tt <- as.numeric(as.POSIXct(d$StartDate, tz = "UTC"))
  rep_flag <- integer(nrow(d))
  seen_id <- character()
  ip_times <- list()
  for (i in order(tt)) {
    if (trimws(d$Type[i]) == "") next          # never reached a vignette
    sid <- trimws(d$id[i])
    ip <- d$IPAddress[i]
    prior <- ip_times[[ip]]
    if (sid != "") {
      if (sid %in% seen_id) rep_flag[i] <- 1L
      seen_id <- c(seen_id, sid)
    } else if (!is.null(prior) && any((tt[i] - prior) / 3600 <= window_hours)) {
      rep_flag[i] <- 1L
    }
    ip_times[[ip]] <- c(prior, tt[i])
  }
  rep_flag
}

deidentify <- function(study) {
  path <- file.path(raw_dir, sprintf("Study %d", study), sprintf("Study%d_Values.csv", study))
  q <- read_qualtrics(path)
  d <- q$dat
  names(d) <- make_names(q$names, q$import_id)
  repeat_flag <- flag_repeats(d)
  meta <- data.frame(column = names(d), export_name = q$names, import_id = q$import_id,
                     question_text = gsub("\\s+", " ", q$text), stringsAsFactors = FALSE)

  # 3. identifiers
  keep <- !(meta$import_id %in% DROP_IMPORT_IDS)
  # 5. columns empty for every response
  empty <- vapply(d, function(x) all(trimws(x) == ""), logical(1))
  dropped_empty <- names(d)[empty & keep]
  keep <- keep & !empty
  d <- d[, keep, drop = FALSE]
  meta <- meta[keep, ]

  # 4. dates and ids
  d$StartDate <- substr(d$StartDate, 1, 10)
  pid <- sprintf("S%d_%04d", study, seq_len(nrow(d)))
  key <- data.frame(pid = pid, ResponseId = d$ResponseId)
  write_csv(key, file.path(private_dir, sprintf("Study%d_id_key.csv", study)))
  interim_flag <- NULL
  if (study == 2 && !is.null(interim_ids)) {
    interim_flag <- as.integer(d$ResponseId %in% interim_ids)
  }
  d$ResponseId <- NULL
  d <- cbind(pid = pid, d)
  d$repeat_response <- repeat_flag
  meta <- rbind(meta, data.frame(column = "repeat_response", export_name = "", import_id = "",
    question_text = "1 = not this person's first exposure to a vignette (same SONA id earlier, or no SONA id and same IP within 3 hours); 0 = first exposure"))
  if (!is.null(interim_flag)) {
    d$in_2025_interim <- interim_flag
    meta <- rbind(meta, data.frame(column = "in_2025_interim", export_name = "", import_id = "",
      question_text = "1 = response was in the 2025 interim analysis file; 0 = never seen"))
  }
  meta <- rbind(data.frame(column = "pid", export_name = "", import_id = "",
                           question_text = "Participant id assigned at de-identification"),
                meta[meta$column != "ResponseId", ])

  # 5. age
  if ("Age" %in% names(d)) {
    a <- suppressWarnings(as.integer(gsub("[^0-9]", "", d$Age)))
    d$Age <- ifelse(is.na(a), "", ifelse(a >= AGE_TOP_CODE, paste0(AGE_TOP_CODE, "+"), as.character(a)))
  }

  # 6. free-text screen (report goes to private_dir; text is not printed)
  flags <- list()
  for (col in intersect(FREE_TEXT, names(d))) {
    for (p in names(FLAG_PATTERNS)) {
      hit <- grepl(FLAG_PATTERNS[[p]], d[[col]], ignore.case = TRUE, perl = TRUE)
      if (any(hit)) flags[[length(flags) + 1]] <-
        data.frame(pid = d$pid[hit], column = col, pattern = p, text = d[[col]][hit])
    }
  }
  flags <- if (length(flags)) do.call(rbind, flags) else
    data.frame(pid = character(), column = character(), pattern = character(), text = character())
  write_csv(flags, file.path(private_dir, sprintf("Study%d_free_text_flags.csv", study)))

  # 6b. drop debrief comment boxes; redact contact details and long numbers elsewhere
  d <- d[, !(names(d) %in% DROP_FREE_TEXT), drop = FALSE]
  meta <- meta[!(meta$column %in% DROP_FREE_TEXT), ]
  n_redacted <- 0L
  for (col in intersect(FREE_TEXT, names(d))) {
    for (p in REDACT_PATTERNS) {
      hit <- grepl(p, d[[col]], perl = TRUE)
      n_redacted <- n_redacted + sum(hit)
      d[[col]] <- gsub(p, "[REDACTED]", d[[col]], perl = TRUE)
    }
  }

  write_csv(d, file.path(out_dir, sprintf("Study%d_deidentified.csv", study)), na = "")
  write_csv(meta, file.path(out_dir, sprintf("Study%d_codebook.csv", study)), na = "")

  cat(sprintf("Study %d: %d rows, %d columns written; %d identifier columns, %d empty columns and %d comment boxes dropped; %d free-text flags for review; %d redactions in kept text.\n",
              study, nrow(d), ncol(d), sum(q$import_id %in% DROP_IMPORT_IDS), length(dropped_empty),
              length(DROP_FREE_TEXT), nrow(flags), n_redacted))
  if (length(dropped_empty)) cat("  empty columns dropped:", paste(dropped_empty, collapse = ", "), "\n")
}

for (s in 1:2) deidentify(s)
