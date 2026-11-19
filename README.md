# Fame, Transformation, and Lay Judgments of Fair Use

Materials, de-identified data, and analysis code for two experiments by David G. Kamper, Becca Bedell, and Keith J. Holyoak (manuscript in preparation).

Courts treat fair use as a question about the work: how much the new work transforms the original, and whether it harms the original's market. Two vignette experiments ask whether ordinary people also weigh who the parties are. A visual artist, Alex Martinez, makes and sells prints of a new artwork built from a landscape photograph by Jamie Rivera, without permission. **Study 1** (N = 276 recorded, 246 included) crosses the artist's fame with the photographer's fame. **Study 2** (N = 599 recorded, 403 included) adds how much Martinez transformed the photograph. Participants were UCLA undergraduates who took part for course credit in October and November 2025.

**Status.** The analysis plan was written after data collection and before any analysis of the final data, and registered on OSF on 19 November 2026: <https://osf.io/pj25c>. The analysis code will be committed here, tested on simulated data, before it is run on the real data.

## What is in this repository

| Folder | Contents |
|---|---|
| `Docs/Preregistration/` | The registered analysis plan: `Analysis_Plan_v1.1_registered.pdf` is the file uploaded to OSF (SHA-256 `57bc2a36367ff0dbb9e6f71341a3d1f27fdfebd19850bfd17a36680a20afaf6a`), and the `.md` file is its source. The registered copy is blinded for peer review. |
| `Experiment/` | Both Qualtrics surveys as exported (`.qsf`), with the SONA credit token and the Qualtrics account id replaced by `REDACTED`, and a printout of the Study 1 survey (`Stimuli/`). |
| `Data/` | One de-identified response file per study (`StudyN_deidentified.csv`, one row per recorded response, before any exclusions) and a codebook per study (`StudyN_codebook.csv`: column name, Qualtrics export name, ImportId, and question text). |
| `Analysis/` | `00_deidentify.R`, which produced the files in `Data/` from the raw exports. The registered analysis scripts follow. |

## Reading the data files

* Ratings are the raw Qualtrics codes. The scoring rules (which items are reversed, how composites are formed, who is excluded) are in the analysis plan and applied by the analysis scripts, not in these files.
* `QualtricsStatus` is the Qualtrics response type. `ArtistStatus` is the item "How much status does Martinez (the artist) have in the art world?"
* `Type` holds the fame condition; in Study 2, `TransformCondition` holds the transformation condition.
* `repeat_response` is 1 when a response is not the person's first exposure to a story: the same SONA ID appeared on an earlier response, or the response has no SONA ID and an earlier response from the same IP address reached a story within the previous three hours. It is computed before the IDs and IP addresses are removed. Study 1 has none; Study 2 has 188 (136 of them among responses that passed the comprehension checks). Analyses keep only `repeat_response` = 0.
* In Study 2, `in_2025_interim` is 1 for the 103 responses that were in a 2025 interim analysis and 0 for responses no one had seen; the analysis plan repeats each confirmatory test on the unseen responses.
* `ArtTraining` is exported with the codes 1, 4, 5, 6, 7; the analysis recodes them to 1–5. `Seriousness` is 1 = No, 4 = Yes.

## De-identification

`Analysis/00_deidentify.R` removes IP address, location, the SONA id, the consent date, recipient and distribution fields, and the end and recorded timestamps; keeps only the date of `StartDate`; replaces Qualtrics response ids with study-specific ids (`S1_0001` …); top-codes age at 30; and drops columns that are empty for every response. It screens all free-text answers for contact details and identification numbers. The two debrief comment boxes ("Was any part of the procedure unclear?" and "Is there anything else you would like to share?") are not used in any analysis and are left out, because that is where participants volunteer personal details. In the written explanations that remain, e-mail addresses, links, phone numbers, and long numbers would be replaced with `[REDACTED]`; the screen found none. The key linking ids to Qualtrics records stays with the authors.

## A note on the Study 1 survey file

About 20 October 2025, after 65 Study 1 responses, the end-of-survey questions (perceived status, power, and resources; seriousness; demographics) were moved to the Qualtrics Trash in the survey editor, and a replacement demographics block was added. The live survey kept showing the original questions, and every included participant answered them. In November 2026 the questions were restored and re-exported. The exported `.qsf` and the printout reflect the editor after the October edit: the original questions sit in the Trash block, and the replacement block, which no participant saw, appears in the flow. The analysis plan (Section 3) describes the episode and the checks that the restored answers are complete and correct.

## What is not included

* The raw Qualtrics exports and the id key, which contain identifiers.
* The two debrief comment boxes (see above).
* Interim analyses run in 2025 on partial data with scoring errors. The analysis plan (Section 4) lists them; none of their numbers are used.

## License

Code is licensed MIT (`LICENSE`). Data, materials, and documents are licensed CC BY 4.0 (`LICENSE-DATA`). Please cite the archived release (see `CITATION.cff`) and the article once published.
