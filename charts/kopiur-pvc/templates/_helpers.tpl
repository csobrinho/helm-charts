{{- define "kopiur-pvc.namespace" -}}
{{- .Values.namespaceOverride | default .Release.Namespace -}}
{{- end -}}

{{/*
Field defaults for a persistence.<name> entry. Helm's values-merge only fills
in defaults for a map key that shares a name with an entry already present in
the chart's own values.yaml (persistence.config here) -- a differently-named
key (persistence.media, say) gets ONLY the fields the caller set, nothing
else, not even `enabled`. So every template normalizes its entry through this
before using it: `mergeOverwrite (fromYaml (include "kopiur-pvc.entryDefaults" $)) $rawEntry`.
`size`/`storageClass` are deliberately absent: `size` is schema-required (no
sensible shared default), and storageClass's Go zero-value ("") already means
what we want (cluster default).
*/}}
{{- define "kopiur-pvc.entryDefaults" -}}
enabled: true
existingClaim: false
accessMode: ReadWriteOnce
volumeMode: Filesystem
retain: false
labels: {}
annotations: {}
extraSpec: {}
populate: {}
backup: {}
{{- end -}}

{{- define "kopiur-pvc.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
