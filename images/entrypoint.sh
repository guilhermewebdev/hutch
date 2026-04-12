#!/bin/bash
# Entrypoint: registers the host user inside the container and drops privileges.
# Also loads API keys from ~/.api_keys so they are available to all processes.
set -e

USERNAME="${HUTCH_USER:-user}"
UID_VAL="${HUTCH_UID:-1000}"
GID_VAL="${HUTCH_GID:-1000}"
DOCKER_GID="${HUTCH_DOCKER_GID:-}"

# Register the user's primary group
if existing_group="$(getent group "$GID_VAL" 2>/dev/null)"; then
    old_group_name="$(echo "$existing_group" | cut -d: -f1)"
    if [ "$old_group_name" != "$USERNAME" ]; then
        sed -i "s/^${old_group_name}:/${USERNAME}:/" /etc/group
    fi
else
    echo "${USERNAME}:x:${GID_VAL}:" >> /etc/group
fi

# Register the user
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

# Symlink for path consistency
if [ "$USERNAME" != "user" ]; then
    if [ ! -L "/home/$USERNAME" ] && [ ! -e "/home/$USERNAME" ]; then
        ln -s /home/user "/home/$USERNAME"
    fi
fi

# Docker group mapping
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
# Load from the shared volume home so all containers (main & services) have them.
if [ -f "/home/user/.api_keys" ]; then
    echo "Entrypoint: Loading API keys from /home/user/.api_keys"
    # Export variables so they are inherited by the gosu command.
    # We use 'set -a' and source the file in a subshell or strip manually to handle quotes.
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        # Strip 'export ' prefix if present
        line="${line#export }"
        
        # Extract key and value
        key="${line%%=*}"
        value="${line#*=}"
        
        # Strip leading/trailing quotes from value
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"
        
        export "$key=$value"
    done < "/home/user/.api_keys"
fi

# Workspace symlink
if [ -n "${HUTCH_WORKSPACE:-}" ]; then
    ln -sfn "${HUTCH_WORKSPACE}" /workspace
fi

exec gosu "$USERNAME" "$@"
