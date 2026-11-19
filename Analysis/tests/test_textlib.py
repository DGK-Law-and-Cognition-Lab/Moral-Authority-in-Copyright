"""Tests for Analysis/python/textlib.py. Run from the repository root:
    python3 -m pytest -q Analysis/tests/test_textlib.py
No test reads a real response.
"""
import json
import os
import sys

import numpy as np
import pandas as pd
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "python"))
import textlib as tl  # noqa: E402

ROOT = tl.repo_root(os.path.dirname(__file__))
CFG = tl.load_config(ROOT)


def test_tokens_keep_apostrophes_and_split_hyphens():
    assert tl.tokens("Rivera’s well-known photo, don't!") == ["rivera's", "well", "known", "photo", "don't"]


def test_count_terms_whole_words_phrases_first_no_double_counting():
    terms = ["cause", "because", "as a result", "result in", "so that"]
    assert tl.count_terms("Because of the cause", terms) == 2
    assert tl.count_terms("becauseway causes", terms) == 0            # whole words only
    assert tl.count_terms("As a result it could result in harm", terms) == 2
    # "as a result in" contains both phrases; the longer, earlier match consumes "result"
    assert tl.count_terms("as a result in", ["as a result", "result in"]) == 1
    assert tl.count_terms("He did so that he could", terms) == 1


def test_registered_causal_list_drops_bare_as_and_to():
    causal = CFG["word_lists"]["causal"]
    assert "as" not in causal and "to" not in causal
    assert tl.count_terms("He used it to sell it as art", causal) == 0


def test_masking_replaces_fame_and_transformation_phrases_only():
    terms = CFG["masking"]["fame_terms"] + CFG["masking"]["transformation_phrases"]
    s = "Martinez is World-Renowned and famous, Rivera is relatively unknown; the work looked nearly identical. Fame matters."
    m = tl.mask_text(s, terms, "[MASK]")
    assert m == "Martinez is [MASK] and [MASK], Rivera is [MASK]; the work looked [MASK]. [MASK] matters."
    assert tl.mask_text("a world-famous artist and a well known one", terms) == "a [MASK] artist and a [MASK] one"
    assert tl.mask_text("infamous fameless", terms) == "infamous fameless"   # not inside other words
    assert tl.mask_text("the following reasons", terms) == "the following reasons"   # bare 'following' is not masked


def test_masking_is_identical_across_hash_seeds():
    import subprocess
    code = ("import sys; sys.path.insert(0, %r); import textlib as tl; cfg = tl.load_config(%r); "
            "t = cfg['masking']['fame_terms'] + cfg['masking']['transformation_phrases']; "
            "print(tl.mask_text('He is world-renowned and world-famous, not unknown; nearly identical', t))"
            % (os.path.join(ROOT, "Analysis", "python"), ROOT))
    outs = set()
    for seed in range(12):
        env = dict(os.environ, PYTHONHASHSEED=str(seed))
        outs.add(subprocess.run([sys.executable, "-c", code], env=env, capture_output=True, text=True, check=True).stdout)
    assert outs == {"He is [MASK] and [MASK], not [MASK]; [MASK]\n"}


def test_uptake_flags():
    up = CFG["uptake"]
    assert tl.mentions_any("He is famous so he should know better", up["fame_status"])
    assert not tl.mentions_any("He did not ask permission", up["fame_status"])
    assert tl.mentions_any("It is basically a copy of the photo", up["change"])
    assert not tl.mentions_any("He used the original photo without asking", up["change"])


def test_passive_clause_counts():
    spacy = pytest.importorskip("spacy")
    nlp = spacy.load("en_core_web_sm")
    c = tl.clause_counts(nlp("The photograph was taken by Rivera."))
    assert c == {"clauses": 1, "passive_clauses": 1}
    c = tl.clause_counts(nlp("Martinez took the photograph and he sold it."))
    assert c["passive_clauses"] == 0 and c["clauses"] == 2
    c = tl.clause_counts(nlp("It is wrong because the work was copied."))
    assert c["clauses"] == 2 and c["passive_clauses"] == 1
    c = tl.clause_counts(nlp("He should have asked because it is her photo."))
    assert c["clauses"] == 2 and c["passive_clauses"] == 0


def test_vignette_texts_come_from_the_survey_files():
    texts = tl.vignette_texts(ROOT)
    joined = " ".join(texts)
    assert len(texts) >= 10
    assert "nearly identical" in joined and "15 other images" in joined and "world-renowned" in joined.lower()
    src = set().union(*(tl.ngrams(tl.tokens(t), 5) for t in texts))
    copied = "In the new artwork, Martinez changed the colors of Rivera's photograph and added text over it."
    assert tl.copy_share(copied, src, 5) > 0.5
    assert tl.copy_share("I think he should have asked first because it is her photo", src, 5) < 0.2


def test_dictionary_parsers(tmp_path):
    dic = tmp_path / "toy.dic"
    dic.write_text("%\n1\tcare.virtue\n2\tfairness.vice\n%\nprotect*\t1\ncheat\t2\nunfair\t2\n", encoding="utf-8")
    d = tl.read_dic(str(dic))
    assert d == {"care.virtue": ["protect*"], "fairness.vice": ["cheat", "unfair"]}
    s = tl.dic_scores("He protected nothing and it was unfair", d)
    assert s["care.virtue"] == pytest.approx(1 / 7) and s["fairness.vice"] == pytest.approx(1 / 7)
    table = pd.DataFrame({"word": ["harm", "fair"], "care_p": [0.8, 0.1], "fairness_p": [0.2, 0.9]})
    w = tl.weighted_scores("harm harm fair other", table)
    assert w["care_p"] == pytest.approx((0.8 + 0.8 + 0.1) / 3)
    assert tl.weighted_scores("nothing here", table) == {"care_p": 0.0, "fairness_p": 0.0}


def test_ddr_scores_sign():
    a = np.array([[1.0, 0.0], [0.9, 0.1]]); b = np.array([[0.0, 1.0], [0.1, 0.9]])
    docs = np.array([[1.0, 0.05], [0.05, 1.0]])
    s = tl.ddr_scores(docs, a, b)
    assert s[0] > 0 > s[1]


def test_hash_embed_is_deterministic_and_normalized():
    X1 = tl.hash_embed(["a b c", "d e"], 64); X2 = tl.hash_embed(["a b c", "d e"], 64)
    assert np.allclose(X1, X2) and np.allclose(np.linalg.norm(X1, axis=1), 1)


def test_decoding_accuracy_detects_signal_and_not_noise():
    rng = np.random.default_rng(0)
    y = np.repeat([0, 1], 60)
    X_sig = rng.normal(size=(120, 20)); X_sig[:, 0] += 3.0 * y
    X_noise = rng.normal(size=(120, 20))
    r_sig = tl.decoding_accuracy(X_sig, y, folds=5, repeats=2, n_permutations=50)
    r_noise = tl.decoding_accuracy(X_noise, y, folds=5, repeats=2, n_permutations=50)
    assert r_sig["accuracy"] > 0.7 and r_sig["permutation_p"] < 0.05
    assert 0 <= r_sig["permutation_observed_accuracy"] <= 1
    assert r_noise["permutation_p"] > 0.05


def test_log_odds_direction():
    a = ["copy copy identical"] * 10; b = ["changed different new"] * 10
    lo = tl.log_odds_dirichlet(a, b, a + b)
    assert lo.iloc[0]["word"] in ("copy", "identical") and lo.iloc[0]["z"] > 0
    assert lo.iloc[-1]["z"] < 0


def test_coding_schema_parse_and_majority():
    good = {c: False for c in tl.REASON_CODES}; good.update(permission=True, stance="favors_rivera",
                                                            sentiment_martinez="negative", sentiment_rivera="neutral")
    assert tl.parse_coding(json.dumps(good)) == good
    assert tl.parse_coding("Here it is: " + json.dumps(good) + " done") == good
    with pytest.raises(ValueError):
        tl.parse_coding(json.dumps({**good, "stance": "both"}))
    with pytest.raises(ValueError):
        tl.parse_coding(json.dumps({k: v for k, v in good.items() if k != "remedy"}))
    r2 = {**good, "permission": False, "stance": "favors_martinez"}
    m = tl.majority([good, good, r2])
    assert m["permission"] is True and m["stance"] == "favors_rivera" and m["n_valid_runs"] == 3
    m = tl.majority([good, r2, None])                       # two valid runs that disagree
    assert m["permission"] is False and m["stance"] == "mixed_or_unclear"
    assert tl.majority([None, None]) is None
    ag = tl.run_agreement([[good, good, good], [good, r2, good]])
    assert ag.set_index("field").loc["permission", "share_all_runs_agree"] == 0.5


def test_simulated_coder_output_is_schema_valid():
    out = tl.simulated_coder("Martinez did not ask Rivera for permission. He should pay Rivera.")
    assert tl.parse_coding(json.dumps(out)) == out and out["permission"] and out["remedy"]


def test_codebook_prompt_has_markers_and_all_codes():
    p = tl.codebook_prompt(ROOT)
    for c in tl.REASON_CODES:
        assert c in p
    assert "Explanation:" in tl.build_prompt(p, "x")


def test_require_frozen_blocks_real_mode_only():
    tl.require_frozen({"frozen": False}, "simulated", "x")
    with pytest.raises(RuntimeError):
        tl.require_frozen({"frozen": False}, "real", "x")


def _codes(pids, **over):
    base = {c: 0 for c in tl.REASON_CODES}; base["stance"] = "favors_rivera"
    rows = []
    for i, p in enumerate(pids):
        r = {"pid": p, **base}
        for k, v in over.items():
            r[k] = v[i]
        rows.append(r)
    return pd.DataFrame(rows)


def test_kappa_treats_01_and_true_false_alike():
    assert tl.kappa([1, 0, 1, 0], ["True", "False", "True", "False"]) == 1.0
    assert tl.kappa([1, 0, 1, 0], [True, False, True, False]) == 1.0
    assert np.isnan(tl.kappa([0, 0, 0], [0, 0, 0]))                    # undefined, not a pass
    assert tl.kappa(["a", "b", "a"], ["a", "b", "a"], categorical=True) == 1.0


def test_reliability_gate_retains_reason_codes_only_and_applies_test_check():
    pids = [f"p{i}" for i in range(40)]
    perm = [i % 2 for i in range(40)]; remedy = [(i // 2) % 2 for i in range(40)]
    stance = ["favors_rivera" if i % 3 else "favors_martinez" for i in range(40)]
    h = pd.concat([_codes(pids, permission=perm, remedy=remedy, stance=stance).assign(coder="A"),
                   _codes(pids, permission=perm, remedy=remedy, stance=stance).assign(coder="B")])
    consensus = _codes(pids, permission=perm, remedy=remedy, stance=stance)
    primary = _codes(pids, permission=[bool(x) for x in perm], remedy=[bool(x) for x in remedy], stance=stance)
    dev = tl.reliability_dev(h, consensus, {"gptoss": primary, "claude": primary})
    assert dev.set_index("field").loc["permission", "kappa_humans"] == 1.0
    assert dev.set_index("field").loc["permission", "kappa_gptoss_vs_consensus"] == 1.0
    assert "kappa_claude_vs_consensus" in dev.columns
    assert bool(dev.set_index("field").loc["stance", "retained_dev"]) is False
    assert tl.retained_categories(dev, None) == ["permission", "remedy"]
    bad_remedy = [1 - x for x in remedy][:20]
    test = tl.reliability_test(_codes(pids[:20], permission=perm[:20], remedy=bad_remedy), primary)
    assert tl.retained_categories(dev, test) == ["permission"]


def test_freeze_check_requires_frozen_config():
    with pytest.raises(RuntimeError):
        tl.freeze_check(ROOT, {"frozen": False})
