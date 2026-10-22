# supermarket

Runs [supermarket-api](https://github.com/csobrinho/supermarket-api) as one `CronJob` per entry in `users:`. Each job
reads its credentials from the `secret:` Secret (`CLIENT_ID`, `API_KEY`, `<USER>_REFRESH_TOKEN`, `<USER>_STORE_ID`)
and pushes metrics to the Prometheus Pushgateway at `http://infra-prometheus:9091`.

## Usage

From a Kustomize `helmCharts:` entry:

```yaml
helmCharts:
  - name: supermarket
    repo: oci://ghcr.io/csobrinho/helm-charts
    releaseName: supermarket
    namespace: tools
    version: 0.1.0
    valuesInline:
      users:
        - name: alice
          schedule: "0 * * * *"
```

## Values

| Key | Default | Description |
|---|---|---|
| `image` | `ghcr.io/csobrinho/supermarket-api:main` | Container image. |
| `secret` | `supermarket-secret` | Secret holding the credentials above. |
| `userAgent` | `okhttp/4.12.0` | `USER_AGENT` sent to the store API. |
| `appVersion` | `2026.6.0` | `APP_VERSION` sent to the store API. |
| `users` | `[]` | `{name, schedule}` entries; one CronJob `supermarket-<name>` each. |
