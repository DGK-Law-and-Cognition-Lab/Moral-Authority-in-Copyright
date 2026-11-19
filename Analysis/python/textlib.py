"""Shared functions for the text analyses (registered plan, Section 7).

Everything that turns an explanation into a number lives here, so the Colab
notebooks stay thin and the logic is covered by tests (Analysis/tests/test_textlib.py).
Statistical tests of these features are run in R (Analysis/06_text_statistics.Rmd).
"""
from __future__ import annotations

import hashlib
import html
import json
import math
import os
import re
from collections import Counter
from typing import Callable, Dict, Iterable, List, Optional, Sequence

import numpy as np
import pandas as pd

# ---------------------------------------------------------------------------
# Paths and configuration
# ---------------------------------------------------------------------------

def repo_root(start: Optional[str] = None) -> str:
    p = os.path.abspath(start or os.getcwd())
    while not os.path.exists(os.path.join(p, "Analysis", "R", "config.R")):
        parent = os.path.dirname(p)
        if parent == p:
            raise FileNotFoundError("repository root not found (looked for Analysis/R/config.R)")
        p = parent
    return p


def load_config(root: str) -> dict:
    with open(os.path.join(root, "Analysis", "text_frozen", "text_config.json"), encoding="utf-8") as f:
        return json.load(f)


def load_anchors(root: str) -> dict:
    with open(os.path.join(root, "Analysis", "text_frozen", "anchors.json"), encoding="utf-8") as f:
        return json.load(f)


def require_frozen(cfg: dict, mode: str, what: str) -> None:
    """Section 7.1: no test-set analysis of real data before the development-stage choices are frozen."""
    if mode == "real" and not cfg.get("frozen"):
        raise RuntimeError(
            f"{what}: the text configuration is not frozen. Finalize it on the development set, set "
            "frozen = true with a date, and commit it before analyzing the test set (plan, Section 7.1).")


def output_dir(root: str, mode: str, *parts: str) -> str:
    assert mode in ("real", "simulated")
    d = os.path.join(root, "Analysis", "output", mode, "text", *parts)
    os.makedirs(d, exist_ok=True)
    return d


def load_text_input(root: str, mode: str) -> pd.DataFrame:
    path = os.path.join(root, "Analysis", "output", mode, "text_input.csv")
    df = pd.read_csv(path, dtype={"pid": str})
    df["Explain_Ruling"] = df["Explain_Ruling"].fillna("")
    return df


def link_drive_outputs(root: str, drive_output: str, modes: Sequence[str]) -> None:
    """Colab: read the data from, and write the results to, the Google Drive copy
    of the repository. Each Analysis/output/<mode> folder of the fresh clone is
    replaced by a link to the Drive copy's folder, after checking that the Drive
    copy's text_input.csv is the file committed in the repository. Messages name
    no absolute paths, so executed notebooks do not record them."""
    import shutil
    for mode in modes:
        assert mode in ("real", "simulated")
        local = os.path.join(root, "Analysis", "output", mode)
        remote = os.path.join(drive_output, mode)
        if os.path.islink(local):
            if os.path.realpath(local) != os.path.realpath(remote):
                raise RuntimeError(f"Analysis/output/{mode} already links to a different folder")
            continue
        theirs = os.path.join(remote, "text_input.csv")
        if not os.path.isfile(theirs):
            raise FileNotFoundError(f"The Drive copy has no Analysis/output/{mode}/text_input.csv; "
                                    "copy the repository to Drive again.")
        ours = os.path.join(local, "text_input.csv")
        if os.path.isfile(ours) and sha256_file(ours) != sha256_file(theirs):
            raise RuntimeError(f"Analysis/output/{mode}/text_input.csv on Drive differs from the committed file; "
                               "copy the repository to Drive again before running.")
        if os.path.isdir(local):
            shutil.rmtree(local)
        os.makedirs(os.path.dirname(local), exist_ok=True)
        os.symlink(remote, local)

# ---------------------------------------------------------------------------
# Tokens and whole-word matching
# ---------------------------------------------------------------------------

TOKEN_RE = re.compile(r"[a-z0-9]+(?:['’][a-z0-9]+)*")


def tokens(text: str) -> List[str]:
    """Lower-cased word tokens. Apostrophes inside a word are kept (don't,
    rivera's); hyphens separate words (well-known -> well, known), so a listed
    word is found inside hyphenated compounds such as world-famous. Curly
    apostrophes are normalized to straight ones."""
    t = (text or "").lower().replace("’", "'")
    return TOKEN_RE.findall(t)


def _term_tokens(term: str) -> List[str]:
    return tokens(term)


def count_terms(text: str, terms: Iterable[str]) -> int:
    """Number of matches of `terms` in `text`: whole words, case-insensitive,
    longer phrases first, and no token counted twice."""
    toks = tokens(text)
    used = [False] * len(toks)
    phrases = sorted({tuple(_term_tokens(t)) for t in terms if _term_tokens(t)}, key=len, reverse=True)
    n = 0
    for ph in phrases:
        L = len(ph)
        i = 0
        while i <= len(toks) - L:
            if tuple(toks[i:i + L]) == ph and not any(used[i:i + L]):
                for j in range(i, i + L):
                    used[j] = True
                n += 1
                i += L
            else:
                i += 1
    return n


def mentions_any(text: str, terms: Iterable[str]) -> bool:
    return count_terms(text, terms) > 0


def _mask_order(terms: Iterable[str]) -> List[str]:
    """Deterministic order: more words first, then longer strings, then
    alphabetical (so 'world-renowned' is always replaced before 'renowned')."""
    uniq = {t.strip() for t in terms if t and t.strip()}
    return sorted(uniq, key=lambda t: (-len(re.split(r"[\s\-]+", t)), -len(t), t.lower()))


def mask_text(text: str, terms: Iterable[str], token: str = "[MASK]") -> str:
    """Replace every whole-word, case-insensitive match of `terms` with `token`.
    Words inside a term may be separated in the text by spaces or hyphens
    ('well known' matches 'well-known'). A hyphen counts as a word boundary, so
    'famous' is masked inside 'world-famous' (giving 'world-[MASK]') unless the
    compound itself is listed, in which case the whole compound is masked."""
    out = text or ""
    for term in _mask_order(terms):
        words = [re.escape(w) for w in re.split(r"[\s\-]+", term)]
        pat = r"(?<![A-Za-z0-9'’])" + r"[\s\-]+".join(words) + r"(?![A-Za-z0-9'’])"
        out = re.sub(pat, token, out, flags=re.IGNORECASE)
    return out

# ---------------------------------------------------------------------------
# Passive voice (spaCy)
# ---------------------------------------------------------------------------

SUBJ_DEPS = {"nsubj", "nsubjpass", "csubj", "csubjpass", "expl"}
PASSIVE_DEPS = {"nsubjpass", "csubjpass", "auxpass"}


def clause_counts(doc) -> Dict[str, int]:
    """Count finite-verb clauses and passive clauses in a spaCy Doc.
    A clause is a verb or copula (VERB or AUX) that has a subject child or is
    the root of a sentence; auxiliaries attached to another verb (aux, auxpass)
    are not clauses. A clause is passive if any child has an nsubjpass,
    csubjpass, or auxpass dependency."""
    clauses = passive = 0
    for tok in doc:
        if tok.pos_ not in ("VERB", "AUX"):
            continue
        child_deps = {c.dep_ for c in tok.children}
        is_clause = bool(child_deps & SUBJ_DEPS) or tok.dep_ == "ROOT"
        if not is_clause:
            continue
        if tok.dep_ in ("aux", "auxpass"):
            continue  # an auxiliary attached to a main verb belongs to that verb's clause
        clauses += 1
        if child_deps & PASSIVE_DEPS:
            passive += 1
    return {"clauses": clauses, "passive_clauses": passive}

# ---------------------------------------------------------------------------
# Data quality (Section 7.6): flagged and counted, never excluded
# ---------------------------------------------------------------------------

def vignette_texts(root: str) -> List[str]:
    """The vignette and transformation texts participants read, taken from the survey files."""
    texts = []
    for n in (1, 2):
        path = os.path.join(root, "Experiment", f"Study{n}_FairUseAuthority.qsf")
        with open(path, encoding="utf-8") as f:
            q = json.load(f)
        els = q["SurveyElements"]
        blocks = [e for e in els if e["Element"] == "BL"][0]["Payload"]
        blocks = list(blocks.values()) if isinstance(blocks, dict) else blocks
        qs = {e["PrimaryAttribute"]: e["Payload"] for e in els if e["Element"] == "SQ"}
        for b in blocks:
            if str(b.get("Description", "")).startswith("Condition"):
                for be in b.get("BlockElements", []):
                    if be.get("Type") == "Question" and be["QuestionID"] in qs:
                        texts.append(_clean_html(qs[be["QuestionID"]]["QuestionText"]))
        def walk(node):
            if isinstance(node, dict):
                if node.get("Field") == "TransformText" and node.get("Value"):
                    texts.append(_clean_html(node["Value"]))
                for v in node.values():
                    walk(v)
            elif isinstance(node, list):
                for v in node:
                    walk(v)
        walk([e for e in els if e["Element"] == "FL"][0]["Payload"])
    return [t for t in texts if t]


def _clean_html(t: str) -> str:
    t = re.sub(r"\$\{[^}]*\}", " ", t)
    return re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", html.unescape(t))).strip()


def ngrams(toks: Sequence[str], n: int) -> set:
    return {tuple(toks[i:i + n]) for i in range(len(toks) - n + 1)}


def copy_share(text: str, source_ngrams: set, n: int) -> float:
    """Share of the response's n-grams that also occur in the vignette texts."""
    g = ngrams(tokens(text), n)
    return (len(g & source_ngrams) / len(g)) if g else 0.0


def quality_flags(text: str, source_ngrams: set, n: int, threshold: float, english_vocab: Optional[set] = None) -> Dict[str, object]:
    toks = tokens(text)
    flags = {"copies_vignette": copy_share(text, source_ngrams, n) >= threshold}
    case_words = {"martinez", "rivera", "photo", "photograph", "art", "artist", "artwork", "permission",
                  "copyright", "fair", "use", "work", "image", "picture", "pay", "credit", "money", "sell",
                  "sold", "original", "photographer", "he", "she", "they", "law", "legal", "rights"}
    flags["off_topic"] = len(toks) >= 3 and not (set(toks) & case_words)
    if english_vocab is not None and toks:
        flags["not_english"] = sum(t in english_vocab for t in toks) / len(toks) < 0.5
    else:
        flags["not_english"] = None
    return flags

# ---------------------------------------------------------------------------
# Dictionaries (Section 7.6): LIWC-style .dic (MFD 2.0) and weighted CSV (eMFD)
# ---------------------------------------------------------------------------

def read_dic(path: str) -> Dict[str, List[str]]:
    """Parse a LIWC-format .dic file: a %-delimited category header, then
    'word<TAB>cat_id [cat_id ...]' lines. Words may end in '*' (prefix match)."""
    with open(path, encoding="utf-8-sig") as f:
        lines = [ln.rstrip("\n") for ln in f]
    pct = [i for i, ln in enumerate(lines) if ln.strip() == "%"]
    if len(pct) < 2:
        raise ValueError(f"{path}: not a LIWC .dic file")
    cats = {}
    for ln in lines[pct[0] + 1:pct[1]]:
        if ln.strip():
            k, v = ln.split(None, 1)
            cats[k] = v.strip()
    out: Dict[str, List[str]] = {v: [] for v in cats.values()}
    for ln in lines[pct[1] + 1:]:
        parts = ln.split()
        if len(parts) < 2:
            continue
        word, ids = parts[0].lower(), parts[1:]
        for i in ids:
            if i in cats:
                out[cats[i]].append(word)
    return out


def dic_scores(text: str, dic: Dict[str, List[str]]) -> Dict[str, float]:
    """Per-category share of word tokens that match (exact or '*' prefix)."""
    toks = tokens(text)
    res = {}
    for cat, words in dic.items():
        exact = {w for w in words if not w.endswith("*")}
        prefixes = tuple(w[:-1] for w in words if w.endswith("*"))
        hits = sum(1 for t in toks if t in exact or (prefixes and t.startswith(prefixes)))
        res[cat] = hits / len(toks) if toks else 0.0
    return res


def weighted_scores(text: str, table: pd.DataFrame, word_col: str = "word") -> Dict[str, float]:
    """Mean of the per-word weights over matched tokens (eMFD-style scoring);
    0 for a category when no token matches."""
    toks = tokens(text)
    w = table.set_index(table[word_col].str.lower())
    matched = [t for t in toks if t in w.index]
    cols = [c for c in table.columns if c != word_col]
    if not matched:
        return {c: 0.0 for c in cols}
    sub = w.loc[matched, cols]
    return {c: float(sub[c].mean()) for c in cols}

# ---------------------------------------------------------------------------
# Embeddings
# ---------------------------------------------------------------------------

def l2_normalize(X: np.ndarray) -> np.ndarray:
    X = np.asarray(X, dtype=np.float64)
    n = np.linalg.norm(X, axis=1, keepdims=True)
    n[n == 0] = 1.0
    return X / n


def hash_embed(texts: Sequence[str], dim: int = 256, seed: int = 2025) -> np.ndarray:
    """SIMULATED-MODE STAND-IN, not a language model: a deterministic feature-hashing
    embedding of unigrams and bigrams, used only so the pipeline can be tested
    end to end on synthetic data without a GPU or API keys."""
    X = np.zeros((len(texts), dim))
    for i, t in enumerate(texts):
        toks = tokens(t)
        feats = toks + [a + "_" + b for a, b in zip(toks, toks[1:])]
        for ft in feats:
            h = int(hashlib.sha256(f"{seed}:{ft}".encode()).hexdigest(), 16)
            X[i, h % dim] += 1.0 if (h >> 64) % 2 == 0 else -1.0
    return l2_normalize(X)


def ddr_scores(doc_emb: np.ndarray, pole_a_emb: np.ndarray, pole_b_emb: np.ndarray) -> np.ndarray:
    """Distributed dictionary representation axis score:
    cos(doc, mean of pole A anchors) - cos(doc, mean of pole B anchors)."""
    D = l2_normalize(doc_emb)
    a = l2_normalize(np.asarray(pole_a_emb).mean(axis=0, keepdims=True))[0]
    b = l2_normalize(np.asarray(pole_b_emb).mean(axis=0, keepdims=True))[0]
    return D @ a - D @ b

# ---------------------------------------------------------------------------
# Decoding classifier (Section 7.4, effect size)
# ---------------------------------------------------------------------------

def decoding_accuracy(X: np.ndarray, y: Sequence, folds: int = 10, repeats: int = 10,
                      n_permutations: int = 1000, C: float = 1.0, seed: int = 2025, n_jobs: int = -1) -> Dict[str, float]:
    """Cross-validated accuracy of an L2-penalized logistic regression on
    standardized embeddings (folds x repeats), and a permutation test
    (`n_permutations` label shuffles, each scored with one stratified folds-fold
    split). Returns mean accuracy, its SD across repeats, chance (majority
    class share), and the permutation p value with the accuracy of the single
    split it is based on. Fits run in parallel (n_jobs);
    the folds and permutations come from `seed`, so results do not depend on n_jobs."""
    from sklearn.linear_model import LogisticRegression
    from sklearn.model_selection import RepeatedStratifiedKFold, StratifiedKFold, cross_val_score, permutation_test_score
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import StandardScaler

    y = np.asarray(y)
    pipe = make_pipeline(StandardScaler(), LogisticRegression(C=C, max_iter=5000))
    rcv = RepeatedStratifiedKFold(n_splits=folds, n_repeats=repeats, random_state=seed)
    scores = cross_val_score(pipe, X, y, cv=rcv, scoring="accuracy", n_jobs=n_jobs)
    by_repeat = scores.reshape(repeats, folds).mean(axis=1)
    perm_observed, perm_scores, p = permutation_test_score(
        pipe, X, y, cv=StratifiedKFold(n_splits=folds, shuffle=True, random_state=seed),
        n_permutations=n_permutations, scoring="accuracy", random_state=seed, n_jobs=n_jobs)
    return {"accuracy": float(scores.mean()), "accuracy_sd_repeats": float(by_repeat.std(ddof=1)) if repeats > 1 else float("nan"),
            "chance": float(pd.Series(y).value_counts(normalize=True).max()),
            "permutation_observed_accuracy": float(perm_observed),
            "permutation_mean": float(perm_scores.mean()), "permutation_p": float(p),
            "n": int(len(y)), "folds": folds, "repeats": repeats, "n_permutations": n_permutations}

# ---------------------------------------------------------------------------
# Words that separate conditions (Monroe, Colaresi & Quinn, 2008)
# ---------------------------------------------------------------------------

def log_odds_dirichlet(texts_i: Sequence[str], texts_j: Sequence[str], prior_texts: Sequence[str],
                       min_count: int = 3) -> pd.DataFrame:
    """Weighted log-odds ratios with an informative Dirichlet prior. The prior
    counts are the word counts of `prior_texts` (here: all explanations). Positive
    z = more typical of group i."""
    ci, cj, cp = Counter(), Counter(), Counter()
    for t in texts_i: ci.update(tokens(t))
    for t in texts_j: cj.update(tokens(t))
    for t in prior_texts: cp.update(tokens(t))
    ni, nj, a0 = sum(ci.values()), sum(cj.values()), sum(cp.values())
    rows = []
    for w, aw in cp.items():
        yi, yj = ci.get(w, 0), cj.get(w, 0)
        if yi + yj < min_count:
            continue
        d = (math.log((yi + aw) / (ni + a0 - yi - aw)) - math.log((yj + aw) / (nj + a0 - yj - aw)))
        var = 1.0 / (yi + aw) + 1.0 / (yj + aw)
        rows.append({"word": w, "count_i": yi, "count_j": yj, "delta": d, "z": d / math.sqrt(var)})
    return pd.DataFrame(rows).sort_values("z", ascending=False).reset_index(drop=True)

# ---------------------------------------------------------------------------
# BERTopic stability (Section 7.6)
# ---------------------------------------------------------------------------

def bertopic_assignments(texts: Sequence[str], embeddings: np.ndarray, seed: int, min_topic_size: int = 10) -> np.ndarray:
    from bertopic import BERTopic
    from umap import UMAP
    umap_model = UMAP(n_neighbors=15, n_components=5, min_dist=0.0, metric="cosine", random_state=seed)
    tm = BERTopic(umap_model=umap_model, min_topic_size=min_topic_size, calculate_probabilities=False, verbose=False)
    topics, _ = tm.fit_transform(list(texts), embeddings)
    return np.asarray(topics), tm


def topic_stability(assignments: List[np.ndarray]) -> Dict[str, float]:
    from itertools import combinations
    from sklearn.metrics import adjusted_rand_score
    aris = [adjusted_rand_score(a, b) for a, b in combinations(assignments, 2)]
    return {"mean_ari": float(np.mean(aris)), "min_ari": float(np.min(aris)), "max_ari": float(np.max(aris)), "pairs": len(aris)}

# ---------------------------------------------------------------------------
# Language-model coding (Section 7.5)
# ---------------------------------------------------------------------------

REASON_CODES = ["permission", "transformation", "nature_of_work", "amount_used", "market_effect", "profit",
                "credit", "nonmonetary_harm", "fame_status_power", "fairness_moral", "law_rules", "remedy"]
STANCES = ["favors_rivera", "favors_martinez", "mixed_or_unclear"]
SENTIMENTS = ["negative", "neutral", "positive", "not_mentioned"]

CODING_SCHEMA = {
    "type": "object",
    "properties": {
        **{c: {"type": "boolean"} for c in REASON_CODES},
        "stance": {"type": "string", "enum": STANCES},
        "sentiment_martinez": {"type": "string", "enum": SENTIMENTS},
        "sentiment_rivera": {"type": "string", "enum": SENTIMENTS},
    },
    "required": REASON_CODES + ["stance", "sentiment_martinez", "sentiment_rivera"],
    "additionalProperties": False,
}


def codebook_prompt(root: str) -> str:
    with open(os.path.join(root, "Analysis", "text_frozen", "codebook.md"), encoding="utf-8") as f:
        md = f.read()
    m = re.search(r"<!-- PROMPT START -->(.*?)<!-- PROMPT END -->", md, flags=re.S)
    if not m:
        raise ValueError("codebook.md has no PROMPT START/END markers")
    return m.group(1).strip()


def build_prompt(codebook: str, explanation: str) -> str:
    keys = ", ".join(f'"{k}"' for k in CODING_SCHEMA["required"])
    return (f"{codebook}\n\nReturn a JSON object with exactly these keys: {keys}. The twelve reason codes are "
            f"true or false; stance is one of {STANCES}; each sentiment is one of {SENTIMENTS}.\n\n"
            f"Explanation:\n<<<\n{explanation}\n>>>")


def parse_coding(raw: str) -> dict:
    """Parse and validate one coder output. Accepts a bare JSON object, or text
    that contains exactly one JSON object (some open models wrap it). Raises
    ValueError if it does not match CODING_SCHEMA."""
    import jsonschema
    s = (raw or "").strip()
    try:
        obj = json.loads(s)
    except json.JSONDecodeError:
        found = re.findall(r"\{.*\}", s, flags=re.S)
        if len(found) != 1:
            raise ValueError("no single JSON object in output")
        obj = json.loads(found[0])
    try:
        jsonschema.validate(obj, CODING_SCHEMA)
    except jsonschema.ValidationError as e:
        raise ValueError(f"schema violation: {e.message}") from e
    return obj


def majority(runs: Sequence[Optional[dict]]) -> Optional[dict]:
    """Majority code across repeated runs of one coder. Failed runs (None) are
    ignored. Boolean ties (possible with two valid runs) resolve to False;
    categorical ties resolve to 'mixed_or_unclear' (stance) or 'neutral'
    (sentiment). Returns None if no run succeeded."""
    ok = [r for r in runs if r is not None]
    if not ok:
        return None
    out = {}
    for c in REASON_CODES:
        t = sum(bool(r[c]) for r in ok)
        out[c] = t > len(ok) - t
    for key, tie in (("stance", "mixed_or_unclear"), ("sentiment_martinez", "neutral"), ("sentiment_rivera", "neutral")):
        cnt = Counter(r[key] for r in ok).most_common()
        out[key] = cnt[0][0] if len(cnt) == 1 or cnt[0][1] > cnt[1][1] else tie
    out["n_valid_runs"] = len(ok)
    return out


def run_agreement(runs_by_item: Sequence[Sequence[Optional[dict]]]) -> pd.DataFrame:
    """Share of items on which all valid runs gave the same code, per field."""
    fields = REASON_CODES + ["stance", "sentiment_martinez", "sentiment_rivera"]
    rows = []
    for f in fields:
        agree = [len({r[f] for r in runs if r is not None}) == 1 for runs in runs_by_item
                 if sum(r is not None for r in runs) >= 2]
        rows.append({"field": f, "items": len(agree), "share_all_runs_agree": float(np.mean(agree)) if agree else float("nan")})
    return pd.DataFrame(rows)


def simulated_coder(explanation: str) -> dict:
    """SIMULATED-MODE STAND-IN, not a language model: keyword rules that return a
    schema-valid coding so the pipeline can be tested without a model."""
    t = explanation.lower()
    has = lambda *ws: any(re.search(r"\b" + re.escape(w) + r"\b", t) for w in ws)
    out = {
        "permission": has("permission", "ask", "asked", "consent"),
        "transformation": has("transformative", "different", "changed", "copy", "identical", "creativity"),
        "nature_of_work": has("photograph is", "creative work"),
        "amount_used": has("complete", "whole", "portion", "part of"),
        "market_effect": has("income", "market", "sales", "lose"),
        "profit": has("profit", "profits", "money", "sold"),
        "credit": has("credit"),
        "nonmonetary_harm": has("reputation", "hurt", "feelings"),
        "fame_status_power": has("famous", "unknown", "small artist", "status"),
        "fairness_moral": has("wrong", "unfair", "fair", "stealing"),
        "law_rules": has("law", "legal", "fair use", "copyright"),
        "remedy": has("should pay", "give credit", "share the profits", "should have been asked"),
    }
    out["stance"] = ("favors_rivera" if has("permission", "wrong", "owns") else
                     "favors_martinez" if has("transformative", "creativity", "builds on") else "mixed_or_unclear")
    out["sentiment_martinez"] = "negative" if out["stance"] == "favors_rivera" else "neutral"
    out["sentiment_rivera"] = "neutral"
    return out


# ---------------------------------------------------------------------------
# Reliability gate (Section 7.5)
# ---------------------------------------------------------------------------

def as01(values) -> np.ndarray:
    """Map True/False, 'True'/'False', 'true'/'false', 1/0 and '1'/'0' to 1/0; anything else to NaN."""
    m = {"true": 1, "false": 0, "1": 1, "0": 0, "1.0": 1, "0.0": 0}
    return np.array([m.get(str(v).strip().lower(), np.nan) for v in values], dtype=float)


def kappa(a, b, categorical: bool = False) -> float:
    """Cohen's kappa on paired codes. Booleans are compared as 0/1 whatever their
    spelling; categorical fields as strings. Pairs with a missing code are dropped.
    Returns NaN when kappa is undefined (one code used throughout by both)."""
    from sklearn.metrics import cohen_kappa_score
    if categorical:
        x = pd.Series(list(a), dtype=object); y = pd.Series(list(b), dtype=object)
        ok = x.notna() & y.notna() & (x.astype(str) != "nan") & (y.astype(str) != "nan")
        x, y = x[ok].astype(str), y[ok].astype(str)
    else:
        x, y = as01(a), as01(b)
        ok = ~np.isnan(x) & ~np.isnan(y)
        x, y = x[ok].astype(int), y[ok].astype(int)
    if len(x) == 0 or (len(set(x)) == 1 and len(set(y)) == 1):
        return float("nan")
    return float(cohen_kappa_score(x, y))


GATE_FIELDS = REASON_CODES + ["stance"]


def _aligned(a: pd.DataFrame, b: pd.DataFrame):
    a = a.drop_duplicates("pid").set_index("pid"); b = b.drop_duplicates("pid").set_index("pid")
    common = a.index.intersection(b.index)
    return a.loc[common], b.loc[common]


def reliability_dev(h_ind: pd.DataFrame, consensus: pd.DataFrame, coders: Dict[str, pd.DataFrame],
                    primary: str = "gptoss", threshold: float = 0.70) -> pd.DataFrame:
    """Development-set gate. `h_ind`: the two humans' independent codes (columns
    pid, coder, fields). `consensus`: the resolved human code for every item
    (pid, fields), after discussion. `coders`: majority codes per model. A
    reason code is retained at this stage if kappa between the humans and kappa
    between the primary coder and the consensus are both >= threshold. Stance is
    reported but is not a reason code and is never retained."""
    names = sorted(h_ind["coder"].unique())
    if len(names) != 2:
        raise ValueError("need exactly two human coders in the independent file")
    h1, h2 = _aligned(h_ind[h_ind.coder == names[0]], h_ind[h_ind.coder == names[1]])
    rows = []
    for f in GATE_FIELDS:
        cat = f == "stance"
        r = {"field": f, "n_humans": len(h1), "kappa_humans": kappa(h1[f], h2[f], cat)}
        for k, df in coders.items():
            c, m = _aligned(consensus, df)
            r[f"n_{k}"] = len(c)
            r[f"kappa_{k}_vs_consensus"] = kappa(c[f], m[f], cat)
        r["retained_dev"] = (f in REASON_CODES and r["kappa_humans"] >= threshold
                             and r[f"kappa_{primary}_vs_consensus"] >= threshold)
        rows.append(r)
    return pd.DataFrame(rows)


def reliability_test(h_test: pd.DataFrame, primary_codes: pd.DataFrame, threshold: float = 0.70) -> pd.DataFrame:
    """Test-set check: one human codes a random 100 test responses; a category
    passes if kappa between that human and the primary coder is >= threshold."""
    h, m = _aligned(h_test, primary_codes)
    rows = []
    for f in GATE_FIELDS:
        k = kappa(h[f], m[f], f == "stance")
        rows.append({"field": f, "n_test": len(h), "kappa_primary_vs_test_human": k,
                     "passes_test": f in REASON_CODES and k >= threshold})
    return pd.DataFrame(rows)


def retained_categories(dev: pd.DataFrame, test: Optional[pd.DataFrame]) -> List[str]:
    keep = set(dev.loc[dev.retained_dev, "field"])
    if test is not None:
        keep &= set(test.loc[test.passes_test, "field"])
    return [c for c in REASON_CODES if c in keep]

# ---------------------------------------------------------------------------
# Freeze integrity (Section 7.1)
# ---------------------------------------------------------------------------

FROZEN_FILES = ["codebook.md", "anchors.json"]


def sha256_file(path: str) -> str:
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def freeze_check(root: str, cfg: dict) -> dict:
    """For real-mode test-set work: the configuration must be frozen, the frozen
    files must match the SHA-256 values recorded in text_config.json, and
    Analysis/text_frozen must have no uncommitted changes. Returns the commit."""
    import subprocess
    if not cfg.get("frozen"):
        raise RuntimeError("text_config.json is not frozen (plan, Section 7.1)")
    rec = cfg.get("frozen_files_sha256") or {}
    for name in FROZEN_FILES:
        got = sha256_file(os.path.join(root, "Analysis", "text_frozen", name))
        if rec.get(name) != got:
            raise RuntimeError(f"{name} does not match the SHA-256 recorded when the configuration was frozen")
    dirty = subprocess.run(["git", "-C", root, "status", "--porcelain", "--", "Analysis/text_frozen"],
                           capture_output=True, text=True, check=True).stdout.strip()
    if dirty:
        raise RuntimeError("Analysis/text_frozen has uncommitted changes:\n" + dirty)
    head = subprocess.run(["git", "-C", root, "rev-parse", "HEAD"], capture_output=True, text=True, check=True).stdout.strip()
    return {"commit": head}
