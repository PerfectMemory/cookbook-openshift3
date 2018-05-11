default['cookbook-openshift3']['openshift_logging_image_prefix'] = node['cookbook-openshift3']['openshift_deployment_type'] =~ /enterprise/ ? 'registry.access.redhat.com/openshift3/' : 'docker.io/openshift/origin-'
default['cookbook-openshift3']['openshift_logging_image_version'] = node['cookbook-openshift3']['openshift_deployment_type'] =~ /enterprise/ ? 'v3.7' : 'v3.7.1'
default['cookbook-openshift3']['openshift_logging_install_logging'] = true

default['cookbook-openshift3']['openshift_logging_use_ops'] = false
default['cookbook-openshift3']['openshift_logging_master_url'] = 'https://kubernetes.default.svc'
default['cookbook-openshift3']['openshift_logging_master_public_url'] = node['cookbook-openshift3']['openshift_master_public_api_url']
default['cookbook-openshift3']['openshift_logging_namespace'] = 'logging'

default['cookbook-openshift3']['openshift_logging_curator_default_days'] = 30
default['cookbook-openshift3']['openshift_logging_curator_run_hour'] = 0
default['cookbook-openshift3']['openshift_logging_curator_run_minute'] = 0
default['cookbook-openshift3']['openshift_logging_curator_run_timezone'] = 'UTC'
default['cookbook-openshift3']['openshift_logging_curator_script_log_level'] = 'INFO'
default['cookbook-openshift3']['openshift_logging_curator_log_level'] = 'ERROR'
default['cookbook-openshift3']['openshift_logging_curator_cpu_limit'] = '100m'
default['cookbook-openshift3']['openshift_logging_curator_memory_limit'] = ''
default['cookbook-openshift3']['openshift_logging_curator_nodeselector'] = {}
default['cookbook-openshift3']['openshift_logging_curator_ops_cpu_limit'] = '100m'
default['cookbook-openshift3']['openshift_logging_curator_ops_memory_limit'] = ''
default['cookbook-openshift3']['openshift_logging_curator_ops_nodeselector'] = {}

default['cookbook-openshift3']['openshift_logging_kibana_hostname'] = "kibana.#{node['cookbook-openshift3']['openshift_master_router_subdomain']}"
default['cookbook-openshift3']['openshift_logging_kibana_cpu_limit'] = ''
default['cookbook-openshift3']['openshift_logging_kibana_memory_limit'] = '736Mi'
default['cookbook-openshift3']['openshift_logging_kibana_proxy_debug'] = false
default['cookbook-openshift3']['openshift_logging_kibana_proxy_cpu_limit'] = ''
default['cookbook-openshift3']['openshift_logging_kibana_proxy_memory_limit'] = '256Mi'
default['cookbook-openshift3']['openshift_logging_kibana_replica_count'] = 1
default['cookbook-openshift3']['openshift_logging_kibana_edge_term_policy'] = 'Redirect'

default['cookbook-openshift3']['openshift_logging_kibana_nodeselector'] = {}
default['cookbook-openshift3']['openshift_logging_kibana_ops_nodeselector'] = {}

# The absolute path on the First master to the cert file to use
# for the public facing kibana certs
default['cookbook-openshift3']['openshift_logging_kibana_cert'] = ''

# The absolute path on the First master to the key file to use
# for the public facing kibana certs
default['cookbook-openshift3']['openshift_logging_kibana_key'] = ''

# The absolute path on the First master to the CA file to use
# for the public facing kibana certs
default['cookbook-openshift3']['openshift_logging_kibana_ca'] = ''

default['cookbook-openshift3']['openshift_logging_kibana_ops_hostname'] = "kibana-ops.#{node['cookbook-openshift3']['openshift_master_router_subdomain']}"
default['cookbook-openshift3']['openshift_logging_kibana_ops_cpu_limit'] = ''
default['cookbook-openshift3']['openshift_logging_kibana_ops_memory_limit'] = '736Mi'
default['cookbook-openshift3']['openshift_logging_kibana_ops_proxy_debug'] = false
default['cookbook-openshift3']['openshift_logging_kibana_ops_proxy_cpu_limit'] = ''
default['cookbook-openshift3']['openshift_logging_kibana_ops_proxy_memory_limit'] = '256Mi'
default['cookbook-openshift3']['openshift_logging_kibana_ops_replica_count'] = 1

# The absolute path on the First master to the cert file to use
# for the public facing ops kibana certs
default['cookbook-openshift3']['openshift_logging_kibana_ops_cert'] = ''

# The absolute path on the First master to the key file to use
# for the public facing ops kibana certs
default['cookbook-openshift3']['openshift_logging_kibana_ops_key'] = ''

# The absolute path on the First master to the CA file to use
# for the public facing ops kibana certs
default['cookbook-openshift3']['openshift_logging_kibana_ops_ca'] = ''

default['cookbook-openshift3']['openshift_logging_fluentd_nodeselector'] = { 'logging-infra-fluentd' => true }
default['cookbook-openshift3']['openshift_logging_fluentd_cpu_limit'] = '100m'
default['cookbook-openshift3']['openshift_logging_fluentd_memory_limit'] = '512Mi'
default['cookbook-openshift3']['openshift_logging_fluentd_es_copy'] = 'false'
default['cookbook-openshift3']['openshift_logging_fluentd_use_journal'] = 'false'
default['cookbook-openshift3']['openshift_logging_fluentd_journal_source'] = ''
default['cookbook-openshift3']['openshift_logging_fluentd_journal_read_from_head'] = 'false'
default['cookbook-openshift3']['openshift_logging_fluentd_hosts'] = %w(--all)
default['cookbook-openshift3']['openshift_logging_fluentd_buffer_queue_limit'] = 1024
default['cookbook-openshift3']['openshift_logging_fluentd_buffer_size_limit'] = '1m'

default['cookbook-openshift3']['openshift_logging_es_host'] = 'logging-es'
default['cookbook-openshift3']['openshift_logging_es_port'] = 9200
default['cookbook-openshift3']['openshift_logging_es_ca'] = '/etc/fluent/keys/ca'
default['cookbook-openshift3']['openshift_logging_es_client_cert'] = '/etc/fluent/keys/cert'
default['cookbook-openshift3']['openshift_logging_es_client_key'] = '/etc/fluent/keys/key'
default['cookbook-openshift3']['openshift_logging_es_cluster_size'] = 1
default['cookbook-openshift3']['openshift_logging_es_cpu_limit'] = ''
# The logging appenders for the root loggers to write ES logs. Valid values'] = 'file', 'console'
default['cookbook-openshift3']['openshift_logging_es_log_appenders'] = %w(file)
default['cookbook-openshift3']['openshift_logging_es_memory_limit'] = '8Gi'
default['cookbook-openshift3']['openshift_logging_es_number_of_replicas'] = 0
default['cookbook-openshift3']['openshift_logging_es_number_of_shards'] = 1
default['cookbook-openshift3']['openshift_logging_es_pvc_size'] = ''
default['cookbook-openshift3']['openshift_logging_es_pvc_prefix'] = 'logging-es'
default['cookbook-openshift3']['openshift_logging_es_recover_after_time'] = '5m'
default['cookbook-openshift3']['openshift_logging_es_storage_group'] = %w(65534)
default['cookbook-openshift3']['openshift_logging_es_nodeselector'] = {}

# Allow cluster-admin or cluster-reader to view operations index
default['cookbook-openshift3']['openshift_logging_es_ops_allow_cluster_reader'] = 'false'

default['cookbook-openshift3']['openshift_logging_es_ops_host'] = 'logging-es-ops'
default['cookbook-openshift3']['openshift_logging_es_ops_port'] = 9200
default['cookbook-openshift3']['openshift_logging_es_ops_ca'] = '/etc/fluent/keys/ca'
default['cookbook-openshift3']['openshift_logging_es_ops_client_cert'] = '/etc/fluent/keys/cert'
default['cookbook-openshift3']['openshift_logging_es_ops_client_key'] = '/etc/fluent/keys/key'
default['cookbook-openshift3']['openshift_logging_es_ops_cluster_size'] = 1
default['cookbook-openshift3']['openshift_logging_es_ops_cpu_limit'] = ''
default['cookbook-openshift3']['openshift_logging_es_ops_memory_limit'] = '8Gi'
default['cookbook-openshift3']['openshift_logging_es_ops_pvc_size'] = ''
default['cookbook-openshift3']['openshift_logging_es_ops_pvc_prefix'] = 'logging-es-ops'
default['cookbook-openshift3']['openshift_logging_es_ops_recover_after_time'] = '5m'
default['cookbook-openshift3']['openshift_logging_es_ops_storage_group'] = %w(65534)
default['cookbook-openshift3']['openshift_logging_es_ops_nodeselector'] = {}

# Storage related defaults
default['cookbook-openshift3']['openshift_logging_storage_access_modes'] = %w(ReadWriteOnce)
