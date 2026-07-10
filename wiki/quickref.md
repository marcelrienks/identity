# Quick reference

Use this page as a short cheat sheet. For the full explanation, see [guide.md](guide.md) and [reference.md](reference.md).

## Common commands

```bash
./deploy.sh deploy --domain marcelrienks.com --subdomain www
./deploy.sh update
./deploy.sh update --version major
./deploy.sh validate --domain marcelrienks.com
./deploy.sh rollback --version 1.0.0
./deploy.sh versions list
./deploy.sh help
```

## Common flags

- `--domain` for the primary domain
- `--subdomain` for the subdomain prefix
- `--region` for the AWS region
- `--source-dir` for the site directory
- `--dry-run` to preview actions
- `-v` or `--verbose` for debug output

## Useful links

- [guide.md](guide.md) for the main workflow
- [reference.md](reference.md) for the full option list
- [architecture.md](architecture.md) for the system design
- [deployments.md](deployments.md) for manifest and rollback details
