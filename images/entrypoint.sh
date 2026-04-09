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
    # Normalize the entry: gosu reads home from /etc/passwd, so ensure it's /home/user
    # regardless of what the pre-existing entry had (e.g. ubuntu user has /home/ubuntu)
    sed -i "s|^${USERNAME}:.*|${USERNAME}:x:${UID_VAL}:${GID_VAL}::/home/user:/bin/bash|" /etc/passwd
else
    echo "${USERNAME}:x:${UID_VAL}:${GID_VAL}::/home/user:/bin/bash" >> /etc/passwd
fi

# Register the docker group and add the user to it
if [ -n "$DOCKER_GID" ]; then
    if ! getent group "$DOCKER_GID" &>/dev/null; then
        echo "docker:x:${DOCKER_GID}:${USERNAME}" >> /etc/group
    else
        # Group exists — append user if not already a member
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

# Create /workspace symlink pointing to the actual mounted workspace path.
# This lets users type shorter paths (/workspace/...) while Docker Compose
# on the host resolves bind mounts correctly via the real path.
if [ -n "${HUTCH_WORKSPACE:-}" ]; then
    ln -sfn "${HUTCH_WORKSPACE}" /workspace
fi


exec gosu "$USERNAME" "$@"
