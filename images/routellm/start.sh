#!/bin/bash
# Starts the RouteLLM OpenAI-compatible server.
set -e

# Define Home explicitly just in case
export HOME="/home/user"

if [ -f "$HOME/.api_keys" ]; then
    echo "--- Loading API keys from $HOME/.api_keys ---"
    # Read file and export each line manually to be super safe
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.*$ ]] && continue # skip comments
        [[ -z "$line" ]] && continue       # skip empty lines
        echo "Exporting: ${line%%=*}"
        export "$line"
    done < "$HOME/.api_keys"
fi

# RouteLLM internal client initialization requires OPENAI_API_KEY to be set
# even if routing to other providers. We alias DEEPSEEK_API_KEY if available.
if [ -z "${OPENAI_API_KEY:-}" ]; then
    if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
        echo "Aliasing DEEPSEEK_API_KEY to OPENAI_API_KEY"
        export OPENAI_API_KEY="$DEEPSEEK_API_KEY"
    else
        echo "Warning: No API key found. Setting dummy OPENAI_API_KEY to prevent crash."
        export OPENAI_API_KEY="no-key-set"
    fi
fi

# Final check
if [ -z "$OPENAI_API_KEY" ]; then
    echo "ERROR: OPENAI_API_KEY is still empty!"
    exit 1
fi

ROUTELLM_STRONG_MODEL="${ROUTELLM_STRONG_MODEL:-deepseek/deepseek-chat}"
ROUTELLM_WEAK_MODEL="${ROUTELLM_WEAK_MODEL:-deepseek/deepseek-coder}"
ROUTELLM_ROUTER="${ROUTELLM_ROUTER:-mf}"
ROUTELLM_PORT="${ROUTELLM_PORT:-6060}"

echo "Starting RouteLLM on port $ROUTELLM_PORT..."
echo "  Router: $ROUTELLM_ROUTER"
echo "  Strong: $ROUTELLM_STRONG_MODEL"
echo "  Weak:   $ROUTELLM_WEAK_MODEL"

# Use python3 explicitly and ensure it inherits the environment
exec /usr/local/bin/python3 -m routellm.openai_server \
    --routers "$ROUTELLM_ROUTER" \
    --strong-model "$ROUTELLM_STRONG_MODEL" \
    --weak-model "$ROUTELLM_WEAK_MODEL" \
    --port "$ROUTELLM_PORT"
