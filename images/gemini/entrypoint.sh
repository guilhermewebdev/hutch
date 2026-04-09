#!/bin/bash
# Entrypoint: registers the host user inside the container by writing directly
# to /etc/passwd and /etc/group (avoids groupadd/useradd locking issues on
# Docker Desktop and rootless Docker), then drops privileges via gosu.
set -e

USERNAME="${HUTCH_USER:-user}"
UID_VAL="${HUTCH_UID:-1000}"
GID_VAL="${HUTCH_GID:-1000}"
DOCKER_GID="${HUTCH_DOCKER_GID:-}"

# Register the user's primary group if the GID is not yet in /etc/group
if ! getent group "$GID_VAL" &>/dev/null; then
    echo "${USERNAME}:x:${GID_VAL}:" >> /etc/group
fi

# Register the user in /etc/passwd if the UID is not yet present
if ! getent passwd "$UID_VAL" &>/dev/null; then
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
exec gosu "$USERNAME" "$@"
