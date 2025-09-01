# HomeLab

This repo contains Ansible playbooks, Bash scripts, and OpenTofu
configurations for things in my HomeLab.

## `pre-commit`

Ensure `podman` works and `docker` CLI works with `podman` engine:

```bash
brew install podman docker
podman machine init
podman machine start
sudo podman-mac-helper
```

Pull `megalinter` image:

```bash
docker pull docker.io/oxsecurity/megalinter:v8
```

Create MegaLinter config:

```bash
npx mega-linter-runner --install
```

Add pre-commit hook:

```bash
prek install
```

Run `pre-commit` hook:

```bash
prek
```

Upgrade `pre-commit` hook:

```bash
prek autoupdate --freeze
```

The `prek` hook uses `megalinter-full` as the container name. If it is already started and you cancel it, you need to remove that container:

```bash
docker container stop megalinter-full
```
