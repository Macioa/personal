"""Structured-output request to the remote Gemini REST API."""
import sys, time
import requests
from db import env

MODEL = "gemini-3.1-flash-lite"  # same as homepage-2026 netlify/functions/chat.mts
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
MAX_RETRIES = 2
RETRY_SECONDS = 30


# Retries rate limits and server errors. Returns the Gemini response.
def generate(text, schema):
    body = {"contents": [{"role": "user", "parts": [{"text": text}]}],
            "generationConfig": {"temperature": 0, "responseMimeType": "application/json",
                                 "responseJsonSchema": schema.model_json_schema()}}
    for attempt in range(MAX_RETRIES + 1):
        r = requests.post(URL, headers={"x-goog-api-key": env("RESUME_GEMINI_KEY")}, json=body, timeout=180)
        if r.status_code != 429 and r.status_code < 500:
            break
        if attempt < MAX_RETRIES:
            print(f"Gemini {r.status_code}, retry {attempt + 1}/{MAX_RETRIES} in {RETRY_SECONDS}s", file=sys.stderr)
            time.sleep(RETRY_SECONDS)
    if not r.ok:
        sys.exit(f"Gemini request failed ({r.status_code}): {r.text[:500]}")
    return r.json()
