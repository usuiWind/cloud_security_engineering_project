"""Meridian AI gateway: the one function that reaches the model provider and Azure.

Events from meridian-app (OpenAI chat format for the model):
  {"op": "chat", "messages": [...], "tools": [...], "max_tokens": 800}  -> {"message": {...}, "finish_reason": "..."}
  {"op": "shield", "user": "...", "documents": ["..."]}                -> {"user": bool, "documents": [bool, ...]}
  {"op": "analyze", "text": "..."}                                      -> {"categories": {"Hate": 0, ...}}
  {"op": "models"}  lists the model ids the key can use (runbook 3.8 smoke test).

The Gemini key comes from Secrets Manager (only this role can read it), the
model name from /meridian/config/model_id (set by the pipeline, CM-5). Azure
is keyless: an AWS STS web identity token is traded with Entra for a Content
Safety token. Hosts are pinned here; the network does not restrict this
function (POA&M).
"""
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

import boto3

BASE = "https://generativelanguage.googleapis.com/v1beta/openai"
LOGIN = "https://login.microsoftonline.com"
CS_API = "api-version=2024-09-01"
RETRY = (429, 500, 503)
_config, _azure = {}, {}


def config():
    # Once per cold start.
    if not _config:
        _config["key"] = boto3.client("secretsmanager").get_secret_value(
            SecretId=os.environ["SECRET_ID"])["SecretString"].strip()
        _config["model"] = boto3.client("ssm").get_parameter(Name=os.environ["MODEL_PARAM"])["Parameter"]["Value"]
    return _config["key"], _config["model"]


def send(url, headers, data=None, tries=4, what="model provider"):
    """POST data (GET without it), backing off on throttling. Errors carry the status only."""
    for i in range(tries):
        try:
            return json.loads(urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers),
                                                     timeout=25).read())
        except urllib.error.HTTPError as e:
            if e.code in RETRY and i < tries - 1:
                # ponytail: fixed exponential backoff (2, 4, 8 s); honour Retry-After if throttling gets worse
                time.sleep(2 ** (i + 1))
                continue
            # Status only: the response body can echo the request.
            raise RuntimeError(f"{what} returned HTTP {e.code}") from None
    raise RuntimeError("unreachable")


def call(path, key, body=None, tries=4):
    return send(f"{BASE}/{path}", {"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
                json.dumps(body).encode() if body else None, tries)


def azure_token():
    """Entra token for Content Safety, from this role's AWS identity. Cached until 5 min before expiry."""
    if _azure.get("exp", 0) > time.time() + 300:
        return _azure["token"]
    aws_jwt = boto3.client("sts").get_web_identity_token(
        Audience=["api://AzureADTokenExchange"], SigningAlgorithm="RS256")["WebIdentityToken"]
    form = urllib.parse.urlencode({
        "client_id": os.environ["AZURE_CLIENT_ID"],
        "scope": "https://cognitiveservices.azure.com/.default",
        "grant_type": "client_credentials",
        "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
        "client_assertion": aws_jwt,
    }).encode()
    r = send(f"{LOGIN}/{os.environ['AZURE_TENANT_ID']}/oauth2/v2.0/token",
             {"Content-Type": "application/x-www-form-urlencoded"}, form, tries=2, what="Entra token exchange")
    _azure.update(token=r["access_token"], exp=time.time() + int(r["expires_in"]))
    return _azure["token"]


def content_safety(path, body):
    endpoint = os.environ["CONTENT_SAFETY_ENDPOINT"].rstrip("/")
    if not (urllib.parse.urlparse(endpoint).hostname or "").endswith(".cognitiveservices.azure.com"):
        raise RuntimeError("CONTENT_SAFETY_ENDPOINT is not a Content Safety host")
    return send(f"{endpoint}/contentsafety/{path}?{CS_API}",
                {"Authorization": f"Bearer {azure_token()}", "Content-Type": "application/json"},
                json.dumps(body).encode(), what="Content Safety")


def handler(event, context=None):
    op = event.get("op", "chat")
    if op == "shield":
        # Prompt Shields: user prompt attacks and document (indirect) attacks. Inputs cap at 10k characters.
        r = content_safety("text:shieldPrompt", {"userPrompt": event.get("user", "")[:10000],
                                                 "documents": [d[:10000] for d in event.get("documents", [])]})
        # A documents-only call (tool results) gets no userPromptAnalysis back.
        return {"user": r.get("userPromptAnalysis", {}).get("attackDetected", False),
                "documents": [d["attackDetected"] for d in r.get("documentsAnalysis", [])]}
    if op == "analyze":
        r = content_safety("text:analyze", {"text": event["text"][:10000], "outputType": "FourSeverityLevels"})
        return {"categories": {c["category"]: c["severity"] for c in r.get("categoriesAnalysis", [])}}
    key, model = config()
    if op == "models":
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
