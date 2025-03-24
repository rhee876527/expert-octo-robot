# Get application directory
{{- define "get.appsDir" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.APPS_DIR | b64dec -}}
{{- end -}}

# Get email for zerossl
{{- define "get.email" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.MY_EMAIL | b64dec -}}
{{- end -}}

# Get domain
{{- define "get.domain" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.MY_DOMAIN | b64dec -}}
{{- end -}}

# Get user
{{- define "get.authuser" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.BUSER | b64dec -}}
{{- end -}}

# Get pass
{{- define "get.authpass" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.BPASS | b64dec -}}
{{- end -}}

