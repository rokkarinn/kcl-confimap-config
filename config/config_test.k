test_tenant = lambda {
    t = TenantEnv{environment = 'uat'}
    assert t.environment == 'uat' or t.environment == 'prod', "environment must be either 'uat' or 'prod'."
}

test_tenant_name_is_lowercase = lambda {
    t = TenantEnv{environment = 'prod' name = 'belgium'}
    assert t.name.islower(), "Tenant name should be all lowercase letters."
}

test_service_config_config_status = lambda {
    s = ServiceConfig{service_name = 'test1'}
    assert s.config_status == "current" , "Service config status shoule be 'current' when override_version and base_version are equal."
}
