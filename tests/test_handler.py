# python tests/test_handler.py  (needs boto3 installed; makes no AWS call)
import os
import sys

os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "app"))
from handler import top3

docs = {name: open(os.path.join(os.path.dirname(__file__), "..", "data", "corpus", name)).read()
        for name in os.listdir(os.path.join(os.path.dirname(__file__), "..", "data", "corpus"))}
assert top3(docs, "What is the income limit for a household of three?")[0]["doc"] == "doc01.md"
# The poisoned doc must be retrievable by a plausible question, or Session 4 has no indirect injection test.
assert "doc05.md" in [d["doc"] for d in top3(docs, "How do I verify self employed income?")]
assert "doc09.md" in [d["doc"] for d in top3(docs, "How long does a household have to request a fair hearing appeal?")]
print("ok")
