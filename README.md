# Catalyst Configuration Management

This project uses KCL (Konfiguration Control Language) to manage Kubernetes ConfigMaps for microservices in different environments. It provides a structured approach to configuration management with baseline configurations and environment-specific overrides.

## Overview

The configuration system supports:
- **Baseline configurations**: Default settings for each service
- **Environment overrides**: Environment-specific customizations
- **Multi-tenant support**: Different tenant configurations
- **Version management**: Configurable versioning for each service
- **Kubernetes integration**: Direct generation of ConfigMap YAML manifests

## Architecture

```
catalyst-config/
├── baseline/                    # Base configurations for all services
│   ├── access/                 # Access service configs
│   │   ├── v1.env
│   │   └── v2.env
│   ├── time/                   # Time service configs
│   │   └── v1.env
│   └── wallet/                 # Wallet service configs
│       └── v1.env
├── environments/               # Environment-specific overrides
│   ├── prod/                   # Production overrides
│   │   ├── access/
│   │   ├── time/
│   │   └── wallet/
│   └── uat/                    # UAT overrides
│       ├── access/
│       ├── time/
│       └── wallet/
├── config/                     # KCL configuration modules
│   ├── main.k                  # Core configuration logic
│   ├── kcl.mod                 # Module dependencies
│   └── config_test.k           # Test configurations
├── main.k                      # Main entry point
├── kcl.mod                     # Project dependencies
└── README.md                   # This documentation
```

## Configuration Schema

### Tenant Environment
```kcl
tenant = config.TenantEnv {
  environment = 'uat' | 'prod'
  name = 'tenant-name'  # lowercase
}
```

### Service Configuration
```kcl
services = config.Services {
  service_name: {
    service_name = 'service-name'    # lowercase
    base_version = 'v1'              # baseline version
    override_version = 'v1'           # override version
    enabled = True                    # service enabled flag
  }
}
```

## Services

### Access Service
- **Purpose**: Authentication and authorization
- **Versions**: v1, v2
- **Status**: Can be enabled/disabled per environment

### Time Service  
- **Purpose**: Time management utilities
- **Versions**: v1, v2
- **Status**: Always enabled when configured

### Wallet Service
- **Purpose**: Digital wallet functionality
- **Versions**: v1
- **Status**: Always enabled when configured

## Configuration Merging

The system follows this precedence order:
1. **Base configuration**: `baseline/{service}/{version}.env`
2. **Environment overrides**: `environments/{env}/{service}/{version}-overrides.env`

Environment overrides will merge with and replace any matching keys from the base configuration.

## ConfigMap Generation

For each enabled service, the system generates a Kubernetes ConfigMap with:

### Naming Convention
```
{tenant-name}-{service-name}-{environment}-config-{version}
```

### Labels
- `app.kubernetes.io/component`: ConfigMap name
- `service`: Service name
- `environment`: Environment (uat/prod)
- `config-version`: Configuration version
- `config-status`: "current" or "available"

### Annotations
- `config.kubernetes.io/version`: Configuration version
- `config.kubernetes.io/version-number`: Version number without 'v' prefix
- `config.kubernetes.io/baseline-file`: Base configuration file
- `config.kubernetes.io/overrides-file`: Override configuration file
- `config.kubernetes.io/created-at`: Creation timestamp
- `config.kubernetes.io/current-version`: Currently active version

## Usage

### Generate Configuration
```bash
kcl main.k
```

### Generate YAML Manifests
```bash
kcl main.k -o yaml
```

### Test Configuration
```bash
kcl config/config_test.k
```

## Configuration Files

### Environment File Format
```bash
# Comments are supported
KEY=value
ANOTHER_KEY=another_value
```

### Version Management
- Base versions: `v1`, `v2`, etc.
- Override versions: `v1-overrides`, `v2-overrides`, etc.
- Current version tracking per service

## Dependencies

- **KCL**: Konfiguration Control Language
- **k8s**: Kubernetes API schemas (v1.32.4)
- **Standard KCL modules**: file, datetime, regex, manifests

## Validation

The configuration system includes built-in validation:
- Tenant names must be lowercase
- Environment must be "uat" or "prod"
- Service names must be lowercase
- Versions must start with "v"

## Example Output

Running `kcl main.k` will generate YAML ConfigMaps like:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: belgium-time-uat-config-v2
  labels:
    app.kubernetes.io/component: belgium-time-uat-config-v2
    service: time
    environment: uat
    config-version: v2
    config-status: current
  annotations:
    config.kubernetes.io/version: v2
    config.kubernetes.io/version-number: "2"
    config.kubernetes.io/baseline-file: v2.env
    config.kubernetes.io/overrides-file: v2-overrides.env
    config.kubernetes.io/created-at: "2025-12-19T10:30:00Z"
    config.kubernetes.io/current-version: v2
immutable: true
data:
  TIME_ZONE: UTC
  LOG_LEVEL: INFO
  # ... merged configuration
```