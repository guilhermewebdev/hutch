#!/bin/bash
# Starts the RouteLLM OpenAI-compatible server.
# API keys are read from ~/.api_keys in the profile home if the file exists.
# Any variable can also be overridden via the container environment.
set -e

if [ -f "$HOME/.api_keys" ]; then
    echo "Loading API keys from $HOME/.api_keys"
    set -a
    # shellcheck source=/dev/null
    . "$HOME/.api_keys"
    set +a
fi

# RouteLLM internal client initialization requires OPENAI_API_KEY to be set
# even if routing to other providers. We alias DEEPSEEK_API_KEY if available.
if [ -z "${OPENAI_API_KEY:-}" ]; then
    if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
        echo "Aliasing DEEPSEEK_API_KEY to OPENAI_API_KEY for RouteLLM initialization"
        export OPENAI_API_KEY="$DEEPSEEK_API_KEY"
    else
        echo "Warning: OPENAI_API_KEY is not set. RouteLLM might fail to start."
        # Set a dummy key to prevent crash during module import if no key is provided yet
        export OPENAI_API_KEY="no-key-set"
    fi
fi

ROUTELLM_STRONG_MODEL="${ROUTELLM_STRONG_MODEL:-deepseek/deepseek-chat}"
ROUTELLM_WEAK_MODEL="${ROUTELLM_WEAK_MODEL:-deepseek/deepseek-coder}"
ROUTELLM_ROUTER="${ROUTELLM_ROUTER:-mf}"
ROUTELLM_PORT="${ROUTELLM_PORT:-6060}"

echo "Starting RouteLLM on port $ROUTELLM_PORT..."
echo "  Router: $ROUTELLM_ROUTER"
echo "  Strong Model: $ROUTELLM_STRONG_MODEL"
echo "  Weak Model: $ROUTELLM_WEAK_MODEL"

exec python -m routellm.openai_server \
    --routers "$ROUTELLM_ROUTER" \
    --strong-model "$ROUTELLM_STRONG_MODEL" \
    --weak-model "$ROUTELLM_WEAK_MODEL" \
    --port "$ROUTELLM_PORT"
