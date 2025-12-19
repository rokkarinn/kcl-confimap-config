# Import required KCL modules for Kubernetes and file operations
import k8s.api.core.v1 as v1
import file
import datetime
import regex
import manifests

# Schema for tenant environment configuration
schema TenantEnv:
    environment: "uat" | "prod"  # Target environment
    name: str                     # Tenant identifier

    # Validation rules for tenant configuration
    check:
        name.islower(), "Tenant name should be all lowercase."
        environment == "uat" or environment == "prod", "Environment should be either uat or prod."

# Schema for individual service configuration
schema ServiceConfig:
    enabled: bool = True                    # Service enabled flag
    service_name: str                       # Service identifier
    base_version: str = 'v1'                # Base configuration version
    override_version: str = 'v1'            # Environment override version
    current_version: str = override_version if override_version == base_version else 'v1'  # Active version
    config_status: str = "current" if current_version == override_version else "available"  # Status indicator

    # Validation rules for service configuration
    check:
        service_name.islower(), "Service name should be all lowercase."
        base_version.startswith('v'), "Version should always start with v and followed by integer representing the version of the config to use."
        override_version.startswith('v'), "Version should always start with v and followed by integer representing the version of the config to use."
        current_version.startswith('v'), "Version should always start with v and followed by integer representing the version of the config to use."

# Schema for collection of services (dictionary mapping)
schema Services:
    [service: str]: ServiceConfig

# Get list of base configuration files for a service and version
get_base_config_files = lambda base_file_version, service {
    result = [regex.replace((p.split("/")[-1]), ".env", "") for p in file.glob("./baseline/${service}/${base_file_version}.env")]
    result
}

# Get list of override configuration files for a service, version, and environment
get_override_config_files = lambda config_file_version, service, environment {
    result = [regex.replace((p.split("/")[-1]), ".env", "") for p in file.glob("./environments/${environment}/${service}/${config_file_version}.env")]
    result
}

# Parse environment file content and remove comments
split_and_remove_comments = lambda content {
    {k[0]: k[1] for item in [line for line in regex.split(content, r"[\r\n]+") if line and not line.startswith('#')] for k in [
        item.split('=', 1)
    ]}
}

# Load and parse base configuration data for a service and version
get_base_config_data = lambda version, service {
    file_data = {filename: split_and_remove_comments(file.read("./baseline/${service}/${filename}.env")) for filename in get_base_config_files(version, service)}
    file_data
}

# Load and parse override configuration data for a service, version, and environment
get_override_config_data = lambda version, service, environment {
    file_data = {filename: split_and_remove_comments(file.read("./environments/${environment}/${service}/${filename}.env")) for filename in get_override_config_files(version, service, environment)}
    file_data
}

# Merge base and override configuration data (overrides take precedence)
env_data = lambda base_version, override_version, service, environment {
    fileoverride = {
        **get_base_config_data(base_version, service)      # Base configuration
        **get_override_config_data(override_version, service, environment)  # Environment overrides
    }
    fileoverride
}

# Generate Kubernetes ConfigMaps for enabled services
configMaps = lambda services, tenant {
    service = {service: v1.ConfigMap {
        # Generate unique ConfigMap name with tenant, service, environment, and version
        metadata.name = "${tenant.name}-${services[service].service_name}-${tenant.environment}-config-${services[service].override_version}"
        metadata.labels = {
            "app.kubernetes.io/component" = metadata.name  # Fixed typo from "kubernete.is" to "kubernetes.io"
            "service" = services[service].service_name
            "environment" = tenant.environment  # Fixed typo from "enivronment" to "environment"
            "config-version" = services[service].override_version
            "config-status" = services[service].config_status
        }
        metadata.annotations = {
            "config.kubernetes.io/version" = services[service].override_version
            "config.kubernetes.io/version-number" = services[service].override_version.removeprefix("v")  # Remove 'v' prefix for numeric version
            "config.kubernetes.io/baseline-file" = "${services[service].base_version}.env"
            "config.kubernetes.io/overrides-file" = "${services[service].override_version}-overrides.env"
            "config.kubernetes.io/created-at" = datetime.now()  # Timestamp for creation
            "config.kubernetes.io/current-version" = services[service].current_version
        }
        immutable: True  # Make ConfigMap immutable for better security and performance
        # Load merged configuration data (base + overrides) for the current version
        data = env_data(services[service].base_version, services[service].override_version, services[service].service_name, tenant.environment)[services[service].current_version]
    } for service in services if services[service].enabled}  # Only process enabled services
    service
}

# Render all ConfigMaps as a YAML stream for Kubernetes deployment
render_configmaps_yaml = lambda services, tenant {
    yaml = manifests.yaml_stream([configMaps(services, tenant)[cm] for cm in configMaps(services, tenant)])
    yaml
}
