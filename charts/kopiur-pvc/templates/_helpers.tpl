{{- define "kopiur-pvc.namespace" -}}
{{- .Values.namespaceOverride | default .Release.Namespace -}}
{{- end -}}

{{/*
Resolves .Values.pvcs to a non-empty map of pvcName -> {pvc, populate, backup}
sparse-override dict. Falls back to a single synthetic entry (nameOverride or
the release name) when pvcs is empty, so the common single-PVC case needs no
`pvcs:` at all.
*/}}
{{- define "kopiur-pvc.items" -}}
{{- if .Values.pvcs -}}
{{- toYaml .Values.pvcs -}}
{{- else -}}
{{- $name := .Values.nameOverride | default .Release.Name -}}
{{- toYaml (dict $name dict) -}}
{{- end -}}
{{- end -}}

{{- define "kopiur-pvc.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
