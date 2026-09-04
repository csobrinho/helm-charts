# kopiur-pvc

Creates a `PersistentVolumeClaim` wired end-to-end into [kopiur](https://github.com/home-operations/kopiur)
(a Kopia-native Kubernetes backup operator):

- the PVC itself, with the usual size/storageClass/accessModes/labels/annotations knobs
- a `SnapshotPolicy` (+ `SnapshotSchedule`) that backs it up to a `Repository`/`ClusterRepository` on a cron schedule
- a `Restore` in **passive-populator** mode, wired via the PVC's `spec.dataSourceRef`, so a brand-new/empty PVC is
  deploy-or-restored from the latest snapshot automatically — no snapshot yet (first-ever deploy) just provisions an
  empty volume instead of failing

This mirrors kopiur's own [`deploy-or-restore`](https://github.com/home-operations/kopiur/blob/main/deploy/examples/05-deploy-or-restore-gitops.yaml)
pattern. Requires the kopiur controller already installed with `installScope: cluster` (the default) — the populator
path is refused under `installScope: namespaced`.

## Usage

```bash
helm install sonarr-config oci://ghcr.io/csobrinho/charts/kopiur-pvc \
  --namespace media \
  --set pvc.size=10Gi \
  --set pvc.storageClassName=ceph-block \
  --set backup.repository.name=s3
```

Or from a Kustomize `helmCharts:` entry:

```yaml
helmCharts:
  - name: kopiur-pvc
    repo: oci://ghcr.io/csobrinho/charts
    releaseName: sonarr-config
    namespace: media
    version: 0.1.0
    valuesInline:
      pvc:
        size: 10Gi
        storageClassName: ceph-block
      backup:
        repository:
          name: s3
```

## First deploy vs. steady state

- **First-ever deploy, no snapshot exists yet:** `populate.onMissingSnapshot: Continue` (default) lets the PVC bind
  empty so the workload can start and take its first backup.
- **Every deploy after that:** the PVC's `dataSourceRef` claims the `Restore`, which resolves the `SnapshotPolicy`'s
  latest snapshot and restores it before the PVC is bound — e.g. after a PVC/node was deleted and recreated.
- **Migrating data to a differently-named/namespaced PVC:** point `populate.sourcePolicy.name`/`namespace` at the
  *old* `SnapshotPolicy` instead of leaving it defaulted to this release's own policy.

## Values

| Key | Default | Description |
|---|---|---|
| `nameOverride` | `""` | Name used for the PVC / SnapshotPolicy / SnapshotSchedule / Restore (defaults to the release name). |
| `namespaceOverride` | `""` | Namespace for all resources (defaults to the release namespace). |
| `commonLabels` / `commonAnnotations` | `{}` | Applied to every rendered resource. |
| `pvc.accessModes` | `[ReadWriteOnce]` | PVC access modes. |
| `pvc.size` | `10Gi` | Requested PVC storage. |
| `pvc.storageClassName` | `""` | StorageClass; empty = cluster default. |
| `pvc.volumeMode` | `Filesystem` | `Filesystem` or `Block`. |
| `pvc.labels` / `pvc.annotations` | `{}` | Extra metadata on the PVC only. |
| `populate.enabled` | `true` | Wire `dataSourceRef` to a passive-populator `Restore`. |
| `populate.onMissingSnapshot` | `Continue` | `Continue` (bootstrap-friendly) or `Fail`. |
| `populate.waitTimeout` | `""` | How long to wait for the source snapshot before giving up. |
| `populate.offset` | `0` | 0 = latest snapshot, 1 = previous, ... |
| `populate.asOf` | `""` | RFC3339 timestamp for point-in-time restore. |
| `populate.credentialProjection` | `false` | Copy repo credentials into this namespace for the restore Job. |
| `populate.sourcePolicy.name` / `.namespace` | `""` | Restore from a different SnapshotPolicy (defaults to this chart's own policy). |
| `backup.enabled` | `true` | Render the `SnapshotPolicy` (+ `SnapshotSchedule`). |
| `backup.repository.kind` / `.name` / `.namespace` | `ClusterRepository` / `s3` / `""` | Repository this PVC backs up to. |
| `backup.volumeSnapshotClassName` | `""` | VolumeSnapshotClass for the CSI-snapshot copy method. |
| `backup.compression` | `{compressor: zstd}` | Kopia compression settings. |
| `backup.retention` | see `values.yaml` | GFS retention (`keepLatest/Hourly/Daily/Weekly/Monthly/Annual`). |
| `backup.mover` | `{}` | Per-run mover overrides (resources, cache, securityContext). |
| `backup.credentialProjection.enabled` | `false` | Copy repo credentials into this namespace for backup Jobs. |
| `backup.suspend` | `false` | Pause scheduled runs. |
| `backup.schedule.cron` | `H 2 * * *` | Cron for the `SnapshotSchedule`; empty renders no schedule. |
| `backup.schedule.jitter` | `30m` | Deterministic jitter. |
| `backup.schedule.*` | see `values.yaml` | `runOnCreate`, `timezone`, `suspend`, `concurrencyPolicy`, `startingDeadlineSeconds`. |
| `backup.extraSpec` | `{}` | Deep-merged into `SnapshotPolicy.spec` (hooks, files, staging, identity, ...). |
| `backup.scheduleExtraSpec` | `{}` | Deep-merged into `SnapshotSchedule.spec`. |
| `pvcExtraSpec` | `{}` | Deep-merged into the PVC's `spec`. |
| `restoreExtraSpec` | `{}` | Deep-merged into `Restore.spec`. |

## Source Code

* <https://github.com/csobrinho/helm-charts>
* <https://github.com/home-operations/kopiur>
