{{- define "config-server.fullname" -}}
{{ printf "%s-config-server" .Release.Name }}
{{- end }}

{{- define "config-server.labels" -}}
app.kubernetes.io/name: config-server
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}