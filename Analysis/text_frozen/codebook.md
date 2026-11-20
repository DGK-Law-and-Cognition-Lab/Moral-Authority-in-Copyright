# Codebook for the written explanations (DRAFT)

Status: draft. The two human coders refine this on the development set (registered plan, Section 7.5). The final version is committed, with the date, before any test-set coding. The text between the two `PROMPT` markers is inserted verbatim into the prompt every language-model coder receives.

Revision 1 (19 November 2026), after the coders' first calibration round (development items P01-P20; no condition information): added code 13 (reliance); remedy now includes not paying Rivera; added the rules for hard cases. See `Docs/Changes after registration.md`, entry 2.

<!-- PROMPT START -->
You will read one participant's answer to the question "Explain your reasoning for your ruling." The participant had read a short story: a visual artist, Alex Martinez, made and sold prints of a new artwork built from a landscape photograph by a photographer, Jamie Rivera, without asking permission or paying. Martinez said the new work was different enough to count as fair use. The participant then said how they would rule if they were on a jury, and wrote this explanation.

Code what the explanation SAYS, not what you think about the case. A response can have several codes. Mark a code true only if the explanation clearly expresses that reason; mark it false otherwise.

Reason codes:
1. permission: Martinez did or did not ask for, or needed, Rivera's permission or consent.
2. transformation: whether the new work is transformative, original, creative, or how much Martinez changed the photograph (fair use factor 1).
3. nature_of_work: the kind of work the photograph is (for example, that it is a creative or artistic photograph, or published) (fair use factor 2).
4. amount_used: how much of the photograph Martinez used (all of it, part of it) (fair use factor 3).
5. market_effect: the effect on Rivera's market, sales, income, or opportunities (fair use factor 4).
6. profit: that Martinez made money or sold the prints for profit.
7. credit: credit or attribution to Rivera (giving or not giving credit).
8. nonmonetary_harm: harm to Rivera other than money, such as reputation, feelings, or recognition.
9. fame_status_power: the fame, status, reputation, power, or resources of either party.
10. fairness_moral: moral or fairness language (wrong, unfair, stealing, right, ethical).
11. law_rules: appeals to law, legal rules, copyright, or fair use as a legal standard.
12. remedy: a remedy or what should happen (pay Rivera, share profits, give credit, should have asked, take it down), including that Martinez did not pay Rivera.
13. reliance: Martinez's work depends on Rivera's photograph or effort: the photograph is the foundation or basis of the new work, the new work would not exist without it, Rivera did the work or the hard part, or the photograph gives the new work its value.

Rules for hard cases:
- Code only what the explanation says, not facts from the story that it leaves out. Code permission only if the explanation mentions asking, permission, consent, or agreeing. The word "used" by itself is not amount_used. Calling the work a photograph is not nature_of_work. Code credit only if the explanation mentions credit or attribution.
- If the explanation says Martinez should have asked, or needed consent, code both permission and remedy. If it only says he did not ask, code permission alone.
- Saying that Martinez did not pay Rivera is remedy, as is saying that he should pay.
- Any mention of Martinez selling the work, making money, revenue, or a commission is profit, even inside a remedy (for example, "share the revenue").
- If the participant mixes up the names, code by role: Rivera is the photographer, and Martinez is the artist who used the photograph.

Stance: which side the explanation favors.
- favors_rivera: the explanation supports the photographer.
- favors_martinez: the explanation supports the artist.
- mixed_or_unclear: both sides, neither, or cannot tell.

Sentiment toward each party, as expressed in the explanation:
- sentiment_martinez and sentiment_rivera: one of negative, neutral, positive, not_mentioned.

Return only the JSON object described in the instructions.
<!-- PROMPT END -->
