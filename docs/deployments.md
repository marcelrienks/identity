# Deployments - Version History & Manifest Files

This document explains how deployment manifests are stored and managed.

---

## Manifest Storage

Version manifests are stored in the **`deployments/`** folder and tracked in git.

```
deployments/
├── 1.0.0.json        ← version manifest with file hashes
├── 1.1.0.json        ← current version
└── ...
```

Each manifest contains:
- **version_id** — Version identifier (semantic versioning)
- **timestamp** — ISO 8601 deployment timestamp
- **file_count** — Number of files in this version
- **files** — Array of {path, hash, size} for each file

**Example:**
```json
{
  "version_id": "1.1.0",
  "timestamp": "2026-05-03T08:04:52Z",
  "domain": "marcelrienks.com",
  "subdomain": "www",
  "file_count": 48,
  "files": [
    {
      "path": "index.html",
      "hash": "3326ed2a1f1d79781a475028605faf7ab914b5dcd648b3c9774cf0a4eff8e4f6",
      "size": 34689
    },
    ...
  ]
}
```

---

## Local State (Machine-Specific)

The **`.deploy/`** folder is NOT tracked in git — it contains local machine state:

```
.deploy/
├── state.json                  ← current deployment metadata
└── versions/                   ← cached local copies (for speed)
    └── 1.1.0.json
```

This folder is excluded via `.gitignore` because it:
- Contains timestamps specific to when you deployed
- May contain temporary logs
- Varies between development machines

---

## How Change Detection Works

When you run `./deploy.sh update`:

1. **Load previous manifest** from `deployments/VERSION.json`
2. **Calculate current file hashes** in working directory
3. **Compare hashes** — detect changed files only
4. **Upload changed files** to S3
5. **Create new manifest** in `deployments/` with updated hashes
6. **Invalidate CloudFront** cache for changed paths

---

## Multi-Machine Deployments

Since manifests are in git:

- ✅ Clone on machine A → manifests available
- ✅ Make changes on machine A, `./deploy.sh update`
- ✅ Commit manifests to git
- ✅ Pull on machine B → new manifest available
- ✅ `./deploy.sh update` on machine B uses current manifest

---

## CI/CD Integration

For GitHub Actions or other CI/CD:

```yaml
- name: Deploy
  run: |
    ./deploy.sh update --domain marcelrienks.com
```

The manifest will be read from `deployments/` automatically.

---

## Rollback

When you rollback:

```bash
./deploy.sh rollback --version 1.0.0
```

This:
1. Reads manifest from `deployments/1.0.0.json`
2. Restores all files from that version (stored in S3 versioning)
3. Invalidates CloudFront cache
4. Creates new manifest version (e.g., `1.0.1.json`)

---

## Managing Manifests

### View deployment history

```bash
./deploy.sh versions list
```

### View specific version details

```bash
./deploy.sh versions show 1.1.0
```

### Manual manifest creation (if needed)

After a fresh deployment without manifests, you can restore history:

```bash
# Query S3 for all files and recreate manifest
aws s3 ls s3://id-marcelrienks.com-static --recursive | \
  while read line; do
    # Extract path and calculate hash
  done > deployments/1.1.0.json
```

Most of the time, this is automatic — included in `./deploy.sh deploy`.
