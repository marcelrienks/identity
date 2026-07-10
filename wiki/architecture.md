# Architecture

The deployment flow is intentionally simple: the shell entrypoint routes commands, the library modules perform the AWS work, and the manifest files provide history and rollback support.

## High-level flow

```text
deploy.sh
  -> parse CLI options and config
  -> call the relevant command module
  -> update AWS resources or publish site content
  -> write deployment state and version manifests
```

## Main components

- `deploy.sh` is the command entrypoint.
- The files in `lib/` handle configuration, AWS provisioning, S3 uploads, CloudFront invalidation, Route 53 updates, versioning, and validation.
- `.deployrc` holds user-level defaults.
- `deployments/` stores version manifests that are tracked in git.
- `.deploy/` stores local machine state that is not committed.

## Why the state is split

- `deployments/` is shared and versioned, so teammates and CI can use the same manifest history.
- `.deploy/` is local-only, which keeps machine-specific timestamps and temporary state out of git.

## Design choices

- CloudFormation is used for infrastructure provisioning.
- SHA256 hashes are used to detect changed files.
- S3 versioning and manifest files support rollback.
- CloudFront invalidation keeps the published site current.

For the command syntax, see [reference.md](reference.md). For the version lifecycle, see [deployments.md](deployments.md).
