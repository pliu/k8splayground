{{- define "jaas-secret-name" -}}
jaas-config
{{- end -}}

{{- define "jaas-config-filename" -}}
jaas.config
{{- end -}}

{{- define "schema-registry-jaas-secret-name" -}}
schema-registry-secret-name
{{- end -}}

{{- define "kafka-monitor-name" -}}
kafka-monitor
{{- end -}}

{{- define "kafka-monitor-metrics-port" -}}
8080
{{- end -}}

{{- define "kafka-monitor-jmx-config" -}}
jmx-config.yaml
{{- end -}}

{{- define "mirrormaker2-name" -}}
mirrormaker2
{{- end -}}

{{- define "connect-config" -}}
connect.properties
{{- end -}}

{{- define "mirrormaker2-config" -}}
mm2.properties
{{- end -}}
