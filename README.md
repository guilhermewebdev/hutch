# hutch

Isolated CLI environments via Docker Compose, managed through profiles.

Each environment runs in its own container with a persistent home volume — credentials, config, and state are preserved across sessions. Switch between profiles to use different accounts or tools without any interference.

Not exclusive to AI tools. Works for any CLI.

## Concepts

Hutch is built on three independent layers:

| Layer | Location | Purpose |
|---|---|---|
| **Image** | `images/<name>/Dockerfile` | Installed software |
| **Base** | `bases/<name>.yml` | Runtime definitions (volumes, env, socket) |
| **Profile** | `~/.config/hutch/<name>` | Named environment (`BASE` + `COMMAND`) |

Multiple profiles can share the same base. Multiple bases can share the same image. Each profile gets its own Docker volume (`<profile>_home`) that persists independently.

The workspace is always the **current directory** — run `hutch work` from any project and it mounts that directory as `/workspace` inside the container.

## Installation

**One-liner** (clones the repo automatically):

```bash
curl -fsSL https://raw.githubusercontent.com/guilhermewebdev/hutch/main/install.sh | bash
```

```bash
wget -qO- https://raw.githubusercontent.com/guilhermewebdev/hutch/main/install.sh | bash
```

**Or clone manually:**

```bash
git clone https://github.com/guilhermewebdev/hutch.git
cd hutch && ./install.sh
```

Ensure `~/.local/bin` is in your `PATH`:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

To update hutch later, just re-run the one-liner — it pulls the latest changes and updates the symlink.

## Usage

```bash
hutch <profile> [args...]    # run the profile's default command in the current directory
hutch shell <profile>        # open an interactive shell in the profile
hutch list                   # list profiles and volume status
hutch list bases             # list bases and image status
hutch list images            # list built Docker images

hutch build <base>           # build the image for a base
hutch rebuild <base>         # force rebuild (no cache)

hutch new base <name>        # create a new base and open in editor
hutch new image <name>       # create a new Dockerfile and open in editor

hutch remove <profile>       # delete the profile's volume (keeps the profile file)
```

## Quickstart

```bash
# Build the Claude image (first time only, ~5 min)
hutch build claude

# Run Claude in the current directory using the work profile
hutch trabalho

# Authenticate (stored in the profile's volume)
hutch trabalho login

# Open a shell to configure git, SSH keys, etc.
hutch shell trabalho

# Switch to a different profile with a separate account
hutch pessoal login
hutch pessoal
```

## Adding a new environment

**1. New image** (if the tool isn't covered by an existing one):

```bash
hutch new image my-tool   # creates images/my-tool/Dockerfile and opens in editor
hutch build my-tool
```

**2. New base** (runtime configuration):

```bash
hutch new base my-tool    # creates bases/my-tool.yml and opens in editor
```

**3. New profile** (named environment):

```bash
cat > ~/.config/hutch/my-profile <<EOF
BASE="my-tool"
COMMAND="my-tool"
DESCRIPTION="My tool – work account"
EOF

hutch my-profile
```

## Included images

| Image | Tool | Package |
|---|---|---|
| `claude` | Claude Code | `@anthropic-ai/claude-code` |
| `gemini` | Google Gemini CLI | `@google/gemini-cli` |

Both images are based on `debian:bookworm` and include common development tools, Node.js, and the Docker CLI for host daemon access.

## Profile isolation

Each profile has its own Docker volume (`<profile>_home`) mounted at `/home/user` inside the container. This isolates:

- CLI credentials and auth tokens
- Tool configuration and memory
- Git identity (`~/.gitconfig`)
- SSH keys (`~/.ssh/`)

Deleting a volume discards all state for that profile:

```bash
hutch remove work
```

The profile file in `~/.config/hutch/` is kept — recreating the volume starts fresh.
