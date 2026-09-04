{{- define "kopiur-pvc.name" -}}
{{- .Values.nameOverride | default .Release.Name -}}
{{- end -}}

{{- define "kopiur-pvc.namespace" -}}
{{- .Values.namespaceOverride | default .Release.Namespace -}}
{{- end -}}

{{- define "kopiur-pvc.restoreName" -}}
{{- printf "%s-restore" (include "kopiur-pvc.name" .) -}}
{{- end -}}

{{- define "kopiur-pvc.scheduleName" -}}
{{- printf "%s-schedule" (include "kopiur-pvc.name" .) -}}
{{- end -}}

{{- define "kopiur-pvc.labels" -}}
app.kubernetes.io/name: {{ include "kopiur-pvc.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "kopiur-pvc.annotations" -}}
{{- with .Values.commonAnnotations }}
{{ toYaml . }}
{{- end }}
{{- end -}}
