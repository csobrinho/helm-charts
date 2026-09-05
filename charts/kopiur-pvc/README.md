# kopiur-pvc

Creates one or more `PersistentVolumeClaim`s wired end-to-end into [kopiur](https://github.com/home-operations/kopiur)
(a Kopia-native Kubernetes backup operator), keyed under `persistence:` with the same field naming as
[bjw-s-labs app-template](https://bjw-s-labs.github.io/helm-charts/docs/app-template/reference/persistence/) /
TrueCharts (`size`, `storageClass`, `accessMode`, `retain`, ...). For each entry:

- the PVC itself, with the usual size/storageClass/accessMode/labels/annotations knobs
- a `SnapshotPolicy` (+ `SnapshotSchedule`) that backs it up to a `Repository`/`ClusterRepository` on a cron schedule
- a `Restore` in **passive-populator** mode, wired via the PVC's `spec.dataSourceRef`, so a brand-new/empty PVC is
  deploy-or-restored from the latest snapshot automatically — no snapshot yet (first-ever deploy) just provisions an
  empty volume instead of failing

This mirrors kopiur's own [`deploy-or-restore`](https://github.com/home-operations/kopiur/blob/main/deploy/examples/05-deploy-or-restore-gitops.yaml)
pattern. Requires the kopiur controller already installed with `installScope: cluster` (the default) — the populator
path is refused under `installScope: namespaced`.

There is no single-PVC mode: `persistence` is the only way to get a PVC out of this chart, and it's empty by default
— you must set at least one entry (`values.schema.json` enforces this).

## Usage

```bash
helm install esphome oci://ghcr.io/csobrinho/helm-charts/kopiur-pvc \
  --namespace esphome \
  --set persistence.esphome-config.size=10Gi \
  --set persistence.esphome-config.storageClass=ceph-block \
  --set backup.repository.name=s3
```

Or from a Kustomize `helmCharts:` entry:

```yaml
helmCharts:
  - name: kopiur-pvc
    repo: oci://ghcr.io/csobrinho/helm-charts
    releaseName: esphome
    namespace: esphome
    version: 0.1.0
    valuesInline:
      backup:
        repository:
          name: s3
      persistence:
        esphome-config:
          size: 10Gi
          storageClass: ceph-block
```

Multiple volumes with different treatment, in one release (`backup.repository.name` is set once and shared; `media`
sparse-overrides just what it needs):

```yaml
helmCharts:
  - name: kopiur-pvc
    repo: oci://ghcr.io/csobrinho/helm-charts
    releaseName: plex
    namespace: media
    version: 0.1.0
    valuesInline:
      backup:
        repository:
          name: s3
      persistence:
        media:
          size: 2Ti
          storageClass: ceph-block
          populate:
            enabled: false # too large to deploy-or-restore; backup-only
        config:
          size: 5Gi
          storageClass: ceph-block
          retain: true # helm.sh/resource-policy: keep — survives `helm uninstall`
```

## First deploy vs. steady state

- **First-ever deploy, no snapshot exists yet:** `populate.onMissingSnapshot: Continue` (default) lets the PVC bind
  empty so the workload can start and take its first backup.
- **Every deploy after that:** the PVC's `dataSourceRef` claims the `Restore`, which resolves the `SnapshotPolicy`'s
  latest snapshot and restores it before the PVC is bound — e.g. after a PVC/node was deleted and recreated.
- **Migrating data to a differently-named/namespaced PVC:** point `populate.sourcePolicy.name`/`namespace` at the
  _old_ `SnapshotPolicy` instead of leaving it defaulted to this release's own policy.

## Values

`populate:`/`backup:` are shared defaults; each `persistence.<name>.populate`/`.backup` sparse-overrides them for
that entry only (Helm's values-merge can't do this automatically across differently-named map keys, so the chart
does it in-template — see the comment above `persistence:` in `values.yaml`).

| Key                                                 | Default                           | Description                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ---------------------------------------------------- | --------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `namespaceOverride`                                  | `""`                              | Namespace for all resources (defaults to the release namespace).                                                                                                                                                                                                                                                                                                                                                                                        |
| `commonLabels` / `commonAnnotations`                 | `{}`                              | Applied to every rendered resource.                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `persistence`                                        | `{}`                              | One PVC per entry, keyed by PVC name. **Required — at least one entry.** See `values.yaml` for the full per-entry example (`media`/`config`).                                                                                                                                                                                                                                                                                                          |
| `persistence.<name>.enabled`                         | `true`                            | Render this entry. Set `false` to temporarily drop one entry without deleting its config.                                                                                                                                                                                                                                                                                                                                                              |
| `persistence.<name>.size`                            | —                                 | Requested PVC storage (e.g. `"10Gi"`). **Required on every entry** — there is no chart-wide default.                                                                                                                                                                                                                                                                                                                                                    |
| `persistence.<name>.storageClass`                    | `""`                              | StorageClass; empty = cluster default.                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `persistence.<name>.accessMode`                      | `ReadWriteOnce`                   | Single access mode (bjw-s-labs/TrueCharts naming). Use `extraSpec.accessModes` for more than one.                                                                                                                                                                                                                                                                                                                                                       |
| `persistence.<name>.volumeMode`                      | `Filesystem`                      | `Filesystem` or `Block`.                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `persistence.<name>.retain`                          | `false`                           | Stamp `helm.sh/resource-policy: keep` — the PVC survives `helm uninstall`. Independent of, and in addition to, `argocd.protectPvcFromDeletion` below.                                                                                                                                                                                                                                                                                                  |
| `persistence.<name>.labels` / `.annotations`         | `{}`                              | Extra metadata on this PVC only.                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `persistence.<name>.extraSpec`                       | `{}`                              | Deep-merged into this PVC's `spec`.                                                                                                                                                                                                                                                                                                                                                                                                                     |
| `persistence.<name>.populate`                        | `{}`                              | Sparse override of `populate:` below, for this entry only.                                                                                                                                                                                                                                                                                                                                                                                              |
| `persistence.<name>.backup`                          | `{}`                              | Sparse override of `backup:` below, for this entry only.                                                                                                                                                                                                                                                                                                                                                                                                |
| `populate.enabled`                                   | `true`                            | Wire `dataSourceRef` to a passive-populator `Restore`.                                                                                                                                                                                                                                                                                                                                                                                                  |
| `populate.onMissingSnapshot`                         | `Continue`                        | `Continue` (bootstrap-friendly) or `Fail`.                                                                                                                                                                                                                                                                                                                                                                                                              |
| `populate.waitTimeout`                               | `""`                              | How long to wait for the source snapshot before giving up.                                                                                                                                                                                                                                                                                                                                                                                              |
| `populate.offset`                                    | `0`                               | 0 = latest snapshot, 1 = previous, ...                                                                                                                                                                                                                                                                                                                                                                                                                  |
| `populate.asOf`                                      | `""`                              | RFC3339 timestamp for point-in-time restore.                                                                                                                                                                                                                                                                                                                                                                                                            |
| `populate.credentialProjection`                      | `true`                            | Copy repo credentials into this namespace for the restore Job (a shared `ClusterRepository`'s Secret normally lives in one namespace). Requires the kopiur controller's `features.credentialProjection.enabled=true`.                                                                                                                                                                                                                                 |
| `populate.mover.inheritSecurityContextFrom`          | `{snapshot: {}}`                  | Restore-mover identity. Defaults to the UID/GID kopia _recorded on the backup itself_ — the only mode needing no live workload pod, so it works on a freshly rebuilt cluster (exactly what the populator runs before).                                                                                                                                                                                                                                 |
| `populate.sourcePolicy.name` / `.namespace`          | `""`                              | Restore from a different SnapshotPolicy (defaults to this entry's own policy).                                                                                                                                                                                                                                                                                                                                                                          |
| `populate.extraSpec`                                 | `{}`                              | Deep-merged into `Restore.spec`.                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `backup.enabled`                                     | `true`                            | Render the `SnapshotPolicy` (+ `SnapshotSchedule`).                                                                                                                                                                                                                                                                                                                                                                                                      |
| `backup.repository.kind` / `.name` / `.namespace`    | `ClusterRepository` / `s3` / `""` | Repository this PVC backs up to.                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `backup.copyMethod`                                  | `Direct`                          | How the source volume is captured before kopia reads it. **Set to `Snapshot`/`Clone` only if your CSI driver's VolumeSnapshot is a real CoW/delta snapshot** (e.g. Ceph RBD/CephFS) — on a driver that full-copies on snapshot (e.g. proxmox-csi), those modes double storage on every scheduled run. `Direct` reads the live volume with no point-in-time guarantee; give a live database its own policy with a `beforeSnapshot` hook via `extraSpec`. |
| `backup.volumeSnapshotClassName`                     | `""`                              | VolumeSnapshotClass; only used when `copyMethod` is `Snapshot`/`Clone`.                                                                                                                                                                                                                                                                                                                                                                                 |
| `backup.readOnly`                                    | `true`                            | Mount the source read-only. Leave `true` — flipping it is only meaningful to let a mover `fsGroup` take effect, and under `copyMethod: Direct` that recursively chgrps the **live** volume permanently. Prefer `inheritSecurityContextFrom` below instead.                                                                                                                                                                                             |
| `backup.acknowledgeLiveMutation`                     | `false`                           | Required alongside `readOnly: false` + `copyMethod: Direct` (webhook-enforced); leave `false` unless deliberate.                                                                                                                                                                                                                                                                                                                                        |
| `backup.inheritSecurityContextFrom`                  | `{}`                              | Backup-mover UID/GID identity (`workloadSelector`/`pvcConsumer`/`snapshot`, oneOf). Prefer `workloadSelector` (matches the Deployment's pod template) over `pvcConsumer` (resolves the pod currently mounting the PVC — nothing if scaled to zero when the schedule fires). Requires the workload to pin `runAsUser` explicitly.                                                                                                                       |
| `backup.compression`                                 | `{compressor: zstd}`              | Kopia compression settings.                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `backup.retention`                                   | see `values.yaml`                 | GFS retention (`keepLatest/Hourly/Daily/Weekly/Monthly/Annual`).                                                                                                                                                                                                                                                                                                                                                                                         |
| `backup.mover`                                       | `{}`                              | Per-run mover overrides (resources, cache, securityContext) — merged with `inheritSecurityContextFrom` above into one `mover` object.                                                                                                                                                                                                                                                                                                                  |
| `backup.errorHandling`                               | `{}`                              | e.g. `{ignoreFileErrors: true}`. Leave `{}` (fail loudly) unless a specific error class is deliberately swallowed — it otherwise turns a loud failure into a snapshot quietly missing files.                                                                                                                                                                                                                                                           |
| `backup.verification.enabled`                        | `true`                            | Weekly quick (blob-level) verification with `successExpr: "stats.errors == 0 && stats.files > 0"` — catches a snapshot that "succeeds" with zero files. `enabled` is chart-only (stripped before rendering); everything else merges verbatim into the CRD's `verification` object. Set `false` to disable.                                                                                                                                          |
| `backup.credentialProjection.enabled`                | `true`                            | Copy repo credentials into this namespace for backup Jobs (same shared-repository reasoning as `populate.credentialProjection`).                                                                                                                                                                                                                                                                                                                       |
| `backup.suspend`                                     | `false`                           | Pause scheduled runs.                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `backup.schedule.cron`                               | `H 2 * * *`                       | Cron for the `SnapshotSchedule`; empty renders no schedule.                                                                                                                                                                                                                                                                                                                                                                                             |
| `backup.schedule.jitter`                             | `30m`                             | Deterministic jitter.                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| `backup.schedule.*`                                  | see `values.yaml`                 | `runOnCreate`, `timezone`, `suspend`, `concurrencyPolicy`, `startingDeadlineSeconds`.                                                                                                                                                                                                                                                                                                                                                                    |
| `backup.schedule.extraSpec`                          | `{}`                              | Deep-merged into `SnapshotSchedule.spec`.                                                                                                                                                                                                                                                                                                                                                                                                                |
| `backup.extraSpec`                                   | `{}`                              | Deep-merged into `SnapshotPolicy.spec` (hooks, files, staging, groupBy, identity, ...).                                                                                                                                                                                                                                                                                                                                                                 |
| `argocd.enabled`                                     | `true`                            | Stamp ArgoCD sync-wave + deletion-protection annotations (inert outside ArgoCD).                                                                                                                                                                                                                                                                                                                                                                        |
| `argocd.syncWaves.backup` / `.restore` / `.pvc`      | `-2` / `-1` / `0`                 | Apply order: SnapshotPolicy/Schedule, then Restore, then the PVC — so the populator claim exists and resolves before the PVC ever binds.                                                                                                                                                                                                                                                                                                               |
| `argocd.protectPvcFromDeletion`                      | `true`                            | Adds `argocd.argoproj.io/sync-options: Prune=false,Delete=false` to every PVC so ArgoCD never deletes a live volume on a prune or a cascading Application delete.                                                                                                                                                                                                                                                                                      |

## Testing

`tests/render_test.sh` re-renders every `tests/<name>-values.yaml` fixture and diffs it byte-for-byte
against the checked-in `tests/<name>-expected.yaml` golden file — run by `.github/workflows/lint-test.yaml`
on every push/PR. Currently one fixture (`esphome`, a realistic single-PVC ESPHome config volume); add more
`<name>-values.yaml` files as new cases come up (e.g. a multi-entry `persistence` example).

```bash
charts/kopiur-pvc/tests/render_test.sh              # run
UPDATE=1 charts/kopiur-pvc/tests/render_test.sh     # regenerate golden files after a deliberate change
```

## Source Code

- <https://github.com/csobrinho/helm-charts>
- <https://github.com/home-operations/kopiur>
- <https://bjw-s-labs.github.io/helm-charts/docs/app-template/reference/persistence/>
