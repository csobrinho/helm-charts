# helm-charts

Personal Helm charts, published as OCI artifacts to `oci://ghcr.io/csobrinho/helm-charts/<name>`.

| Chart | Description |
|---|---|
| [kopiur-pvc](charts/kopiur-pvc) | PVC wired to [kopiur](https://github.com/home-operations/kopiur) for scheduled backups and deploy-or-restore population. |

## Layout

Each chart lives under `charts/<name>`. `.github/workflows/lint-test.yaml` lints/templates/validates every chart on
push and PR; `.github/workflows/release.yaml` packages and pushes any chart whose `Chart.yaml` `version` changed to
GHCR on merge to `main`.

To publish a new version of a chart: bump `version` in its `Chart.yaml` and merge to `main`. An unchanged version is
skipped (and OCI registries refuse to overwrite an existing tag regardless).

## Local development

```bash
helm lint charts/kopiur-pvc
helm template test charts/kopiur-pvc --namespace default
```
