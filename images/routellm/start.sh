#!/bin/bash
# Starts the RouteLLM OpenAI-compatible server.
set -e

# API keys are already loaded by entrypoint.sh into the environment.

# RouteLLM internal client initialization requires OPENAI_API_KEY to be set
# even if routing to other providers. We alias DEEPSEEK_API_KEY if available.
if [ -z "${OPENAI_API_KEY:-}" ]; then
    if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
        echo "Aliasing DEEPSEEK_API_KEY to OPENAI_API_KEY for RouteLLM"
        export OPENAI_API_KEY="$DEEPSEEK_API_KEY"
    else
        echo "Warning: No OpenAI or DeepSeek key found. Setting dummy key to prevent crash."
        export OPENAI_API_KEY="no-key-set"
    fi
fi

ROUTELLM_STRONG_MODEL="${ROUTELLM_STRONG_MODEL:-deepseek/deepseek-chat}"
ROUTELLM_WEAK_MODEL="${ROUTELLM_WEAK_MODEL:-deepseek/deepseek-coder}"
ROUTELLM_ROUTER="${ROUTELLM_ROUTER:-mf}"
ROUTELLM_PORT="${ROUTELLM_PORT:-6060}"

echo "Starting RouteLLM on port $ROUTELLM_PORT..."
echo "  Router: $ROUTELLM_ROUTER"

exec python -m routellm.openai_server \
    --routers "$ROUTELLM_ROUTER" \
    --strong-model "$ROUTELLM_STRONG_MODEL" \
    --weak-model "$ROUTELLM_WEAK_MODEL" \
    --port "$ROUTELLM_PORT"
