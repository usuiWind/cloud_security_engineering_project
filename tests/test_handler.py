# python tests/test_handler.py  (needs boto3 installed; makes no AWS or Gemini call)
import io
import json
import os
import sys
import urllib.error

os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "app"))
import gateway  # noqa: E402
import handler  # noqa: E402
from handler import top3  # noqa: E402

docs = {name: open(os.path.join(os.path.dirname(__file__), "..", "data", "corpus", name)).read()
        for name in os.listdir(os.path.join(os.path.dirname(__file__), "..", "data", "corpus"))}
assert top3(docs, "What is the income limit for a household of three?")[0]["doc"] == "doc01.md"
# The poisoned doc must be retrievable by a plausible question, or Session 4 has no indirect injection test.
assert "doc05.md" in [d["doc"] for d in top3(docs, "How do I verify self employed income?")]
assert "doc09.md" in [d["doc"] for d in top3(docs, "How long does a household have to request a fair hearing appeal?")]

# The loop, with a stub gateway: one tool call, then an answer. The tool result goes back as role "tool".
seen = []
replies = iter([
    {"role": "assistant", "content": None, "tool_calls": [
        {"id": "t1", "type": "function", "function": {"name": "search_policies", "arguments": '{"query": "income"}'}}]},
    {"role": "assistant", "content": "The limit is 2,798 USD."},
])
handler.chat = lambda messages: (seen.append([m["role"] for m in messages]), next(replies))[1]
handler.run_tool = lambda caller, name, args: {"stub": name, "args": args}
out = handler.handler({"caller_id": "cw-001", "question": "income limit for 3"})
assert out["answer"] == "The limit is 2,798 USD.", out
assert out["tool_calls"] == [{"name": "search_policies", "input": {"query": "income"}}], out
assert seen[1] == ["system", "user", "assistant", "tool"], seen

# The gateway backs off on 429 and never puts the response body in its error.
calls = []
def fake_urlopen(req, timeout):
    calls.append(req.full_url)
    if len(calls) < 3:
        raise urllib.error.HTTPError(req.full_url, 429, "Too Many Requests", {}, io.BytesIO(b"echo of the prompt"))
    return io.BytesIO(json.dumps({"ok": 1}).encode())
gateway.urllib.request.urlopen = fake_urlopen
gateway.time.sleep = lambda s: None
assert gateway.call("chat/completions", "k", {"x": 1}) == {"ok": 1}
assert len(calls) == 3 and calls[0].startswith("https://generativelanguage.googleapis.com/"), calls
def always_403(req, timeout):
    raise urllib.error.HTTPError(req.full_url, 403, "Forbidden", {}, io.BytesIO(b"echo of the prompt"))
gateway.urllib.request.urlopen = always_403
try:
    gateway.call("chat/completions", "k", {"x": 1})
    raise AssertionError("403 must raise")
except RuntimeError as e:
    assert str(e) == "model provider returned HTTP 403" and "echo" not in str(e), e
print("ok")
