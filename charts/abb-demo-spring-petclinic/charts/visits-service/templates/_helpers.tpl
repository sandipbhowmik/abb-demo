{{- define "visits-service.fullname" -}}
{{ printf "%s-visits-service" .Release.Name }}
{{- end }}

{{- define "visits-service.labels" -}}
app.kubernetes.io/name: visits-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}