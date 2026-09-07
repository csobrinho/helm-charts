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
uid: null
gid: null
labels: {}
annotations: {}
extraSpec: {}
populate: {}
backup: {}
{{- end -}}

{{/*
Synthesizes mover.securityContext + mover.podSecurityContext from the
top-level `uid`/`gid` shorthand -- takes a dict {uid, gid}, each defaulting
to the other when only one is set, returns {} when NEITHER is set (0
included: root isn't supported by this shortcut, it also needs
privilegedMode: true, set mover.securityContext directly for that). Seed a
mover dict with this FIRST (lowest priority) so an explicit backup.mover /
populate.mover -- chart-wide or per persistence.<name> entry -- still wins
field-by-field via the mergeOverwrite that follows it in both templates.
*/}}
{{- define "kopiur-pvc.uidMover" -}}
{{- $uid := .uid | default .gid -}}
{{- $gid := .gid | default .uid -}}
{{- if or $uid $gid -}}
securityContext:
  runAsUser: {{ $uid }}
  runAsGroup: {{ $gid }}
podSecurityContext:
  fsGroup: {{ $gid }}
{{- else -}}
{}
{{- end -}}
{{- end -}}

{{- define "kopiur-pvc.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}
