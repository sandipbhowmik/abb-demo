{{- define "vets-service.fullname" -}}
{{ printf "%s-vets-service" .Release.Name }}
{{- end }}

{{- define "vets-service.labels" -}}
app.kubernetes.io/name: vets-service
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}