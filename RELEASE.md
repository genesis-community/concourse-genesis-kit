# v5.1.0

Bumps concourse boshrelease **7.13.2 → 8.2.2** (major v7→v8). Kit interface unchanged.

Bundled runtime (delivered by the boshrelease, not separately pinned):
- containerd 1.7.27 → **2.3.1** (remediates CVE-2024-25621, CVE-2025-64329, CVE-2026-46680)
- Go 1.24.0 → **1.26.3**

**Breaking changes — operator action required before/after upgrade:**

- **DB migration on first boot.** ATC rewrites six tables from MD5 to SHA256 on first start at v8.
  Take a DB backup before upgrading. Run `VACUUM FULL ANALYZE` on those six tables in a
  low-traffic window after the migration completes to restore query latency.
- **`put` step input default changed to `detect` (was `all`).** Audit pipeline configs for `put`
  steps that reference input directories via `params:` and add an explicit `inputs:` list.
- **Team/pipeline names containing `/` cannot be set via `set_pipeline` (v8.2.0+).** Check team
  and pipeline names across all environments before upgrading; no automatic migration occurs.
