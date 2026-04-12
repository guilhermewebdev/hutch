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

chown "${UID_VAL}:${GID_VAL}" /home/user
export HOME=/home/user

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
        if ! gemini mcp list 2>/dev/null | grep -q "hutch-files"; then
            echo "Entrypoint: Connecting Gemini CLI to MCP File System..."
            gemini mcp add --transport sse hutch-files "$MCP_FILES_URL" >/dev/null 2>&1 || true
        fi
    fi
fi

# 2. Connect Claude Code to MCP File System if service is present
if [ -n "${MCP_FILES_URL:-}" ]; then
    if command -v claude &>/dev/null; then
        # We try to add, Claude's config is persistent in the volume
        if [ ! -f "/home/user/.config/Claude/config.json" ] || ! grep -q "hutch-files" "/home/user/.config/Claude/config.json" 2>/dev/null; then
            echo "Entrypoint: Connecting Claude Code to MCP File System..."
            claude mcp add --transport sse hutch-files "$MCP_FILES_URL" >/dev/null 2>&1 || true
        fi
    fi
fi

# 3. Setup standard OpenAI Env Vars for LiteLLM
if [ -n "${OPENAI_BASE_URL:-}" ]; then
    # Some tools specifically look for these without 'OPENAI_' prefix or similar
    export LITELLM_PROXY_BASE_URL="$OPENAI_BASE_URL"
fi

# Workspace symlink
if [ -n "${HUTCH_WORKSPACE:-}" ]; then
    ln -sfn "${HUTCH_WORKSPACE}" /workspace
fi

exec gosu "$USERNAME" "$@"
