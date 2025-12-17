import k8s.api.core.v1 as v1
import file
import datetime
import regex
import manifests


schema TenantEnv: 
  environment: 'uat' | 'prod'
  name: str


schema ServiceConfig:
  enabled: bool = True
  service_name: str
  base_version: str = 'v1'
  override_version: str = 'v1'
  current_version: str = 'v1'
  config_status: str = "current" if current_version == override_version else "available"

  check:
    base_version.startswith('v'), "Version should always start with v and followed by integer representing the version of the config to use."

schema Services:
  [service: str]: ServiceConfig


get_base_config_files = lambda base_file_version, service {
  result = [
    regex.replace(
      (p.split("/") [-1]),
      ".env",
      ""
    ) for p in file.glob("./baseline/${service}/${base_file_version}.env")
  ]
  result
}

get_override_config_files = lambda config_file_version, service, environment {
  result = [
    regex.replace(
      (p.split("/") [-1]),
      ".env",
      ""
    ) for p in file.glob("./environments/${environment}/${service}/${config_file_version}.env")
  ]
  result
}

split_and_remove_comments = lambda content {
  {
    k[0]: k[1]
    for item in [
      line for line in regex.split(content, r"[\r\n]+") if line and not line.startswith('#')
    ]
    for k in [
      item.split('=', 1)
    ]
  }
}

get_base_config_data = lambda version, service {
  file_data = {
    filename: split_and_remove_comments(
      file.read("./baseline/${service}/${filename}.env")
    )
    for filename in get_base_config_files(version, service)
  }
  file_data
}

get_override_config_data = lambda version, service, environment {
  file_data = {
    filename: split_and_remove_comments(
      file.read("./environments/${environment}/${service}/${filename}.env")
    )
    for filename in get_override_config_files(version, service, environment)
  }
  file_data
}

env_data = lambda base_version, override_version, service, environment {
  fileoverride = {
    **get_base_config_data(base_version, service),
    **get_override_config_data(override_version, service, environment)
  }
  fileoverride
}

configMaps = lambda services, tenant {
  service = {
    service: v1.ConfigMap {
      metadata.name = "${tenant.name}-${services[service].service_name}-${tenant.environment}-config-${services[service].override_version}"
      metadata.labels = {
        "app.kubernete.is/component" = metadata.name
        "service" = services[service].service_name
        "enivronment" = tenant.environment
        "config-version" = services[service].override_version
        "config-status" = services[service].config_status
      }
      metadata.annotations = {
        "config.kubernetes.io/version" = services[service].override_version
        "config.kubernetes.io/version-number" = services[service].override_version.removeprefix("v")
        "config.kubernetes.io/baseline-file" = "${services[service].base_version}.env"
        "config.kubernetes.io/overrides-file" = "${services[service].override_version}-overrides.env"
        "config.kubernetes.io/created-at" = datetime.now()
        "config.kubernetes.io/current-version" = services[service].current_version
      }
      immutable: True
      data = env_data(
        services[service].base_version,
        services[service].override_version,
        services[service].service_name,
        tenant.environment)[services[service].current_version]
    } for service in services if services[service].enabled
  }
  service
}

render_configmaps_yaml = lambda services, tenant {
  yaml = manifests.yaml_stream(
    [ configMaps(services, tenant)[cm] for cm in configMaps(services, tenant) ]
  )
  yaml
}
