# Helm Charts Documentation

This directory contains documentation for the CF-Microservices Helm chart.

## 📚 Documentation Index

### 1. [Helm Microservices Overview](01-helm-microservices-overview.md)
- Complete list of all 10 microservices
- Service categories and resource allocation
- Architecture overview and dependencies
- Current deployment status

### 2. [Helm Commands Reference](02-helm-commands-reference.md)
- Comprehensive command reference for Helm operations
- Template viewing commands
- Deployment management commands
- Troubleshooting commands
- Tabular output formatting

## 🏗️ Chart Structure

```
helm-charts/cf-microservices/
├── Chart.yaml                  # Main chart metadata
├── values.yaml                 # Global configuration
├── templates/
│   └── _helpers.tpl            # Template helpers
├── charts/                     # Individual microservice charts
│   ├── api-gateway/
│   ├── bench-profile/
│   ├── config-service/
│   ├── daily-submissions/
│   ├── excel-service/
│   ├── frontend/
│   ├── interviews/
│   ├── naming-server/
│   ├── placements/
│   └── spring-boot-admin/
└── docs/                       # This documentation
    ├── README.md
    ├── 01-helm-microservices-overview.md
    └── 02-helm-commands-reference.md
```

## 🔗 Related Documentation

For Aurora database integration and networking details, see:
- [Aurora Database Integration](../roles/cf-db/docs/03-aurora-database-integration.md)
- [CF-DB Role Documentation](../roles/cf-db/docs/)

## 🚀 Quick Start

### View All Deployments
```bash
helm template cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev | grep "kind: Deployment" -A 5
```

### Current Release Status
```bash
helm list -n cf-dev
helm status cf-microservices-dev -n cf-dev
```

### Upgrade Release
```bash
helm upgrade cf-microservices-dev helm-charts/cf-microservices --namespace cf-dev
```

---
*Last Updated: July 30, 2025*
*Environment: cf-dev*