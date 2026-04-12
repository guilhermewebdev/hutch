#!/bin/bash
# Starts the LiteLLM proxy server.
set -e

# API keys are already loaded by entrypoint.sh into the environment.

CONFIG="/home/user/.litellm.yaml"

if [ ! -f "$CONFIG" ]; then
    echo "ERROR: No config found at $CONFIG"
    exit 1
fi

echo "Starting LiteLLM proxy on port 4000..."
exec litellm --config "$CONFIG" --port 4000
