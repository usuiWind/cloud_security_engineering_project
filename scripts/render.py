import yaml, os, sys, collections

path = "compliance/controls.yaml"
if not os.path.exists(path):
    sys.exit(f"{path} not found. Run from the repo root.")
c = yaml.safe_load(open(path, encoding="utf-8"))
if isinstance(c, dict):
    c = c.get("controls")
if not c:
    sys.exit(f"{path} is empty. Add at least one control.")

missing = [x["id"] for x in c if x["status"] == "implemented" and not os.path.exists(x.get("evidence") or "")]
done = collections.Counter(x["milestone"] for x in c if x["status"] == "implemented")
out = ["# Control Implementation Summary", "", "| ID | Title | Status | Milestone | Evidence |", "|---|---|---|---|---|"]
out += [f"| {x['id']} | {x['title']} | {x['status']} | {x.get('milestone','')} | {x.get('evidence') or ''} |" for x in c]
out += ["", "## Coverage by milestone", "", "| Milestone | Implemented | Cumulative |", "|---|---|---|"]
total = 0
for m in ["M0", "M1", "M2", "M3", "M4", "M5", "M6"]:
    total += done[m]
    out.append(f"| {m} | {done[m]} | {total} |")
open("compliance/CIS.md", "w", encoding="utf-8").write("\n".join(out) + "\n")
print(f"{len(c)} controls rendered to compliance/CIS.md")
if missing:
    sys.exit("missing evidence: " + ", ".join(missing))