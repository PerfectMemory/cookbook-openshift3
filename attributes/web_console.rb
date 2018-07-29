default['cookbook-openshift3']['openshift_web_console_metrics_public_url'] = node['cookbook-openshift3']['openshift_hosted_cluster_metrics'] && node['cookbook-openshift3']['openshift_metrics_install_metrics'] ? node['cookbook-openshift3']['openshift_metrics_url'] : '""'
default['cookbook-openshift3']['openshift_web_console_logging_public_url'] = node['cookbook-openshift3']['openshift_hosted_cluster_logging'] && node['cookbook-openshift3']['openshift_logging_install_logging'] ? node['cookbook-openshift3']['openshift_logging_kibana_url'] : '""'
default['cookbook-openshift3']['openshift_web_console_logout_url'] = node['cookbook-openshift3']['openshift_master_logout_url'] ? node['cookbook-openshift3']['openshift_master_logout_url'] : '""'
default['cookbook-openshift3']['openshift_web_console_extension_script_urls'] = []
default['cookbook-openshift3']['openshift_web_console_extension_stylesheet_urls'] = []
default['cookbook-openshift3']['openshift_web_console_properties'] = {}
default['cookbook-openshift3']['openshift_web_console_inactivity_timeout_minutes'] = 0
default['cookbook-openshift3']['openshift_web_console_cluster_resource_overrides_enabled'] = false
default['cookbook-openshift3']['openshift_web_console_image'] = node['cookbook-openshift3']['openshift_deployment_type'] =~ /enterprise/ ? 'registry.access.redhat.com/openshift3/ose-web-console' : 'docker.io/openshift/origin-web-console'
