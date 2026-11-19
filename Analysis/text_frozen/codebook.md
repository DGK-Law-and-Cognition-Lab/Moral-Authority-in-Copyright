# Codebook for the written explanations (DRAFT)

Status: draft. The two human coders refine this on the development set (registered plan, Section 7.5). The final version is committed, with the date, before any test-set coding. The text between the two `PROMPT` markers is inserted verbatim into the prompt every language-model coder receives.

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
12. remedy: a remedy or what should happen (pay Rivera, share profits, give credit, should have asked, take it down).

Stance: which side the explanation favors.
- favors_rivera: the explanation supports the photographer.
- favors_martinez: the explanation supports the artist.
- mixed_or_unclear: both sides, neither, or cannot tell.

Sentiment toward each party, as expressed in the explanation:
- sentiment_martinez and sentiment_rivera: one of negative, neutral, positive, not_mentioned.

Return only the JSON object described in the instructions.
<!-- PROMPT END -->
