"""Freeze the text configuration (registered plan, Section 7.1).

Run once, after the development-stage choices are final, from the repository root:
    python3 Analysis/python/freeze_text_config.py

It refuses to freeze while required fields are unset, records the SHA-256 of
codebook.md and anchors.json, sets frozen = true with today's date, and marks
anchors.json frozen. Then commit Analysis/text_frozen/ and push BEFORE any
test-set analysis; the notebooks and 06_text_statistics.Rmd check both.
"""
import datetime
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import textlib as tl  # noqa: E402

root = tl.repo_root()
fdir = os.path.join(root, "Analysis", "text_frozen")
cfg_path = os.path.join(fdir, "text_config.json")
cfg = json.load(open(cfg_path, encoding="utf-8"))

problems = []
if cfg["embedding_models"]["primary"].get("revision") is None:
    problems.append("embedding_models.primary.revision (pin the Qwen3-Embedding-8B revision)")
for m in cfg["embedding_models"]["checks"]:
    if m["provider"] == "sentence-transformers" and m.get("revision") is None:
        problems.append(f"embedding_models revision for {m['id']}")
if cfg["llm_coders"]["primary"].get("revision") is None:
    problems.append("llm_coders.primary.revision (pin the gpt-oss revision)")
gem = [c for c in cfg["llm_coders"]["checks"] if c["key"] == "gemini"][0]
if not gem.get("id"):
    problems.append("llm_coders gemini id")
if cfg["stm"].get("K") is None:
    problems.append("stm.K (choose on the development set with 06_text_statistics.Rmd, stage = 'development')")
for k in ("mfd2", "emfd"):
    d = cfg["dictionaries"][k]
    try:
        p = tl.dictionary_file(root, cfg, k, download=True) if d.get("sha256") else None
    except Exception:
        p = None
    if not (p and d.get("source")):
        problems.append(f"dictionaries.{k}: file present, source recorded, sha256 matching")
if "draft" in open(os.path.join(fdir, "codebook.md"), encoding="utf-8").read().lower():
    problems.append("codebook.md still says draft (remove the draft status lines once the coders have finalized it)")
if problems:
    sys.exit("Not frozen. Settle these first:\n  - " + "\n  - ".join(problems))

anchors_path = os.path.join(fdir, "anchors.json")
anchors = json.load(open(anchors_path, encoding="utf-8"))
anchors["frozen"] = True
with open(anchors_path, "w", encoding="utf-8") as f:
    json.dump(anchors, f, indent=2, ensure_ascii=False); f.write("\n")

cfg["frozen"] = True
cfg["frozen_date"] = datetime.date.today().isoformat()
cfg["frozen_files_sha256"] = {"_about": cfg["frozen_files_sha256"].get("_about", ""),
                              **{n: tl.sha256_file(os.path.join(fdir, n)) for n in tl.FROZEN_FILES}}
with open(cfg_path, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False); f.write("\n")
print("Frozen on", cfg["frozen_date"], "- now commit Analysis/text_frozen/ and push before analyzing the test set.")
