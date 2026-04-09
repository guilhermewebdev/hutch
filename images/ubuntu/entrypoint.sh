#!/bin/bash
# Entrypoint: registers the host user inside the container by writing directly
# to /etc/passwd and /etc/group (avoids groupadd/useradd locking issues on
# Docker Desktop and rootless Docker), then drops privileges via gosu.
set -e

USERNAME="${HUTCH_USER:-user}"
UID_VAL="${HUTCH_UID:-1000}"
GID_VAL="${HUTCH_GID:-1000}"
DOCKER_GID="${HUTCH_DOCKER_GID:-}"

# Register the user's primary group — rename if GID exists under a different name
if existing_group="$(getent group "$GID_VAL" 2>/dev/null)"; then
    old_group_name="$(echo "$existing_group" | cut -d: -f1)"
    if [ "$old_group_name" != "$USERNAME" ]; then
        sed -i "s/^${old_group_name}:/${USERNAME}:/" /etc/group
    fi
else
    echo "${USERNAME}:x:${GID_VAL}:" >> /etc/group
fi

# Register the user — rename if UID exists under a different name
if existing_user="$(getent passwd "$UID_VAL" 2>/dev/null)"; then
    old_user_name="$(echo "$existing_user" | cut -d: -f1)"
    if [ "$old_user_name" != "$USERNAME" ]; then
        sed -i "s/^${old_user_name}:/${USERNAME}:/" /etc/passwd
        sed -i "s/\([:,]\)${old_user_name}\b/\1${USERNAME}/g" /etc/group
    fi
else
    echo "${USERNAME}:x:${UID_VAL}:${GID_VAL}::/home/user:/bin/bash" >> /etc/passwd
fi

# Register the docker group and add the user to it
if [ -n "$DOCKER_GID" ]; then
    if ! getent group "$DOCKER_GID" &>/dev/null; then
        echo "docker:x:${DOCKER_GID}:${USERNAME}" >> /etc/group
    else
        # Group exists — append user if not already a member
        docker_name="$(getent group "$DOCKER_GID" | cut -d: -f1)"
        if ! getent group "$DOCKER_GID" | grep -qE "(^|,)${USERNAME}$"; then
            sed -i "/^${docker_name}:/ s/$/,${USERNAME}/" /etc/group
        fi
    fi
fi

chown "${UID_VAL}:${GID_VAL}" /home/user
export HOME=/home/user

# Reset Claude's workspace trust when the mounted directory changes.
# Claude caches trust for /workspace by path — since the path is always the same
# inside the container, it would never ask again even when the project changes.
WORKSPACE_TRACKER="/home/user/.claude_last_workspace"
CLAUDE_JSON="/home/user/.claude.json"
if [ -n "${HUTCH_WORKSPACE:-}" ] && [ -f "$CLAUDE_JSON" ]; then
    last_workspace=""
    [ -f "$WORKSPACE_TRACKER" ] && last_workspace="$(cat "$WORKSPACE_TRACKER")"
    if [ "$last_workspace" != "$HUTCH_WORKSPACE" ]; then
        new_json="$(jq 'del(."/workspace")' "$CLAUDE_JSON" 2>/dev/null)" \
            && printf '%s\n' "$new_json" > "$CLAUDE_JSON"
        printf '%s' "$HUTCH_WORKSPACE" > "$WORKSPACE_TRACKER"
        chown "${UID_VAL}:${GID_VAL}" "$WORKSPACE_TRACKER"
    fi
fi

exec gosu "$USERNAME" "$@"
