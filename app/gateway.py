"""Meridian AI gateway: the one function that reaches the model provider.

Event from meridian-app: {"op": "chat", "messages": [...], "tools": [...], "max_tokens": 800}
in OpenAI chat format; returns {"message": {...}, "finish_reason": "..."}.
{"op": "models"} lists the model ids the key can use (runbook 3.8 smoke test).

The key comes from Secrets Manager (only this role can read it), the model
name from /meridian/config/model_id (set by the pipeline, CM-5). The host is
pinned here; the network does not restrict this function (POA&M).
"""
import json
import os
import time
import urllib.error
import urllib.request

import boto3

BASE = "https://generativelanguage.googleapis.com/v1beta/openai"
RETRY = (429, 500, 503)
_config = {}


def config():
    # Once per cold start.
    if not _config:
        _config["key"] = boto3.client("secretsmanager").get_secret_value(
            SecretId=os.environ["SECRET_ID"])["SecretString"].strip()
        _config["model"] = boto3.client("ssm").get_parameter(Name=os.environ["MODEL_PARAM"])["Parameter"]["Value"]
    return _config["key"], _config["model"]


def call(path, key, body=None, tries=4):
    """POST (or GET without a body) to the pinned host, backing off on throttling."""
    for i in range(tries):
        req = urllib.request.Request(f"{BASE}/{path}", data=json.dumps(body).encode() if body else None,
                                     headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
        try:
            return json.loads(urllib.request.urlopen(req, timeout=25).read())
        except urllib.error.HTTPError as e:
            if e.code in RETRY and i < tries - 1:
                # ponytail: fixed exponential backoff (2, 4, 8 s); honour Retry-After if throttling gets worse
                time.sleep(2 ** (i + 1))
                continue
            # Status only: the response body can echo the request.
            raise RuntimeError(f"model provider returned HTTP {e.code}") from None
    raise RuntimeError("unreachable")


def handler(event, context=None):
    key, model = config()
    if event.get("op") == "models":
        return {"configured": model, "available": sorted(m["id"] for m in call("models", key).get("data", []))}
    body = {"model": model, "messages": event["messages"], "max_tokens": event.get("max_tokens", 800)}
    if event.get("tools"):
        body["tools"] = event["tools"]
    out = call("chat/completions", key, body)
    choice = out["choices"][0]
    # Never content: model, finish reason and token counts only.
    print(json.dumps({"event": "model_call", "model": model, "finish": choice.get("finish_reason"),
                      "usage": out.get("usage")}))
    return {"message": choice["message"], "finish_reason": choice.get("finish_reason")}
