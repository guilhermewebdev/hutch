#!/bin/bash
# Entrypoint: creates a user inside the container matching the host's UID/GID/username,
# then drops privileges and executes the given command as that user.
set -e

USERNAME="${HUTCH_USER:-user}"
UID_VAL="${HUTCH_UID:-1000}"
GID_VAL="${HUTCH_GID:-1000}"
DOCKER_GID="${HUTCH_DOCKER_GID:-}"

# Create the group for the user's GID if it doesn't exist yet
if ! getent group "$GID_VAL" &>/dev/null; then
    groupadd -g "$GID_VAL" "$USERNAME"
fi

# Create the user if the UID doesn't exist yet
if ! getent passwd "$UID_VAL" &>/dev/null; then
    useradd -u "$UID_VAL" -g "$GID_VAL" \
            -d /home/user -s /bin/bash -M "$USERNAME"
fi

# Add the user to the docker group so it can reach the host socket
if [ -n "$DOCKER_GID" ]; then
    if ! getent group "$DOCKER_GID" &>/dev/null; then
        groupadd -g "$DOCKER_GID" docker
    fi
    usermod -aG "$DOCKER_GID" "$USERNAME" 2>/dev/null || true
fi

export HOME=/home/user

exec gosu "$USERNAME" "$@"
