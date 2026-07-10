# Deployments

Deployment manifests live in `deployments/` and are tracked in git. They provide a version history that the deployment tool can use for updates and rollbacks.

## What a manifest contains

Each manifest records:

- the version identifier
- a timestamp
- the site files that were published
- hashes and sizes for change detection

## How updates use manifests

When you run `./deploy.sh update`:

1. the previous manifest is loaded
2. the current files are hashed
3. changed files are identified
4. the changed files are uploaded
5. a new manifest is written for the new version

## Rollback flow

A rollback reads an older manifest and restores the corresponding content. This is why the version history matters.

```bash
./deploy.sh rollback --version 1.0.0
```

## Viewing version history

```bash
./deploy.sh versions list
./deploy.sh versions show 1.1.0
```

## Local state vs versioned state

- `deployments/` is versioned and shared
- `.deploy/` is local-only and contains temporary state such as timestamps and cached files

For the high-level system design, see [architecture.md](architecture.md).
