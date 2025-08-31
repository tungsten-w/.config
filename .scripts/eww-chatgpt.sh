#!/usr/bin/env bash
# eww-chatgpt.sh
# Usage: eww-chatgpt.sh "ma question ici"
set -euo pipefail

PROMPT="$1"
# Sécurité: api key via variable d'env
: "${OPENAI_API_KEY:?Set OPENAI_API_KEY env var (export OPENAI_API_KEY=...) }"

# Endpoint simple (chat completions). Tu peux changer model si tu veux.
RESP_JSON=$(
  curl -sS -X POST "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d @- <<-JSON
{
  "model": "gpt-3.5-turbo",
  "messages": [{"role": "user", "content": "$PROMPT"}],
  "max_tokens": 800,
  "temperature": 0.6
}
JSON
)

# Extrait la réponse (choix 0)
ANSWER=$(echo "$RESP_JSON" | jq -r '.choices[0].message.content // "Erreur: pas de réponse"')

# Met à jour la variable eww (nom: chat_reply)
eww update chat_reply="$ANSWER"
