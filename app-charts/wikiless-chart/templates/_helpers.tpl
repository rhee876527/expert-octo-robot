# Get domain
{{- define "get.domain" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.MY_DOMAIN | b64dec -}}
{{- end -}}
