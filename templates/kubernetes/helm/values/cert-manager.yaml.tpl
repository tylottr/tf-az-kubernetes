global:
  rbac:
    create: true
replicaCount: 1
resources:
  limits:
    cpu: 20m
    memory: 64Mi
  requests:
    cpu: 10m
    memory: 32Mi
webhook:
  enabled: false
cainjector:
  enabled: false