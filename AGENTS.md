# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

ZephyrOS is a BlueBuild-based Fedora Atomic custom Linux distribution. The codebase consists of YAML recipes, bash build scripts, system config files, and a static website — there is no traditional application runtime, package manager, or backend service.

### Linting

- **Shell scripts**: `shellcheck files/scripts/*.sh scripts/*.sh nvidia-debug.sh`
- **YAML recipes and CI**: `yamllint recipes/*.yml .github/workflows/build.yml`

Both tools produce warnings/info on pre-existing code style issues; these are not blocking errors.

### Running the website locally

The static website lives in `docs/`. Serve it with:

```
python3 -m http.server 8080 -d docs
```

Then open `http://localhost:8080` in a browser. Both `index.html` and `download.html` should load.

### Building OS images

Full OS image builds require the `bluebuild` CLI, `sudo`, and a container runtime (podman/docker). These builds are resource-intensive (50+ GB disk, several hours) and are primarily run via GitHub Actions CI. Local builds are not expected as part of routine development. See `README.md` for install and build commands.

### Key directories

- `recipes/` — BlueBuild YAML recipes (8 image variants)
- `files/scripts/` — Build-time bash scripts (run during image creation)
- `files/system/` — Config files copied into the OS image
- `docs/` — Static website (GitHub Pages at zephyros.buzz)
- `.github/workflows/build.yml` — CI pipeline
- `.github/copilot-instructions.md` — Detailed architecture docs
