{{- define "customers-service.fullname" -}}
{{ printf "%s-customers-service" .Release.Name }}
{{- end }}

{{- define "customers-service.labels" -}}
app.kubernetes.io/name: customers-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}