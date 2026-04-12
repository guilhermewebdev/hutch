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

**To uninstall:**

```bash
curl -fsSL https://raw.githubusercontent.com/guilhermewebdev/hutch/main/uninstall.sh | bash
```

## Usage

```bash
hutch [--yes|-y] <profile> [args...]   # run the profile's default command in the current directory
hutch [--yes|-y] shell <profile>       # open an interactive shell in the profile
hutch exec <profile> [command]         # exec into a running container of the profile (default: bash)
hutch list                             # list profiles and volume status
hutch list bases                       # list bases and image status
hutch list images                      # list built Docker images

hutch build <image>                    # build an image (e.g. hutch build claude)
hutch rebuild <image>                  # force rebuild (no cache)

hutch new profile <name>               # create a new profile and open in editor
hutch new base <name>                  # create a new base and open in editor
hutch new image <name>                 # create a new Dockerfile and open in editor

hutch edit image|base|profile <name>   # open an existing file in the editor

hutch config                           # show configuration
hutch config editor [value]            # get or set the preferred editor

hutch down <profile>                   # stop all containers for the profile (keeps volumes)
hutch purge <profile>                  # delete the profile's volume/state (keeps the profile file)
```

The `--yes` / `-y` flag bypasses the workspace safety prompt. Useful in non-interactive scripts:

```bash
hutch --yes work                       # skip prompt when running from a shallow or unusual path
```

## Quickstart

```bash
# Build the Claude image (first time only, ~5 min)
hutch build claude

# Run Claude in the current directory using the work profile
hutch work

# Authenticate (stored in the profile's volume)
hutch work login

# Open a shell to configure git, SSH keys, etc.
hutch shell work

# Switch to a different profile with a separate account
hutch personal login
hutch personal
```

## Editor

Hutch opens files in your preferred editor for `new` and `edit` commands. The editor is resolved in this order:

1. `$VISUAL` environment variable
2. `$EDITOR` environment variable
3. Hutch config (`hutch config editor`)
4. Auto-detect: `sensible-editor`, `nano`, `vim`, `vi`

```bash
hutch config editor nano           # save a preference
hutch config editor                # show current setting
hutch config                       # show full configuration
```

```bash
hutch edit image claude            # edit images/claude/Dockerfile
hutch edit base claude             # edit bases/claude.yml
hutch edit profile work        # edit ~/.config/hutch/work
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

| Image | Base OS | Purpose |
|---|---|---|
| `claude` | `debian:bookworm` | Claude Code CLI (`@anthropic-ai/claude-code`) |
| `gemini` | `debian:bookworm` | Google Gemini CLI (`@google/gemini-cli`) |
| `aider` | `debian:bookworm` | Aider – DeepSeek Coder via RouteLLM (`aider-chat`) |
| `goose` | `debian:bookworm` | Goose – Agentic AI coding assistant (`goose session`) |
| `openhands` | `debian:bookworm` | OpenHands – Open-source AI software engineer (`openhands`) |
| `all` | `debian:bookworm` | All AI clients in one image — `claude`, `gemini`, `aider`, `goose`, `openhands` |
| `routellm` | `debian:bookworm` | RouteLLM server — OpenAI-compatible router (strong/weak models) |
| `ubuntu` | `ubuntu:24.04` | General-purpose shell — no AI, just a clean workspace |

The `ubuntu` profile opens bash directly, so `hutch ubuntu` drops you into an isolated shell with the current directory mounted. Useful for running arbitrary tools without touching your host environment.

```bash
hutch build ubuntu
hutch ubuntu          # isolated bash shell in the current directory
```

The `aider` profile uses the `routellm` base, which starts a RouteLLM sidecar as a local OpenAI-compatible router before launching the tool. Build both images first:

```bash
hutch build routellm
hutch build aider
```

All configuration — API keys and RouteLLM settings — lives in `~/.api_keys` inside the profile's home volume. The sidecar sources this file at startup, so credentials never pass through the host environment or the compose file.

Create the file on the first run:

```bash
hutch shell aider

# inside the container:
cat > ~/.api_keys <<EOF
DEEPSEEK_API_KEY=sk-...

# RouteLLM routing config (optional — these are the defaults)
ROUTELLM_STRONG_MODEL=deepseek/deepseek-chat
ROUTELLM_WEAK_MODEL=deepseek/deepseek-coder
ROUTELLM_ROUTER=mf
ROUTELLM_PORT=6060
EOF
```

On subsequent runs `hutch aider` will pick up the keys automatically. The same volume is shared between the tool container and the routellm sidecar, so a single `~/.api_keys` file configures both.

## AI Client Integration

Hutch provides first-class support for connecting AI clients to local proxies and context servers.

### LiteLLM (OpenAI Proxy)
The `litellm` service runs a proxy that translates OpenAI-style requests to any provider (Gemini, DeepSeek, Anthropic, etc.).
- **Auto-Config:** When the `litellm` service is active, `OPENAI_BASE_URL` is automatically set to `http://litellm:4000/v1` in the main container.
- **Provider Setup:** Edit `~/.litellm.yaml` inside your profile to map models and keys.

#### Enhancements (Optional):
You can stack multiple LiteLLM services to enable advanced features:
- **`litellm-db`**: Adds a PostgreSQL database to enable the **Admin UI (Dashboard)**, **Virtual Keys**, and **Usage Tracking**.
  - Dashboard available at `http://litellm:4000/` (internally).
  - Configures `LITELLM_MASTER_KEY=sk-hutch-master-key`.
- **`litellm-cache`**: Adds Redis to enable **Response Caching**. Saves tokens and reduces latency for repeated prompts.

**Usage:**
```bash
# ~/.config/hutch/my-profile
SERVICES="litellm litellm-db litellm-cache"
```

### MCP File System (Context Server)
The `mcp-files` service serves host files from `~/HutchMCP/<profile>/` over the Model Context Protocol (SSE).
- **Auto-Config:** `gemini-cli` and `claude-code` are automatically connected to the server at startup if the service is active.
- **Usage:**
  - **Gemini:** Use `@hutch-files://path/to/file` to reference context.
  - **Claude:** Claude automatically discovers tools to list and read the directory.
- **Host Sync:** Place any files in `~/HutchMCP/<profile>/` on your host to make them available to your AI agents.
## Included bases

| Base | Docker access | Use case |
|---|---|---|
| `default` | None | AI agents and tools that don't need Docker |
| `docker` | Host socket (opt-in) | Running `docker`/`docker compose` from inside the container |
| `dind` | Isolated daemon | Full Docker isolation — no host socket exposed |
| `routellm` | None | Adds a RouteLLM sidecar — routes requests between strong/weak models |

By default all profiles use `default` (no Docker access). To enable Docker CLI access, set `BASE="docker"` in your profile:

```bash
# ~/.config/hutch/my-profile
BASE="docker"
```

> **Security note:** the `docker` base mounts `/var/run/docker.sock`, which gives the container
> full Docker access — including the ability to run privileged containers with host filesystem
> access. Any process inside (including AI agents) inherits this capability. Use only in contexts
> you trust.

## Profile isolation

Each profile has its own Docker volume (`<profile>_home`) mounted at `/home/user` inside the container. This isolates:

- CLI credentials and auth tokens
- Tool configuration and memory
- Git identity (`~/.gitconfig`)
- SSH keys (`~/.ssh/`)

Deleting a volume discards all state for that profile:

```bash
hutch purge work
```

The profile file in `~/.config/hutch/` is kept — recreating the volume starts fresh.
