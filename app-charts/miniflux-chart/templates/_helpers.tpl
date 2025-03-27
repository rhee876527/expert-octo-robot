# Get application directory
{{- define "get.appsDir" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.APPS_DIR | b64dec -}}
{{- end -}}

# Get postgres password
{{- define "get.miniPass" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.MINI_PASS | b64dec -}}
{{- end -}}

# Get domain
{{- define "get.domain" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.MY_DOMAIN | b64dec -}}
{{- end -}}
