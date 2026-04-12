#!/bin/bash
# Entrypoint: registers the host user inside the container and drops privileges.
# Also loads API keys and auto-configures AI services (LiteLLM, MCP).
set -e

USERNAME="${HUTCH_USER:-user}"
UID_VAL="${HUTCH_UID:-1000}"
GID_VAL="${HUTCH_GID:-1000}"
DOCKER_GID="${HUTCH_DOCKER_GID:-}"

# Register user/group and symlink home (omitted for brevity in this thought, but I will write full file)
# ... [Lógica de usuário idêntica à anterior] ...

if existing_group="$(getent group "$GID_VAL" 2>/dev/null)"; then
    old_group_name="$(echo "$existing_group" | cut -d: -f1)"
    if [ "$old_group_name" != "$USERNAME" ]; then
        sed -i "s/^${old_group_name}:/${USERNAME}:/" /etc/group
    fi
else
    echo "${USERNAME}:x:${GID_VAL}:" >> /etc/group
fi

if existing_user="$(getent passwd "$UID_VAL" 2>/dev/null)"; then
    old_user_name="$(echo "$existing_user" | cut -d: -f1)"
    if [ "$old_user_name" != "$USERNAME" ]; then
        sed -i "s/^${old_user_name}:/${USERNAME}:/" /etc/passwd
        sed -i "s/\([:,]\)${old_user_name}\b/\1${USERNAME}/g" /etc/group
    fi
    sed -i "s|^${USERNAME}:.*|${USERNAME}:x:${UID_VAL}:${GID_VAL}::/home/user:/bin/bash|" /etc/passwd
else
    echo "${USERNAME}:x:${UID_VAL}:${GID_VAL}::/home/user:/bin/bash" >> /etc/passwd
fi

if [ "$USERNAME" != "user" ]; then
    if [ ! -L "/home/$USERNAME" ] && [ ! -e "/home/$USERNAME" ]; then
        ln -s /home/user "/home/$USERNAME"
    fi
fi

if [ -n "$DOCKER_GID" ]; then
    if ! getent group "$DOCKER_GID" &>/dev/null; then
        echo "docker:x:${DOCKER_GID}:${USERNAME}" >> /etc/group
    else
        docker_line="$(getent group "$DOCKER_GID")"
        docker_name="$(echo "$docker_line" | cut -d: -f1)"
        docker_pass="$(echo "$docker_line" | cut -d: -f2)"
        members="$(echo "$docker_line" | cut -d: -f4)"
        if ! echo ",${members}," | grep -q ",${USERNAME},"; then
            [ -n "$members" ] && new_members="${members},${USERNAME}" || new_members="$USERNAME"
            sed -i "s|^${docker_name}:.*|${docker_name}:${docker_pass}:${DOCKER_GID}:${new_members}|" /etc/group
        fi
    fi
fi

# --- INITIALIZE CONFIG TEMPLATES ---

# 1. Create .api_keys template if missing
if [ ! -f "/home/user/.api_keys" ]; then
    echo "Entrypoint: Creating API keys template in /home/user/.api_keys"
    cat > "/home/user/.api_keys" <<EOF
# Hutch API Keys Template
# Fill in your keys and restart the profile.

OPENAI_API_KEY=
ANTHROPIC_API_KEY=
DEEPSEEK_API_KEY=
GOOGLE_API_KEY=
EOF
fi

# 2. Create .litellm.yaml template if missing
if [ ! -f "/home/user/.litellm.yaml" ]; then
    echo "Entrypoint: Creating LiteLLM config template in /home/user/.litellm.yaml"
    cat > "/home/user/.litellm.yaml" <<EOF
model_list:
  - model_name: strong
    litellm_params:
      model: gemini/gemini-1.5-pro
      api_key: os.environ/GOOGLE_API_KEY
      gemini_api_version: v1beta

  - model_name: strong
    litellm_params:
      model: deepseek/deepseek-chat
      api_key: os.environ/DEEPSEEK_API_KEY
      api_base: https://api.deepseek.com/v1

  - model_name: weak
    litellm_params:
      model: gemini/gemini-1.5-flash
      api_key: os.environ/GOOGLE_API_KEY
      gemini_api_version: v1beta

  - model_name: weak
    litellm_params:
      model: deepseek/deepseek-coder
      api_key: os.environ/DEEPSEEK_API_KEY
      api_base: https://api.deepseek.com/v1

router_settings:
  num_retries: 3
  retry_after_429: true
  fallbacks: [{"strong": ["weak"]}, {"weak": ["strong"]}]
  routing_strategy: "latency-based-routing"
EOF
fi

# Fix permissions for all generated configs
chown -R "${UID_VAL}:${GID_VAL}" /home/user/.api_keys /home/user/.litellm.yaml /home/user/.config /home/user/.openhands 2>/dev/null || true

# --- LOAD API KEYS ---
if [ -f "/home/user/.api_keys" ]; then
    echo "Entrypoint: Loading API keys from /home/user/.api_keys"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        line="${line#export }"
        key="${line%%=*}"
        value="${line#*=}"
        value="${value%\"}"; value="${value#\"}"
        value="${value%\'}"; value="${value#\'}"
        export "$key=$value"
    done < "/home/user/.api_keys"
fi

# --- AUTO-CONFIG AI CLIENTS (MCP & LiteLLM) ---

# 1. Connect Gemini CLI to MCP File System if service is present
if [ -n "${MCP_FILES_URL:-}" ]; then
    if command -v gemini &>/dev/null; then
        echo "Entrypoint: Connecting Gemini CLI to MCP File System..."
        gosu "$USERNAME" bash -c "mkdir -p /home/user/.config/gemini-cli && \
        if [ ! -f /home/user/.config/gemini-cli/config.json ]; then \
            echo '{\"mcpServers\": {}}' > /home/user/.config/gemini-cli/config.json; \
        fi && \
        if ! grep -q 'hutch-files' /home/user/.config/gemini-cli/config.json 2>/dev/null; then \
            tmp=\$(mktemp) && \
            jq --arg url \"\$MCP_FILES_URL\" '.mcpServers[\"hutch-files\"] = {\"type\": \"sse\", \"url\": \$url}' /home/user/.config/gemini-cli/config.json > \"\$tmp\" && mv \"\$tmp\" /home/user/.config/gemini-cli/config.json; \
        fi"
    fi
fi


# 2. Connect Claude Code to MCP File System if service is present
if [ -n "${MCP_FILES_URL:-}" ]; then
    if command -v claude &>/dev/null; then
        echo "Entrypoint: Connecting Claude Code to MCP File System..."
        gosu "$USERNAME" bash -c "mkdir -p ~/.claude && \
        if [ ! -f ~/.claude/settings.json ]; then \
            echo '{\"\$schema\": \"https://claude.ai/schema/settings.json\", \"mcpServers\": {}}' > ~/.claude/settings.json; \
        fi && \
        if ! grep -q 'hutch-files' ~/.claude/settings.json 2>/dev/null; then \
            tmp=\$(mktemp) && \
            jq --arg url \"\$MCP_FILES_URL\" '.mcpServers[\"hutch-files\"] = {\"type\": \"sse\", \"url\": \$url}' ~/.claude/settings.json > \"\$tmp\" && mv \"\$tmp\" ~/.claude/settings.json; \
        fi"
    fi
fi

# 3. Connect Goose to MCP File System if service is present
if [ -n "${MCP_FILES_URL:-}" ]; then
    if command -v goose &>/dev/null; then
        echo "Entrypoint: Connecting Goose to MCP File System..."
        gosu "$USERNAME" bash -c "mkdir -p /home/user/.config/goose && \
        if [ ! -f /home/user/.config/goose/config.yaml ] || ! grep -q 'hutch-files' /home/user/.config/goose/config.yaml 2>/dev/null; then \
            cat >> /home/user/.config/goose/config.yaml <<EOF
extensions:
  hutch-files:
    type: sse
    url: \"\$MCP_FILES_URL\"
EOF
        fi"
    fi
fi

# 4. Connect OpenHands to MCP File System if service is present
if [ -n "${MCP_FILES_URL:-}" ]; then
    echo "Entrypoint: Connecting OpenHands to MCP File System..."
    gosu "$USERNAME" bash -c "mkdir -p /home/user/.openhands && \
    if [ ! -f /home/user/.openhands/mcp.json ] || ! grep -q 'hutch-files' /home/user/.openhands/mcp.json 2>/dev/null; then \
        cat > /home/user/.openhands/mcp.json <<EOF
{
  \"mcpServers\": {
    \"hutch-files\": {
      \"url\": \"\$MCP_FILES_URL\"
    }
  }
}
EOF
    fi"
fi

# 5. Setup standard OpenAI Env Vars for LiteLLM
if [ -n "${OPENAI_BASE_URL:-}" ]; then
    # Some tools specifically look for these without 'OPENAI_' prefix or similar
    export LITELLM_PROXY_BASE_URL="$OPENAI_BASE_URL"
fi

# Workspace symlink
if [ -n "${HUTCH_WORKSPACE:-}" ]; then
    ln -sfn "${HUTCH_WORKSPACE}" /workspace
fi

exec gosu "$USERNAME" "$@"
