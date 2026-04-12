#!/bin/bash
# Starts the RouteLLM OpenAI-compatible server.
# Note: no set -e — a bad line in ~/.api_keys must not abort the whole script.

export HOME="/home/user"

if [ -f "$HOME/.api_keys" ]; then
    echo "--- Loading API keys from $HOME/.api_keys ---"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.*$ ]] && continue # skip comments
        [[ -z "$line" ]] && continue       # skip empty lines
        # Strip leading "export " so both "VAR=val" and "export VAR=val" work.
        line="${line#export }"
        key="${line%%=*}"
        echo "Exporting: $key"
        export "$line" || echo "Warning: could not export '$key', skipping"
    done < "$HOME/.api_keys"
fi

# OPENAI_API_KEY may be the compose-level placeholder ("routellm-placeholder"),
# unset, or empty — in all three cases we need to derive a real value.
_current_key="${OPENAI_API_KEY:-}"
if [ -z "$_current_key" ] || [ "$_current_key" = "routellm-placeholder" ]; then
    if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
        echo "Aliasing DEEPSEEK_API_KEY to OPENAI_API_KEY"
        export OPENAI_API_KEY="$DEEPSEEK_API_KEY"
    else
        echo ""
        echo "ERROR: No API key configured."
        echo ""
        echo "Create ~/.api_keys inside the container with your key:"
        echo "  hutch shell <profile>"
        echo "  echo 'DEEPSEEK_API_KEY=sk-...' > ~/.api_keys"
        echo ""
        echo "Or export the key in your shell before running hutch:"
        echo "  export DEEPSEEK_API_KEY=sk-..."
        echo ""
        exit 1
    fi
fi

ROUTELLM_STRONG_MODEL="${ROUTELLM_STRONG_MODEL:-deepseek/deepseek-chat}"
ROUTELLM_WEAK_MODEL="${ROUTELLM_WEAK_MODEL:-deepseek/deepseek-coder}"
ROUTELLM_ROUTER="${ROUTELLM_ROUTER:-casc}"
ROUTELLM_PORT="${ROUTELLM_PORT:-6060}"

echo "Starting RouteLLM on port $ROUTELLM_PORT..."
echo "  Router: $ROUTELLM_ROUTER"
echo "  Strong: $ROUTELLM_STRONG_MODEL"
echo "  Weak:   $ROUTELLM_WEAK_MODEL"

exec /usr/local/bin/python3 -m routellm.openai_server \
    --routers "$ROUTELLM_ROUTER" \
    --strong-model "$ROUTELLM_STRONG_MODEL" \
    --weak-model "$ROUTELLM_WEAK_MODEL" \
    --port "$ROUTELLM_PORT"
