{{- define "chat-agent.fullname" -}}
{{ printf "%s-chat-agent" .Release.Name }}
{{- end }}

{{- define "chat-agent.labels" -}}
app.kubernetes.io/name: chat-agent
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}