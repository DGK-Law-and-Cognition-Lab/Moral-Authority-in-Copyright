# Analysis Plan: Fame, Transformation, and Lay Judgments of Fair Use

## 1. Purpose

We ran two vignette experiments on how people judge an unlicensed use of a photograph by another artist. Interim analyses in 2025 used partial samples and miscoded several rating scales, so none of those numbers can be reported. This plan fixes, before analysis of the complete data, which participants count, how each item is scored, which outcomes are primary, which tests are confirmatory, and which models we fit.

Study 1 has already been analyzed almost in full, and 103 Study 2 responses were analyzed in 2025 (Section 4). Only Study 2 can test anything, so the confirmatory tests use Study 2. Study 1 is reported as the study where the patterns first appeared.

## 2. Research questions

Courts treat fair use as a question about the work: how much it transforms the original and whether it harms the original's market. We ask whether people also weigh who the parties are.

- **RQ1. Artist fame.** Does the fame of the artist who borrows change whether people think the use should be legally allowed, and how wrong it seems?
- **RQ2. Victim fame.** Does the fame of the original photographer change how harmed people think the photographer is, and what remedy they think is owed?
- **RQ3. Transformation** (Study 2). Does changing the original more make the use seem more acceptable? Does the artist's fame change how much credit transformation gets?
- **RQ4. Explanations.** Do the manipulations change what reasons people give, and how do those reasons relate to the ratings?

**Direction.** We predict a direction only where there is a basis for one:

- *Transformation.* High transformation makes the use seem more acceptable; that is what the manipulation is for.
- *Victim fame.* An unknown photographer is seen as more harmed and owed more payment. This is the Study 1 pattern, so Study 2 tests it.
- *Artist fame.* We make no directional prediction. We test both for a difference and for equivalence.
- *Interactions.* All are two-sided.

## 3. The studies

**Scenario (both studies).** Loosely modeled on *Andy Warhol Foundation v. Goldsmith* (2023). Visual artist Alex Martinez makes a new artwork from a landscape photograph by photographer Jamie Rivera, sells prints for $500, and neither asks permission nor pays. When Rivera objects, Martinez says the work is different enough to count as fair use.

**Study 1.** 2 (Artist Fame: famous vs. relatively unknown) × 2 (Victim Fame: famous vs. relatively unknown), between subjects. Martinez "changed the colors of Rivera's photograph and added text over it." Famous parties are "world-renowned," shown in "major international museums," with a "large following." Less famous parties are "relatively unknown," in "small local galleries," with a "small following." Qualtrics survey, 17 October to 21 November 2025, 276 recorded responses.

**Study 2.** The same 2 × 2 crossed with Transformation (High vs. Low), for eight cells.

- *High:* Martinez used part of the photograph as one element among 15 images, added painting and digital changes, and changed colors and composition; "the final work looked very different."
- *Low:* Martinez used the whole photograph with minor brightness changes and a small signature; "the final work looked nearly identical."

Qualtrics survey, 5 to 19 November 2025, 599 recorded responses.

**Participants.** A university psychology subject pool (SONA), for course credit, under an approved consent protocol. These are undergraduates, mostly aged 18 to 21. They are not a sample of jury-eligible adults.

**Procedure.**

1. Consent, instructions, and an attention check. A wrong answer loops back to the instructions.
2. The vignette, assigned by Qualtrics' even randomizer.
3. Comprehension checks: who created the new artwork, and what reason Martinez gave. Study 2 adds "Was the new work highly different from the original?" A wrong answer on any of them sends the participant back to reread the vignette once, and the final answers are stored.
4. Four legal ratings and a written explanation, then seven moral ratings, then four harm ratings.
5. Three questions on the parties' status, power, and resources.
6. The seriousness question, demographics, and a debrief.

Every page records timing. Both surveys had per-cell quotas set to end the survey when full: 70 per cell in Study 1 and 40 in Study 2. They did not limit enrollment; every Study 2 cell has more than 40 included responses.

**Irregularities.**

- (a) **Study 1 questions moved to the Trash.** About 20 October 2025, after 65 Study 1 responses, the end-of-survey questions (status, power, resources, seriousness, demographics) were moved to the Qualtrics Trash in the survey editor. A replacement block with copies of the seriousness and demographic items was added to the editor's flow. The live survey kept showing the original questions. In the data, every included participant answered the original questions, and the replacement copies (exported as Q1–Q12) are empty for every response. We restored the originals on 10 November 2026 and re-exported. For the first 65 responses, the restored answers match an export saved on 20 October 2025 in all 780 cells. Analyses use the original items, selected by Qualtrics question ID (Appendix A).
- (b) **Repeat responses in Study 2.** Nothing in the survey stopped people from taking it more than once; Qualtrics' duplicate-response prevention was off. Some participants did take it more than once:
  - 22 SONA IDs have more than one complete response, almost always in a different condition each time.
  - A further 115 complete responses carry no SONA ID. All were started between 5 and 10 November 2025. Most come in back-to-back runs from a single IP address, starting within about two hours after a response that does carry an ID, and cycling through the conditions.
  - In Study 2, no two different SONA IDs ever started within three hours of each other on the same IP address. Such runs are therefore treated as the same person.
  - Their demographic answers agree. 100 of the 109 flagged responses without a SONA ID match the earlier response from the same IP on age, gender, race, and native language (92%), as do 22 of 25 repeats under the same SONA ID (88%). Random pairs of different participants match 1.7% of the time. No flagged response overlapped in time with the earlier one.

  Only each person's first exposure to a vignette is analyzed. A response is a repeat if its SONA ID appeared on an earlier response that reached a vignette, or if it has no SONA ID and an earlier response from the same IP address reached a vignette within the previous three hours. This removes 136 of the 403 Study 2 responses that passed the comprehension checks. The rule was set after inspecting these response patterns, before any analysis of outcomes. Study 1 has no repeat responses under the same rule.
- (c) **Shared IP addresses.** After repeats are removed, 26 of the 261 analyzed Study 2 responses share an IP address with another analyzed response. Each such pair has different SONA IDs or started more than three hours apart, which fits a shared campus network. They are kept.

## 4. What we have already seen

No analysis has been run on the final datasets. The scripts corrected in September 2026 have never been run. We have checked the final files only for:

- row counts, and responses per cell at each inclusion step;
- item coding, completion times, and text lengths;
- completeness and value ranges of the restored Study 1 items, overall, not by condition;
- which Study 2 responses appear in the 2025 interim file, matched by response ID.

Earlier work, all seen by the authors:

1. **Study 1 ratings at N = 137 (22 October 2025) and N ≈ 244 (8 November 2025).** We ran 2 × 2 ANOVAs on all 15 items, using scale codes that were wrong for three items. They showed:
   - no artist-fame effect on legal judgments, with about 87% favoring the photographer on the jury item;
   - victim-fame effects on distress, overall harm, victim status, and payment (d ≈ 0.3–0.5);
   - artist × victim interactions on some harm items.
2. **Study 1 text at N = 136 and N = 242.** About 60 word-count, dictionary, and machine-learning features, each tested against one factor at a time. One feature stood out: a victim-fame effect on a count of causal words (p ≈ .02). Sentiment, emotion, and moral-foundation scores showed nothing.
3. **Study 2 at 103 responses that passed the comprehension checks (all started 5–10 November 2025).** We analyzed all items, ran several follow-up models, and ran the text pipeline. These showed:
   - large transformation effects on legal items;
   - cell means hinting at a larger transformation effect for unknown artists;
   - transformation effects on passive voice and on words that signal a counterargument.
4. **Dissemination.** Results 1 and 2 were presented at a university research group meeting on 8 November 2025. A results draft (N = 137) exists. A figure prepared for the Society for Philosophy and Psychology was submitted and not accepted. Nothing is published or preprinted.

**Consequences.**

- Confirmatory tests use Study 2 only.
- Each confirmatory test is repeated on the Study 2 responses that were not in the interim file (164 after all inclusion rules).
- The word measures, chosen partly because of results 2 and 3, are exploratory.
- The equivalence bound was set after the interim nulls were seen, and we say so.

## 5. Data and coding

**Files.** `Study1_Values.csv` (276 rows, re-exported 10 November 2026) and `Study2_Values.csv` (599 rows, exported 13 October 2026), as de-identified by `Analysis/00_deidentify.R` in the repository. The matching Labeled exports are used only to check codes. Interim exports from 2025 are not used, except to identify which Study 2 responses were seen.

**Who is included.** A response is included if:

- it is finished (`Finished` = 1);
- its final comprehension answers are correct (`WhoNewCheck` = 1, `ReasonWhyCheck` = 2);
- it is the participant's first exposure to a vignette (Section 3, irregularity b; `repeat_response` = 0);
- the participant did not answer "No" to the seriousness question (`Seriousness` ≠ 1);
- its condition fields agree with which vignette page has timing data.

WorkTransform is not an inclusion criterion. Apart from the repeat rule, we exclude no one for shared IP addresses, completion time, or the values of their ratings, and we remove no outliers.

**Sample.**

| | Recorded | Assigned to a cell | Finished | Passed checks | First response only | After seriousness rule |
|---|---|---|---|---|---|---|
| Study 1 | 276 | 269 | 264 | 246 | 246 | 228 |
| Study 2 | 599 | 502 | 440 | 403 | 267 | 261 (164 unseen) |

**Planned sample size.** For Study 1, an a priori power analysis in G\*Power 3.1 (ANOVA: fixed effects, omnibus, one-way; f = 0.20, α = .05, power = .80, four groups) gave a total of 280, 70 per cell (actual power .806). The Study 1 survey's quotas were set to 70 per cell to match. The omnibus test is conservative for our 1-df factorial effects: at N = 280, power to detect f = 0.20 for a main effect or the interaction is .91. Recruitment ended at 276 recorded responses, just short of the target. An earlier, unsubmitted AsPredicted-format draft had proposed 400 participants; it was superseded by this calculation. For Study 2, the same G\*Power analysis with eight groups (f = 0.20, α = .05, power = .80) gave a total of 368, 46 per cell (actual power .803). The survey's 40-per-cell quotas did not match this target and did not limit enrollment. Recruitment ended at 599 recorded responses. After repeat responses are removed (Section 3), 267 distinct participants passed the comprehension checks, fewer than the planned 368. Interim analyses of both studies (Section 4) were run while data were still being collected. Study 1 recruitment stopped near its planned 280, and Study 2 recruitment continued after its interim analysis.

**Sensitivity.** With 80% power, Study 2 (N = 261) detects a main effect of about d = 0.35 at α = .05 and d = 0.43 at the strictest Holm level for five tests (α = .01). The unseen subset (N = 164) detects d = 0.44 at α = .05. Interaction effects must be about twice as large to be detected. Study 1 (N = 228) detects d = 0.37 at α = .05.

**Scoring.** Higher scores always mean less favorable to Martinez: more restrictive, more blame, more harm to Rivera. Four items run the other way in the export and are reversed.

| Item (export name) | Question, in brief | Scale | Scoring |
|---|---|---|---|
| AllowedReason | Should Martinez be legally allowed to sell it without permission? | 1 definitely not … 5 definitely yes | 6 − x |
| Jury | On a jury, who would you rule for? | 1 strongly Rivera … 5 strongly Martinez | 6 − x |
| CostReason | Does the $500 sale make the use more or less acceptable? | 1 much less … 5 much more | 6 − x |
| ReduceMarket | Would the artwork reduce the original's market value? | 1 definitely reduce … 6 definitely increase | 7 − x |
| MorallyWrong, Unfairness, RightsViolation, VictimRivera, ObjectKnowledge, Punishment, Payment | moral judgment and remedy | 1 … 5 | as exported |
| FinancialHarm, ReputationHarm, EmotionalDistress, OverallHarm | harm to Rivera | 1 none … 5 severe | as exported |
| ArtistStatus, PowertoStop, Resources | perceived status of Martinez; Rivera's power to stop the use; who had more resources | 1 … 5 | as exported |
| WorkTransform (Study 2) | Was the new work highly different? | 1 yes, 2 no | comprehension item |
| ArtTraining | formal art training | exported 1, 4, 5, 6, 7 | recode to 1–5 |
| CopyrightFamiliar, Age, Gender, Race, NativeLanguage | background | | description and moderators |

All rating items required a response. ReduceMarket offers three "increase" options but only two "reduce" options; this is reported as a limitation.

**Composites.** The Moral score is the mean of MorallyWrong, Unfairness, RightsViolation, and VictimRivera. The Harm score is the mean of the four harm items. Both are always computed this way. Cronbach's α is reported as a description, not used as a gate.

**Outcomes.**

- *Primary:* AllowedReason (legal), Moral score, Harm score, Payment (remedy).
- *Secondary:* every other rating item.

## 6. Analysis

**Software.** R Markdown files for the rating analyses and the text statistics in Section 7 (`vegan`, `stm`, `logistf`, `glmnet`). Google Colab notebooks (Python, on a Colab Pro+ GPU) for embeddings (local models and the Google and Voyage APIs), language-model coding (vLLM for the open-weight coder; the Anthropic and Google APIs for the check coders), BERTopic, and spaCy. Package versions are recorded and the random seed is 2025. The full analysis code is written, tested on simulated data, and committed to the public repository with its date before it is run on the real data. It is then run once on the real data.

**Models.** For each outcome we fit a linear model with all factors and their interactions: Artist × Victim in Study 1, and Artist × Victim × Transformation in Study 2. The models use sum-to-zero contrasts, Type III tests, and robust (HC3) standard errors. Every effect is reported with an estimate and 95% CI. Two-level contrasts are reported as d, using the model's residual SD; model terms are reported as partial η².

**Confirmatory tests (Study 2, N = 261).**

| | Outcome | Model term | Prediction |
|---|---|---|---|
| C1 | AllowedReason | Transformation | High < Low (less restrictive) |
| C2 | Harm score | Victim Fame | unknown > famous |
| C3 | Payment | Victim Fame | unknown > famous |
| C4 | AllowedReason | Artist Fame | equivalence within ±0.25 points, and a two-sided test of difference |
| C5 | AllowedReason | Artist Fame × Transformation | two-sided |

- **Correction.** p values are Holm-adjusted across C1–C5.
- **What counts as supported.** A test is supported if its adjusted p < .05, its sign matches the prediction where one is made, and its estimate has the same sign in the 164 unseen responses. C5 must also agree in sign and significance with the ordinal model.
- **C4, equivalence.** Equivalence holds if the 90% CI for the artist-fame difference in marginal means (HC3) lies within ±0.25 points, which is both one-sided p values below the Holm-adjusted level. The two-sided test of a difference is reported alongside. The bound is in raw scale points so that it does not depend on the observed SD.

**Secondary results.** Everything else is reported in full and labeled secondary:

- all other terms and outcomes in Study 2;
- all of Study 1.

Within each study, these results get unadjusted p values and Holm-adjusted p values across all terms and the four primary outcomes. None is described as confirmed. We claim an interaction only if the linear and ordinal models agree in sign and both have p < .05.

**Pooled fame effects (secondary).** A fixed-effect meta-analysis of the artist-fame and victim-fame main effects from each study's own model, with the heterogeneity statistic Q.

**Items asked after the outcomes.** Perceived status, power, and resources were asked after every rating and the written explanation, and no item asks about Rivera's fame directly. We report them by condition as post-outcome perceptions, not as clean manipulation checks, and we run no mediation analysis. WorkTransform is a comprehension item with a reread loop, so it cannot test whether the transformation manipulation worked. We report the share answering correctly by condition, and treat the lack of an independent transformation check as a limitation.

**Attrition.** For each cell we report the count at each inclusion step, with a χ² test of whether exclusion rates differ by condition.

**Checks on the main results (supplement).**

- Ordinal (proportional-odds) models for every single-item outcome.
- Results with non-serious responders included.
- Results for all finished first responses, ignoring the comprehension checks.
- Study 2 without the participants who answered WorkTransform wrongly for their condition.
- Reverse-scored AllowedReason split at 4–5 vs. 1–3 and analyzed with logistic regression, because so many answers sit at the restrictive end.

A check *changes* a result if it flips the sign of the estimate or moves the adjusted p across .05. Any change is reported in the main text.

**Exploratory analyses.** Whether art training or copyright familiarity changes the fame or transformation effects. These are labeled exploratory.

## 7. Written explanations

After the four legal ratings, and before the moral and harm ratings, every participant answered "Explain your reasoning for your ruling." Median length is 26 words in Study 1 and 23 in Study 2. Responses under three words are set aside for text analyses.

The text analyses ask three questions:

- **TQ1.** Do the conditions change what people write?
- **TQ2.** Which reasons and themes differ, and how?
- **TQ3.** How do the written reasons relate to the ratings?

### 7.1 Development and test sets

Text methods involve choices that are easy to tune to the data: a codebook, a list of words to mask, the number of topics, anchor sentences, a prompt. We make those choices on data already seen and test on data no one has seen.

- **Development set:** all of Study 1 and the 103 Study 2 responses in the 2025 interim file (about 330 responses).
- **Test set:** the 164 analyzed Study 2 responses never seen (`in_2025_interim` = 0).

Development work does not look at differences between conditions. Every choice made on the development set is committed to the public repository, with its date, before the test set is analyzed. The planned text tests (7.4) use the test set only. Everything else is reported on the test set and on all of Study 2, and labeled exploratory.

### 7.2 Masking the manipulation

Many explanations restate the vignette ("Martinez is famous, so…"). A difference that only echoes the manipulation is not a difference in reasoning. Each analysis therefore runs on the raw text and on a masked copy. The masked copy replaces the following with a neutral token:

- the fame descriptions and close variants: famous, fame, renowned, well-known, celebrated, influential, unknown, large or small following, international museums, local galleries;
- the verbatim transformation descriptions, such as "15 other images," "nearly identical," and "minor brightness adjustments."

The list is finalized on the development set. Masked text is primary for TQ1 and TQ2. Whether people mention fame or transformation at all is analyzed separately, as uptake (7.6).

### 7.3 Embeddings

Each response is embedded by a panel of four models. The panel mixes open-weight and commercial models, large and small, so that no result depends on one model:

- **primary:** `Qwen/Qwen3-Embedding-8B`, among the highest-scoring open-weight models on the English MTEB benchmark. It is pinned to a fixed Hugging Face revision, so anyone can rerun it exactly.
- **commercial check:** Google `gemini-embedding-2`.
- **commercial check:** Voyage `voyage-4-large`.
- **small baseline:** `sentence-transformers/all-mpnet-base-v2`. It shows whether a result needs a large model at all.

The vectors from every model are saved in the repository, so results can be reproduced even if a commercial model is changed or retired. Only de-identified text is sent to the commercial services. Models released after registration may be added as further checks, labeled as added later. They never replace the primary model. The 2025 pipeline used `all-MiniLM-L6-v2`; it is dropped.

### 7.4 Planned text tests (TQ1, test set)

Three tests, Holm-adjusted together and kept separate from the five rating tests:

| | Question |
|---|---|
| T1 | Do explanations differ by Artist Fame? |
| T2 | Do explanations differ by Victim Fame? |
| T3 | Do explanations differ by Transformation? |

- **Test.** PERMANOVA (R `vegan::adonis2`) on cosine distances between masked-text embeddings, in a model with the three main effects. Each factor is tested marginally, with 9,999 permutations.
- **Spread.** PERMANOVA also reacts to differences in spread, so a dispersion test (`betadisper`) is reported beside each result.
- **Effect size.** How well a classifier can tell the condition from the explanation: cross-validated logistic regression on the embeddings (10 folds, repeated 10 times), with accuracy compared to a permutation distribution.
- **What counts as supported.** A test is supported if its Holm-adjusted p < .05 with the primary model and p < .05 with at least two of the three check models.

Interactions are exploratory.

### 7.5 Reason codes (TQ2)

**Codebook.** The codebook is multi-label: a response can have several codes. It starts from the four fair use factors and adds the reasons people gave in 2025:

1. permission or consent;
2. transformation, originality, or how much was changed (factor 1);
3. the kind of work the photograph is (factor 2);
4. how much of the photograph was used (factor 3);
5. effect on Rivera's market or income (factor 4);
6. Martinez's profit from the prints;
7. credit or attribution;
8. harm to Rivera other than money (reputation, feelings);
9. fame, status, or power of either party;
10. fairness or moral language (wrong, unfair, stealing);
11. appeal to law or rules;
12. a remedy (should pay, share profits, give credit, should have asked).

Each response is also coded for **stance**: favors Rivera, favors Martinez, or mixed or unclear.

**Coding.**

1. Two human coders refine the codebook on the development set. They are research assistants who are not authors, have not seen any interim results, and do not see conditions; they are not named here.
2. They independently code a stratified random sample of 200 development responses. We report Cohen's κ for each category before discussion.
3. Three large language models code every response with the same codebook. The exact model IDs and settings are committed to the repository before coding begins.
   - *Primary coder:* OpenAI's open-weight `gpt-oss-120b`, pinned to a fixed Hugging Face revision. It is run on a Colab GPU in vLLM's batch-invariant mode with a fixed seed, so rerunning it gives the same codes. If no GPU with enough memory (about 80 GB) is available, `gpt-oss-20b` is used instead; this is decided and recorded before any coding.
   - *Check coders:* Claude (Anthropic, `claude-opus-5-5`) and a current Gemini model (Google), through their APIs. These hosted models do not allow sampling to be fixed, so each codes every response three times and the majority code is used. Agreement across runs is reported.
   - *Format.* Every model returns its codes in a fixed JSON format (structured output).
   - *Records and privacy.* Every prompt and output is saved. Only de-identified text is sent to the hosted models.
4. A category is used only if κ between the two humans is at least .70 and κ between the primary coder and the human consensus is at least .70. Agreement of Claude and Gemini with the primary coder and with the humans is reported, and the analyses are rerun with each check coder's codes.
5. On the test set, one human codes a random 100 responses to confirm the model's agreement. Categories that fall below .70 there are reported as unreliable and not analyzed.

**Analysis.** Each retained category is compared across conditions with Firth logistic regression using the study's factors, with Benjamini–Hochberg (BH) adjustment across categories and terms. Results are exploratory.

### 7.6 Unsupervised structure and other features (TQ2, exploratory)

- **Topics with condition effects.** A structural topic model (R `stm`) is fit to Study 1 and Study 2 together, with the condition factors as covariates of topic prevalence. The number of topics is chosen on the development set from held-out likelihood, semantic coherence, and exclusivity for 3 to 12 topics, then frozen. Condition effects on topic prevalence come from `estimateEffect`. Two authors label topics from top words and typical responses before seeing condition effects.
- **Embedding-based topics.** BERTopic on the primary embeddings (UMAP and HDBSCAN, fixed seeds) gives a second view. We report its stability across 10 seeds (adjusted Rand index) and give more weight to topics both methods find.
- **Words that separate conditions.** Weighted log-odds ratios with an informative Dirichlet prior (Monroe, Colaresi, & Quinn, 2008), for each factor.
- **Semantic axes.** Each response is placed on a few theory-defined axes by its embedding's projection onto sets of anchor sentences (distributed dictionary representations; Garten et al., 2018):
  - harm to the photographer vs. the borrowing artist's creative freedom;
  - legal rule vs. moral fairness;
  - permission vs. transformation.

  Anchor sentences are written and frozen on the development set. Projections are analyzed with the factorial model.
- **Moral language.** The Moral Foundations Dictionary 2.0 (Frimer et al., 2019) and the extended MFD (Hopp et al., 2021), which are validated instruments. They replace the 2025 zero-shot moral-foundation scores.
- **Party focus.** How often each party is mentioned, and sentiment toward each party (coded by the language model and validated with the codebook sample).
- **Smaller features.** Length; hedging and certainty words; causal and counterargument words; passive voice; and counterfactuals ("if he had asked"). The word lists are whole-word and case-insensitive, and the 2025 code's bare "as" and "to" are dropped.
- **Uptake.** The share of raw explanations that mention fame or status, by fame condition, and the share that mention how much the work was changed, by transformation condition. The explanation comes before the moral and harm ratings, so this is the closest the study has to an early check on whether the manipulations registered.
- **Data quality.** Explanations that copy the vignette, are off-topic, or are not in English are flagged and counted, not excluded.

Dropped from the 2025 pipeline: metaphor dictionaries, clustering methods other than those above, entity networks, and zero-shot natural language inference.

### 7.7 Linking explanations to ratings (TQ3, exploratory)

- **Do explanations carry the verdict?** Cross-validated ridge regression from embeddings to each primary rating, giving out-of-sample R² with bootstrap CIs, compared to permuted labels.
- **Stance and verdict.** The share of explanations whose coded stance agrees with the Jury rating, by condition. Disagreement is a measure of ambivalence.
- **Reasons by verdict.** How common each reason is among participants who favored Rivera vs. Martinez.
- **Reasons beyond the verdict.** Condition effects on reason codes with AllowedReason and Jury as covariates, described as non-causal.
- **Reasons and the later ratings.** The explanation was written before the moral and harm ratings. We ask whether harm, fairness, and permission reasons predict the later Harm, Moral, and Payment scores beyond the legal ratings, in regressions that include the condition factors and the legal ratings.
- **Matching effects.** For each condition effect on a rating, a single table shows the matching text effect, for example victim fame on the Harm score next to victim fame on harm reasons. This shows whether rating effects have a counterpart in what people wrote. We run no formal mediation analysis.

Condition effects on ratings are never adjusted for text features, because the text was written after random assignment.

## 8. What we will report

- **Participant flow:** per cell, at each inclusion step.
- **Confirmatory tests:** C1–C5, on all of Study 2 and on the unseen subset; T1–T3 on the text test set.
- **Results tables:** one per study, giving cell means and SDs, test statistics, unadjusted and adjusted p values, and effect sizes for every rating outcome.
- **Separation:** the confirmatory, secondary, and exploratory results kept in separate sections.
- **Changes:** a "Changes from the analysis plan" section listing every change, with reasons.
- **Materials posted at submission,** in the public repository and its archived release: de-identified data, analysis code, both survey files, and this plan.

## 9. Changes after registration

Any change after registration is listed in the paper with its reason. If a planned model cannot be fit, for example because it does not converge, we use the simplest standard fallback (Poisson with robust errors for counts, linear models for ordinal items) and report it.

## Appendix A. Variable map

Columns are selected by Qualtrics ImportId, not by export name, because names repeat across survey versions.

| Variable | ImportId | Note |
|---|---|---|
| ArtistStatus | QID38 | export name "Status"; a second "Status" column is the Qualtrics response type |
| PowertoStop | QID39 | |
| Resources | QID40 | |
| Seriousness | QID1720293454 | 1 = No, 4 = Yes |
| Age | QID1720293458_TEXT | free text, cleaned to an integer |
| Study 1 replacement block | QID1720311575–QID1720311586 (export names Q1–Q12) | empty for every response; not used |
| Fame condition | embedded field `Type` | |
| Transformation condition (Study 2) | embedded field `TransformCondition` | |
| Repeat responses | column `repeat_response` in the de-identified files | 1 = not the person's first exposure to a vignette (Section 3, irregularity b) |
| Unseen subset (Study 2) | column `in_2025_interim` in the de-identified file | 0 = not in the 2025 interim file (matched by response ID before de-identification) |
