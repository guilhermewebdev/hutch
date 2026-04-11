#!/bin/bash
# Starts the RouteLLM OpenAI-compatible server.
# API keys are read from ~/.api_keys in the profile home if the file exists.
# Any variable can also be overridden via the container environment.
set -e

if [ -f "$HOME/.api_keys" ]; then
    set -a
    # shellcheck source=/dev/null
    . "$HOME/.api_keys"
    set +a
fi

ROUTELLM_STRONG_MODEL="${ROUTELLM_STRONG_MODEL:-deepseek/deepseek-chat}"
ROUTELLM_WEAK_MODEL="${ROUTELLM_WEAK_MODEL:-deepseek/deepseek-coder}"
ROUTELLM_ROUTER="${ROUTELLM_ROUTER:-mf}"
ROUTELLM_PORT="${ROUTELLM_PORT:-6060}"

exec python -m routellm.openai_server \
    --routers "$ROUTELLM_ROUTER" \
    --strong-model "$ROUTELLM_STRONG_MODEL" \
    --weak-model "$ROUTELLM_WEAK_MODEL" \
    --port "$ROUTELLM_PORT"
