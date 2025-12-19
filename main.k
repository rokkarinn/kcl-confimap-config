# Import local configuration module
import .config as config

# Define tenant environment configuration
tenant = config.TenantEnv {
  environment = 'uat'  # Target environment (uat or prod)
  name = 'belgium'     # Tenant identifier (must be lowercase)
}

# Define services configuration with versioning and enablement
services = config.Services {
  # Time service configuration
  time: {
    service_name = 'time'    # Service identifier
    base_version = 'v2'       # Base configuration version to use
    enabled = True            # Enable this service for config generation
  }

  # Wallet service configuration (uses defaults)
  wallet: {
    service_name = 'wallet'   # Service identifier
    # Uses default base_version = 'v1' and enabled = True
  }

  # Access service configuration (disabled)
  access: {
    service_name = 'access'   # Service identifier
    enabled = False           # Disable this service for config generation
  }
}

# Generate all ConfigMaps as YAML manifests for the configured services
all_configmaps = config.render_configmaps_yaml(services, tenant)
