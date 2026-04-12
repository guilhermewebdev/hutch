#!/bin/bash
# Starts the LiteLLM proxy server.
# Reads provider config from ~/.litellm.yaml inside the profile volume.

export HOME="/home/user"

CONFIG="$HOME/.litellm.yaml"

if [ ! -f "$CONFIG" ]; then
    echo ""
    echo "ERROR: No config found at $CONFIG"
    echo ""
    echo "Create ~/.litellm.yaml inside the container. Example:"
    echo ""
    echo "  model_list:"
    echo "    - model_name: strong"
    echo "      litellm_params:"
    echo "        model: gemini/gemini-1.5-pro"
    echo "        api_key: os.environ/GOOGLE_API_KEY"
    echo "    - model_name: weak"
    echo "      litellm_params:"
    echo "        model: deepseek/deepseek-chat"
    echo "        api_key: os.environ/DEEPSEEK_API_KEY"
    echo "        api_base: https://api.deepseek.com/v1"
    echo ""
    exit 1
fi

echo "Starting LiteLLM proxy on port 4000..."
echo "  Config: $CONFIG"

exec litellm --config "$CONFIG" --port 4000
