import k8s.api.core.v1 as v1
import file
import regex
import manifests
import datetime

_version: str = option("version") or 'v1'
_base_version: str = option("baseVersion") or _version
_current_version: str = option("currentVersion") or _version
_service: str = option("svc") or 'time'
_tenant: str = option("tenant") or 'belgium'
_immutable: bool = bool(option("immutable")) or True if _environment == 'prod' else False
_environment: str = option("env") or 'uat'
_config_status: str = "current" if _current_version == _version else "available"

_base_file_path = "./baseline/${_service}"
_file_path = "./environments/${_environment}/${_service}"

_env_base_files = [ 
  regex.replace((p.split("/") [-1]), ".env", "")
  for p in file.glob("${_base_file_path}/${_base_version}.env")
]

_env_files = [ 
  regex.replace((p.split("/") [-1]), ".env", "")
  for p in file.glob("${_file_path}/${_version}-*.env")
]

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

_base_data = {
  filename: split_and_remove_comments(
    file.read("${_base_file_path}/${filename}.env")
  )
  for filename in _env_base_files
}

_data = {
  filename: split_and_remove_comments(
    file.read("${_file_path}/${filename}.env")
  )
  for filename in _env_files
}

_env_data = {
  fileoverride: {
    **_base_data[_base_version], 
    **_data[fileoverride]
  } for fileoverride in _data
}

_configMaps = { 
  file = v1.ConfigMap { 
    metadata.name = "${_tenant}-${_service}-${_environment}-config-${file.removesuffix('-overrides')}"
    metadata.labels = {
      "app.kubernete.is/component" = metadata.name
      "service" = _service
      "environemt" = _environment
      "config-version" = _version
      "config-status" = _config_status
    }
    metadata.annotations = {
      "config.kubernetes.io/version" = _version
      "config.kubernetes.io/version-number" = _version.removeprefix("v")
      "config.kubernetes.io/baseline-file" = "${_base_version}.env"
      "config.kubernetes.io/overrides-file" = "${_version}-overrides.env"
      "config.kubernetes.io/created-at" = datetime.now()
      "config.kubernetes.io/current-version" = _current_version
    }
    immutable: bool(_immutable)
    data = _env_data[file] 
  } for file in _env_files 
}

all_configmaps = manifests.yaml_stream(
  [ _configMaps[cm] for cm in _configMaps ]
)
