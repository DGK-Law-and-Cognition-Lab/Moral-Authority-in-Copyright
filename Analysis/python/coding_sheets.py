"""Human-coding sheets for the reason codes (registered plan, Section 7.5).

Run from the repository root.

  python3 Analysis/python/coding_sheets.py draw-dev
      Draws the development-set coding samples (reproducible, seed from
      text_config.json) and writes the item key Analysis/text_frozen/coding_sample_dev.csv:
        - 200 items (D001-D200), stratified by study and condition cell,
          proportional allocation, for the two coders' independent coding;
        - 20 calibration items (P01-P20) from the rest of the development set,
          used only to refine the codebook before the independent coding.
      Responses under three words are set aside, as in every text analysis.

  python3 Analysis/python/coding_sheets.py sheets-dev OUTDIR
      Writes the workbooks to OUTDIR: one calibration workbook and one workbook
      per coder (A, B) for the 200 items. Conditions are never shown. The code
      definitions are read from codebook.md, so coders and language models see
      the same wording. Rerun after the codebook changes; the items stay fixed.

  python3 Analysis/python/coding_sheets.py import-dev SHEET_A SHEET_B [CONSENSUS]
      Reads the returned workbooks and writes human_codes_dev.csv (pid, coder,
      the 12 codes as 0/1, stance) and, if given, human_codes_dev_consensus.csv,
      and prints Cohen's kappa between the coders for each field.
"""
import argparse
import os
import re
import sys
from math import ceil

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import textlib as tl  # noqa: E402

N_DEV_SAMPLE = 200
N_CALIBRATION = 20
CODE_VALUES = {"1": 1, "0": 0, "1.0": 1, "0.0": 0, "true": 1, "false": 0}


# ---------------------------------------------------------------------------
# Codebook (single source for human sheets and language-model prompts)
# ---------------------------------------------------------------------------

def codebook_definitions(root: str):
    """The 12 reason codes and 3 stances, in order, with their definitions, as
    written between the PROMPT markers of codebook.md."""
    text = open(os.path.join(root, "Analysis", "text_frozen", "codebook.md"), encoding="utf-8").read()
    prompt = text.split("<!-- PROMPT START -->", 1)[1].split("<!-- PROMPT END -->", 1)[0]
    codes = re.findall(r"^\s*(\d+)\.\s+([a-z_]+):\s*(.+?)\s*$", prompt, flags=re.M)
    stances = re.findall(r"^\s*-\s+(favors_rivera|favors_martinez|mixed_or_unclear):\s*(.+?)\s*$", prompt, flags=re.M)
    if [c[1] for c in codes] != tl.REASON_CODES or [int(c[0]) for c in codes] != list(range(1, len(tl.REASON_CODES) + 1)):
        raise ValueError("codebook.md reason codes do not match textlib.REASON_CODES (names and order)")
    if [s[0] for s in stances] != tl.STANCES:
        raise ValueError("codebook.md stances do not match textlib.STANCES")
    story = prompt.strip().split("\n\n", 1)[0]
    story = story.replace("You will read one participant's answer", "Each row is one participant's answer")
    return [(c[1], c[2]) for c in codes], stances, story


# ---------------------------------------------------------------------------
# Samples
# ---------------------------------------------------------------------------

def _strata(df: pd.DataFrame) -> pd.Series:
    t = df["transform"].fillna("none").astype(str)
    return df["study"].astype(str) + "|" + df["artist"].astype(str) + "|" + df["victim"].astype(str) + "|" + t


def allocate(sizes: pd.Series, n: int) -> pd.Series:
    """Proportional allocation by largest remainder; ties go to the stratum that
    sorts first, so the result is deterministic."""
    sizes = sizes.sort_index()
    quota = sizes / sizes.sum() * n
    alloc = np.floor(quota).astype(int)
    rem = (quota - alloc).sort_values(ascending=False, kind="mergesort")
    alloc[rem.index[: n - alloc.sum()]] += 1
    if (alloc > sizes).any():
        raise ValueError("a stratum is smaller than its allocation")
    return alloc


def draw_dev_samples(text_input: pd.DataFrame, seed: int, n: int = N_DEV_SAMPLE, n_cal: int = N_CALIBRATION):
    dev = text_input[(text_input["text_set"] == "dev") & text_input["text_ok"]].copy()
    dev = dev.sort_values("pid", kind="mergesort").reset_index(drop=True)
    dev["stratum"] = _strata(dev)
    rng = np.random.Generator(np.random.PCG64(seed))
    alloc = allocate(dev.groupby("stratum").size(), n)
    picked = []
    for s, k in alloc.items():
        pool = dev.index[dev["stratum"] == s].to_numpy()
        picked.extend(rng.choice(pool, size=k, replace=False).tolist())
    picked = rng.permutation(np.array(sorted(picked)))
    sample = pd.DataFrame({"item": [f"D{i:03d}" for i in range(1, n + 1)], "pid": dev.loc[picked, "pid"].to_numpy()})
    rest = dev.index.difference(picked).to_numpy()
    cal_idx = rng.choice(rest, size=n_cal, replace=False)
    cal = pd.DataFrame({"item": [f"P{i:02d}" for i in range(1, n_cal + 1)], "pid": dev.loc[cal_idx, "pid"].to_numpy()})
    sample["purpose"] = "independent coding (kappa)"
    cal["purpose"] = "calibration (codebook refinement only)"
    return pd.concat([sample, cal], ignore_index=True), alloc


# ---------------------------------------------------------------------------
# Workbooks
# ---------------------------------------------------------------------------

def _clean(text: str) -> str:
    from openpyxl.cell.cell import ILLEGAL_CHARACTERS_RE
    return ILLEGAL_CHARACTERS_RE.sub("", str(text))


def write_workbook(path: str, items: pd.DataFrame, texts: dict, root: str, title: str, coder_note: str) -> None:
    from openpyxl import Workbook
    from openpyxl.comments import Comment
    from openpyxl.styles import Alignment, Font, PatternFill
    from openpyxl.worksheet.datavalidation import DataValidation

    codes, stances, story = codebook_definitions(root)
    wb = Workbook()
    bold = Font(bold=True)
    wrap = Alignment(wrap_text=True, vertical="top")

    ins = wb.active
    ins.title = "Instructions"
    lines = [
        (title, True),
        (coder_note, False),
        ("", False),
        ("What you are reading", True),
        (story, False),
        ("", False),
        ("How to code", True),
        ("1. Read each explanation in the Coding tab. Code what the explanation SAYS, not what you think about the case.", False),
        (f"2. For each of the {len(tl.REASON_CODES)} reason codes, enter 1 if the explanation clearly gives that reason and 0 if it does not. "
         "A response can have several 1s. Every cell must be filled. The definitions are in the Codebook tab and in the "
         "note on each column header.", False),
        ("3. Choose one stance: which side the explanation favors.", False),
        ("4. Use the Notes column for anything unclear, or a reason that fits no code.", False),
        ("5. Work on your own. Do not discuss the explanations with the other coder until you have both finished and "
         "returned your files.", False),
        ("6. Do not look up the study, its conditions, or its results.", False),
        ("7. Code by hand. Do not use ChatGPT, Perplexity, Claude, Gemini, or any other AI tool, and do not paste "
         "the explanations into one. Language models are coded separately and compared with your codes, so your "
         "codes must be your own.", False),
        ("8. Edit this file directly. In Google Drive, do not use 'Save as Google Sheets'.", False),
    ]
    for i, (t, b) in enumerate(lines, start=1):
        c = ins.cell(row=i, column=1, value=t)
        c.alignment = wrap
        if b:
            c.font = bold
    ins.column_dimensions["A"].width = 110

    cb = wb.create_sheet("Codebook")
    cb.append(["Column", "Code", "Definition"])
    for i, (name, d) in enumerate(codes, start=1):
        cb.append([name, i, d])
    cb.append([])
    cb.append(["stance", "", "Which side the explanation favors:"])
    for name, d in stances:
        cb.append(["", name, d])
    for cell in cb[1]:
        cell.font = bold
    cb.column_dimensions["A"].width = 20
    cb.column_dimensions["B"].width = 18
    cb.column_dimensions["C"].width = 100
    for row in cb.iter_rows(min_row=2):
        for cell in row:
            cell.alignment = wrap

    ws = wb.create_sheet("Coding")
    header = ["item", "explanation"] + [c[0] for c in codes] + ["stance", "notes"]
    ws.append(header)
    defs = dict(codes)
    for j, h in enumerate(header, start=1):
        cell = ws.cell(row=1, column=j)
        cell.font = bold
        cell.fill = PatternFill("solid", fgColor="DDDDDD")
        if h in defs:
            cell.alignment = Alignment(text_rotation=90, horizontal="center", vertical="bottom")
            cell.comment = Comment(defs[h], "Codebook", width=320, height=120)
        else:
            cell.alignment = Alignment(vertical="bottom")
    ws.row_dimensions[1].height = 120
    width = 80
    for r, (item, pid) in enumerate(zip(items["item"], items["pid"]), start=2):
        text = _clean(texts[pid])
        ws.cell(row=r, column=1, value=item)
        c = ws.cell(row=r, column=2, value=text)
        c.data_type = "s"   # never read as a formula, whatever the first character
        c.alignment = wrap
        n_lines = sum(max(1, ceil(len(p) / (width - 6))) for p in text.split("\n"))
        ws.row_dimensions[r].height = min(400, 15 * n_lines + 4)
        for j in range(3, len(header) + 1):
            ws.cell(row=r, column=j).alignment = Alignment(vertical="top", horizontal="center", wrap_text=True)
    last = len(items) + 1
    ws.column_dimensions["A"].width = 7
    ws.column_dimensions["B"].width = width
    from openpyxl.utils import get_column_letter
    for j in range(3, 3 + len(codes)):
        ws.column_dimensions[get_column_letter(j)].width = 5
    sc = get_column_letter(3 + len(codes))
    nc = get_column_letter(4 + len(codes))
    ws.column_dimensions[sc].width = 18
    ws.column_dimensions[nc].width = 40
    dv = DataValidation(type="list", formula1='"1,0"', allow_blank=True, showErrorMessage=True,
                        errorTitle="1 or 0", error="Enter 1 (the explanation gives this reason) or 0 (it does not).")
    dv.add(f"C2:{get_column_letter(2 + len(codes))}{last}")
    ds = DataValidation(type="list", formula1='"' + ",".join(tl.STANCES) + '"', allow_blank=True,
                        showErrorMessage=True, errorTitle="Stance", error="Choose one stance from the list.")
    ds.add(f"{sc}2:{sc}{last}")
    ws.add_data_validation(dv)
    ws.add_data_validation(ds)
    ws.freeze_panes = "C2"
    wb.active = wb.sheetnames.index("Instructions")
    wb.save(path)


def read_workbook(path: str) -> pd.DataFrame:
    """Read a returned workbook; stop on any blank or invalid entry."""
    from openpyxl import load_workbook
    ws = load_workbook(path, read_only=True, data_only=True)["Coding"]
    rows = list(ws.iter_rows(values_only=True))
    header = [str(h).strip() if h is not None else "" for h in rows[0]]
    need = ["item"] + tl.REASON_CODES + ["stance"]
    missing = [h for h in need if h not in header]
    if missing:
        raise ValueError(f"{os.path.basename(path)}: missing columns {missing}")
    df = pd.DataFrame([r for r in rows[1:] if r and r[header.index("item")]], columns=header)
    problems = []
    for c in tl.REASON_CODES:
        v = df[c].map(lambda x: CODE_VALUES.get(str(x).strip().lower()) if x is not None else None)
        bad = df.loc[v.isna(), "item"].tolist()
        if bad:
            problems.append(f"{c}: blank or not 1/0 for {', '.join(map(str, bad[:10]))}{' ...' if len(bad) > 10 else ''}")
        df[c] = v
    st = df["stance"].map(lambda x: str(x).strip() if x is not None else "")
    bad = df.loc[~st.isin(tl.STANCES), "item"].tolist()
    if bad:
        problems.append(f"stance: blank or invalid for {', '.join(map(str, bad[:10]))}{' ...' if len(bad) > 10 else ''}")
    df["stance"] = st
    if df["item"].duplicated().any():
        problems.append("duplicated items: " + ", ".join(df.loc[df["item"].duplicated(), "item"].astype(str)))
    if problems:
        raise ValueError(f"{os.path.basename(path)} is incomplete:\n  " + "\n  ".join(problems))
    out = df[["item"] + tl.REASON_CODES + ["stance"]].copy()
    out[tl.REASON_CODES] = out[tl.REASON_CODES].astype(int)
    return out


def to_pids(codes: pd.DataFrame, key: pd.DataFrame, expected_items) -> pd.DataFrame:
    got, want = set(codes["item"]), set(expected_items)
    if got != want:
        raise ValueError(f"items differ from the key: missing {sorted(want - got)[:10]}, extra {sorted(got - want)[:10]}")
    m = codes.merge(key[["item", "pid"]], on="item", how="left", validate="one_to_one")
    return m[["pid"] + tl.REASON_CODES + ["stance"]].sort_values("pid", kind="mergesort").reset_index(drop=True)


# ---------------------------------------------------------------------------
# Command line
# ---------------------------------------------------------------------------

def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("command", choices=["draw-dev", "sheets-dev", "import-dev"])
    p.add_argument("paths", nargs="*")
    p.add_argument("--mode", default="real", choices=["real", "simulated"])
    p.add_argument("--root", default=None)
    a = p.parse_args(argv)
    root = a.root or tl.repo_root()
    fdir = os.path.join(root, "Analysis", "text_frozen")
    key_path = os.path.join(fdir, "coding_sample_dev.csv" if a.mode == "real" else "coding_sample_dev__simulated.csv")
    ti = tl.load_text_input(root, a.mode)

    if a.command == "draw-dev":
        if os.path.exists(key_path):
            sys.exit(f"{os.path.relpath(key_path, root)} already exists; the sample is drawn once. Delete it only "
                     "if it has never been used.")
        cfg = tl.load_config(root)
        key, alloc = draw_dev_samples(ti, cfg["seed"])
        key.to_csv(key_path, index=False)
        print(f"Wrote {os.path.relpath(key_path, root)}: {sum(key.item.str.startswith('D'))} items for independent "
              f"coding, {sum(key.item.str.startswith('P'))} for calibration.")
        print("Allocation (study|artist|victim|transform):")
        print(alloc.to_string())
        return

    key = pd.read_csv(key_path, dtype=str)
    texts = dict(zip(ti["pid"].astype(str), ti["Explain_Ruling"]))

    if a.command == "sheets-dev":
        if len(a.paths) != 1:
            sys.exit("usage: sheets-dev OUTDIR")
        out = a.paths[0]
        os.makedirs(out, exist_ok=True)
        cal = key[key["item"].str.startswith("P")]
        dev = key[key["item"].str.startswith("D")]
        files = {
            os.path.join(out, "Calibration (share with both coders)", "Calibration - 20 practice explanations.xlsx"):
                (cal, "Calibration: 20 practice explanations",
                 "Code these together or separately, then discuss them with the other coder and agree on any changes "
                 "to the codebook. These 20 are not used in any result."),
            os.path.join(out, "Coder A (share with Coder A only)", "Coder A - 200 explanations.xlsx"):
                (dev, "Independent coding: 200 explanations (Coder A)",
                 "Start after the calibration round and any codebook changes. Code all 200 on your own."),
            os.path.join(out, "Coder B (share with Coder B only)", "Coder B - 200 explanations.xlsx"):
                (dev, "Independent coding: 200 explanations (Coder B)",
                 "Start after the calibration round and any codebook changes. Code all 200 on your own."),
        }
        for path, (items, title, note) in files.items():
            os.makedirs(os.path.dirname(path), exist_ok=True)
            write_workbook(path, items, texts, root, title, note)
            print("Wrote", os.path.join(os.path.basename(os.path.dirname(path)), os.path.basename(path)))
        return

    if a.command == "import-dev":
        if len(a.paths) not in (2, 3):
            sys.exit("usage: import-dev SHEET_A SHEET_B [CONSENSUS]")
        dev_items = key.loc[key["item"].str.startswith("D"), "item"]
        frames = []
        for coder, path in zip(["A", "B"], a.paths[:2]):
            d = to_pids(read_workbook(path), key, dev_items)
            d.insert(1, "coder", coder)
            frames.append(d)
        ind = pd.concat(frames, ignore_index=True)
        suffix = "" if a.mode == "real" else "__simulated"
        ind.to_csv(os.path.join(fdir, f"human_codes_dev{suffix}.csv"), index=False)
        print(f"Wrote human_codes_dev{suffix}.csv ({len(ind)} rows). Kappa between the two coders:")
        h1, h2 = frames[0].set_index("pid"), frames[1].set_index("pid").loc[frames[0]["pid"]]
        for f in tl.GATE_FIELDS:
            print(f"  {f:20s} {tl.kappa(h1[f], h2[f], f == 'stance'):.3f}")
        if len(a.paths) == 3:
            con = to_pids(read_workbook(a.paths[2]), key, dev_items)
            con.to_csv(os.path.join(fdir, f"human_codes_dev_consensus{suffix}.csv"), index=False)
            print(f"Wrote human_codes_dev_consensus{suffix}.csv ({len(con)} rows).")


if __name__ == "__main__":
    main()
