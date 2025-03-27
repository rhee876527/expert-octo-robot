# Get application directory
{{- define "get.appsDir" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.APPS_DIR | b64dec -}}
{{- end -}}

# Get SEARXNG_SECRET
{{- define "get.srxSecret" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.SRX_SEC | b64dec -}}
{{- end -}}

# Get domain
{{- define "get.domain" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.MY_DOMAIN | b64dec -}}
{{- end -}}
