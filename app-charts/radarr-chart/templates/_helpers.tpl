# Get application directory
{{- define "get.appsDir" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.APPS_DIR | b64dec -}}
{{- end -}}

# Get media directory
{{- define "get.mediarootDir" -}}
{{- (lookup "v1" "Secret" .Release.Namespace .Values.secrets.name).data.MEDIA_DIR_ROOT | b64dec -}}
{{- end -}}