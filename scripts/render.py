import yaml, os, sys, collections

c = yaml.safe_load(open("compliance/controls.yaml"))
missing = [x["id"] for x in c if x["status"] == "implemented" and not os.path.exists(x.get("evidence") or "")]
done = collections.Counter(x["milestone"] for x in c if x["status"] == "implemented")
out = ["# Control Implementation Summary", "", "| ID | Title | Status | Milestone | Evidence |", "|---|---|---|---|---|"]
out += [f"| {x['id']} | {x['title']} | {x['status']} | {x.get('milestone','')} | {x.get('evidence') or ''} |" for x in c]
out += ["", "## Coverage by milestone", "", "| Milestone | Implemented | Cumulative |", "|---|---|---|"]
total = 0
for m in ["M0", "M1", "M2", "M3", "M4", "M5", "M6"]:
    total += done[m]
    out.append(f"| {m} | {done[m]} | {total} |")
open("compliance/CIS.md", "w").write("\n".join(out) + "\n")
if missing:
    sys.exit("missing evidence: " + ", ".join(missing))
print("wrote compliance/CIS.md")