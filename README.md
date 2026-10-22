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

Charts are signed (cosign keyless, via GitHub's OIDC) on publish. Verify with:

```bash
cosign verify ghcr.io/csobrinho/helm-charts/kopiur-pvc:0.1.0 \
  --certificate-identity-regexp 'https://github.com/csobrinho/helm-charts/.github/workflows/release.yaml@.*' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## One-time setup before the first publish

- **GHCR package visibility**: the first `helm push` to a name creates a *private* GHCR package. A
  private package makes ArgoCD's (or anyone else's) pull fail with an auth error unless it's given a
  pull secret. Since nothing here is sensitive, make each package public right after its first push:
  repo → **Packages** (right sidebar) → the package → **Package settings** → **Change visibility** →
  **Public**.
- **Verify `oci://` end to end** before pointing a real app's `kustomization.yaml`/ArgoCD `Application`
  at this: (1) `kustomize build --enable-helm` locally against a `helmCharts:` entry using the pushed
  OCI ref, (2) the same from inside the actual ArgoCD repo-server (there's history of `oci://`
  regressions in ArgoCD's kustomize/helm managers across versions), (3) Renovate's dependency dashboard
  picks up the `oci://` chart reference for updates.

## Local development

```bash
helm lint charts/kopiur-pvc
helm template test charts/kopiur-pvc --namespace default
charts/kopiur-pvc/tests/render_test.sh
```
