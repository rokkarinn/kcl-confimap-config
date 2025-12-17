import .config as config

tenant = config.TenantEnv {
  environment = 'uat'
  name = 'belgium'
}

services = config.Services {
  time: {
    service_name = 'time'
    base_version = 'v2'
    enabled = False
  }

  wallet: {
    service_name = 'wallet'
  }

  access: {
    service_name = 'access'
  }
}

all_configmaps = config.render_configmaps_yaml(services, tenant)
