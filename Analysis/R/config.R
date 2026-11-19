# config.R
# Every constant fixed by the registered analysis plan (Docs/Preregistration/
# Analysis_Plan_v1.1_registered.md) lives here, with the plan section it comes
# from. Nothing in the analysis code should hard-code these values elsewhere.

SEED <- 2025                                   # Section 6, Software

# ---- Items and scoring (Section 5, Scoring) --------------------------------
# Higher scores always mean less favorable to Martinez. Four items are
# reversed: scored = k - raw. Raw ranges were checked against the Labeled
# exports (code -> label) for both studies.
REVERSED <- c(AllowedReason = 6, Jury = 6, CostReason = 6, ReduceMarket = 7)
RAW_RANGE <- list(
  AllowedReason = 1:5, Jury = 1:5, CostReason = 1:5, ReduceMarket = 1:6,
  MorallyWrong = 1:5, Unfairness = 1:5, RightsViolation = 1:5, VictimRivera = 1:5,
  ObjectKnowledge = 1:5, Punishment = 1:5, Payment = 1:5,
  FinancialHarm = 1:5, ReputationHarm = 1:5, EmotionalDistress = 1:5, OverallHarm = 1:5,
  ArtistStatus = 1:5, PowertoStop = 1:5, Resources = 1:5
)
RATING_ITEMS <- c("AllowedReason", "Jury", "CostReason", "ReduceMarket",
                  "MorallyWrong", "VictimRivera", "ObjectKnowledge", "Unfairness",
                  "RightsViolation", "Punishment", "Payment",
                  "FinancialHarm", "ReputationHarm", "EmotionalDistress", "OverallHarm")
PERCEPTION_ITEMS <- c("ArtistStatus", "PowertoStop", "Resources")   # Section 6, Items asked after the outcomes

# Composites (Section 5, Composites): always these four-item means; alpha is descriptive.
MORAL_ITEMS <- c("MorallyWrong", "Unfairness", "RightsViolation", "VictimRivera")
HARM_ITEMS  <- c("FinancialHarm", "ReputationHarm", "EmotionalDistress", "OverallHarm")

# Outcomes (Section 5, Outcomes)
PRIMARY   <- c("AllowedReason", "Moral", "Harm", "Payment")
SECONDARY <- setdiff(RATING_ITEMS, c("AllowedReason", "Payment"))
SINGLE_ITEM_OUTCOMES <- RATING_ITEMS          # composites have no ordinal model
OUTCOME_RANGE <- c(lapply(RAW_RANGE[RATING_ITEMS], function(r) range(r)),
                   list(Moral = c(1, 5), Harm = c(1, 5)))

# ArtTraining is exported as 1, 4, 5, 6, 7 and recoded to 1-5 (Section 5).
ART_TRAINING_RECODE <- c(`1` = 1, `4` = 2, `5` = 3, `6` = 4, `7` = 5)

# ---- Conditions ---------------------------------------------------------------
# Embedded field Type = "<artist>_<photographer>", verified against the survey
# flow (block-randomizer group -> Type value -> vignette block).
CELLS <- c("Famous_Famous", "Famous_LessFamous", "LessFamous_Famous", "LessFamous_LessFamous")
# The vignette page whose timer belongs to each cell (condition-consistency check, Section 5).
CELL_TIMER <- c(Famous_Famous         = "TimeFamousFamous_Page Submit",
                Famous_LessFamous     = "TimingFamousLessFam_Page Submit",
                LessFamous_Famous     = "TimingLessFamFamous_Page Submit",
                LessFamous_LessFamous = "TimingLessFamLessFam_Page Submit")
# Study 2 transformation text, first words of each version (survey flow).
TRANSFORM_TEXT_START <- c(High = "In the new artwork, Martinez used a portion",
                          Low  = "In the new artwork, Martinez used Rivera's complete")

# Numeric effect codes (+/- 0.5). With these codes each coefficient of the
# full-factorial model is the difference between unweighted marginal means
# (main effects) or a difference of differences (2-way interactions); the
# Wald test of each coefficient is the Type III test. The sign conventions
# are chosen so that the registered predictions read naturally:
#   a = artist fame:      +0.5 famous,  -0.5 unknown   (estimate = famous - unknown)
#   v = victim fame:      +0.5 unknown, -0.5 famous    (estimate = unknown - famous; C2, C3 predict > 0)
#   t = transformation:   +0.5 high,    -0.5 low       (estimate = high - low; C1 predicts < 0)
TERM_LABELS <- c(a = "Artist fame (famous - unknown)",
                 v = "Victim fame (unknown - famous)",
                 t = "Transformation (high - low)",
                 `a:v` = "Artist x Victim",
                 `a:t` = "Artist x Transformation",
                 `v:t` = "Victim x Transformation",
                 `a:v:t` = "Artist x Victim x Transformation")
TERMS <- list(`1` = c("a", "v", "a:v"),
              `2` = c("a", "v", "t", "a:v", "a:t", "v:t", "a:v:t"))

# ---- Confirmatory tests (Section 6) -------------------------------------------
CONFIRMATORY <- data.frame(
  test      = c("C1", "C2", "C3", "C4", "C5"),
  outcome   = c("AllowedReason", "Harm", "Payment", "AllowedReason", "AllowedReason"),
  term      = c("t", "v", "v", "a", "a:t"),
  predicted = c(-1, 1, 1, NA, NA),          # sign of the estimate; NA = two-sided
  stringsAsFactors = FALSE
)
EQUIV_BOUND <- 0.25                          # C4, raw scale points
ALPHA <- 0.05
