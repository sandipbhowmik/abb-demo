{{/*
Return the fullname of the chart, used on all resources
*/}}
{{- define "otel-collector.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Return the chart name (used by labels/selectors)
*/}}
{{- define "otel-collector.name" -}}
{{- .Chart.Name -}}
{{- end }}