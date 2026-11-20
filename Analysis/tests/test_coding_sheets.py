"""Tests for the human-coding sheets. Run from the repository root:
    python3 -m pytest Analysis/tests
They use the simulated data only."""
import os
import sys

import numpy as np
import pandas as pd
import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "python"))
import coding_sheets as cs  # noqa: E402
import textlib as tl  # noqa: E402

ROOT = tl.repo_root(HERE)
TI = tl.load_text_input(ROOT, "simulated")
SEED = tl.load_config(ROOT)["seed"]


def test_codebook_definitions_match_the_code_list():
    codes, stances, story = cs.codebook_definitions(ROOT)
    assert [c[0] for c in codes] == tl.REASON_CODES
    assert [s[0] for s in stances] == tl.STANCES
    assert all(len(d) > 10 for _, d in codes)
    assert "Martinez" in story and "famous" not in story.lower()   # no condition information


def test_draw_is_reproducible_proportional_and_development_only():
    k1, alloc = cs.draw_dev_samples(TI, SEED)
    k2, _ = cs.draw_dev_samples(TI, SEED)
    pd.testing.assert_frame_equal(k1, k2)
    dev = TI[(TI.text_set == "dev") & TI.text_ok]
    d, p = k1[k1.item.str.startswith("D")], k1[k1.item.str.startswith("P")]
    assert len(d) == 200 and len(p) == 20
    assert d.pid.is_unique and p.pid.is_unique and not set(d.pid) & set(p.pid)
    assert set(k1.pid) <= set(dev.pid)
    sizes = dev.assign(s=cs._strata(dev)).groupby("s").size()
    quota = sizes / sizes.sum() * 200
    assert alloc.sum() == 200
    assert ((alloc >= np.floor(quota)) & (alloc <= np.ceil(quota))).all()
    drawn = dev.set_index("pid").loc[d.pid]
    assert (cs._strata(drawn.reset_index()).value_counts().sort_index() == alloc[alloc > 0].sort_index()).all()


def _fill(path, rng, blank_item=None):
    from openpyxl import load_workbook
    wb = load_workbook(path)
    ws = wb["Coding"]
    header = [c.value for c in ws[1]]
    truth = {}
    for r in range(2, ws.max_row + 1):
        item = ws.cell(row=r, column=1).value
        codes = rng.integers(0, 2, size=len(tl.REASON_CODES)).tolist()
        stance = tl.STANCES[int(rng.integers(0, 3))]
        for j, v in enumerate(codes):
            # half the rows as text, as Google Sheets may store them
            ws.cell(row=r, column=header.index(tl.REASON_CODES[j]) + 1, value=str(v) if r % 2 else v)
        ws.cell(row=r, column=header.index("stance") + 1, value=stance)
        truth[item] = codes + [stance]
    if blank_item:
        r = [ws.cell(row=i, column=1).value for i in range(1, ws.max_row + 1)].index(blank_item) + 1
        ws.cell(row=r, column=header.index("credit") + 1).value = None   # cell(value=None) would not clear it
    wb.save(path)
    return truth


def test_workbook_round_trip(tmp_path):
    key, _ = cs.draw_dev_samples(TI, SEED)
    items = key[key.item.str.startswith("D")]
    texts = dict(zip(TI.pid, TI.Explain_Ruling))
    path = str(tmp_path / "a.xlsx")
    cs.write_workbook(path, items, texts, ROOT, "t", "n")
    truth = _fill(path, np.random.default_rng(1))
    got = cs.read_workbook(path)
    assert len(got) == 200
    for _, row in got.iterrows():
        assert row[tl.REASON_CODES].tolist() + [row.stance] == truth[row["item"]]
    m = cs.to_pids(got, key, items.item)
    assert list(m.columns) == ["pid"] + tl.REASON_CODES + ["stance"]
    assert set(m.pid) == set(items.pid)


def test_blank_cell_stops_the_import(tmp_path):
    key, _ = cs.draw_dev_samples(TI, SEED)
    items = key[key.item.str.startswith("D")]
    path = str(tmp_path / "b.xlsx")
    cs.write_workbook(path, items, dict(zip(TI.pid, TI.Explain_Ruling)), ROOT, "t", "n")
    _fill(path, np.random.default_rng(2), blank_item="D007")
    with pytest.raises(ValueError, match="credit: blank or not 1/0 for D007"):
        cs.read_workbook(path)


def test_text_that_looks_like_a_formula_stays_text(tmp_path):
    from openpyxl import load_workbook
    items = pd.DataFrame({"item": ["D001", "D002"], "pid": ["x1", "x2"]})
    texts = {"x1": "=SUM(A1) is not a formula", "x2": "bell\x07 removed"}
    path = str(tmp_path / "c.xlsx")
    cs.write_workbook(path, items, texts, ROOT, "t", "n")
    ws = load_workbook(path)["Coding"]
    assert ws.cell(row=2, column=2).value == "=SUM(A1) is not a formula"
    assert ws.cell(row=2, column=2).data_type == "s"
    assert ws.cell(row=3, column=2).value == "bell removed"


def test_items_must_match_the_key():
    key = pd.DataFrame({"item": ["D001", "D002"], "pid": ["a", "b"]})
    codes = pd.DataFrame({"item": ["D001"], **{c: [0] for c in tl.REASON_CODES}, "stance": ["favors_rivera"]})
    with pytest.raises(ValueError, match="missing"):
        cs.to_pids(codes, key, key.item)
