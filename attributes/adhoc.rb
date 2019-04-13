default['cookbook-openshift3']['openshift_adhoc_reboot_node'] = false

default['cookbook-openshift3']['adhoc_redeploy_certificates'] = false
default['cookbook-openshift3']['adhoc_redeploy_etcd_ca'] = false
default['cookbook-openshift3']['adhoc_redeploy_cluster_ca'] = false
default['cookbook-openshift3']['adhoc_migrate_etcd_flag'] = '/to_be_migrated_etcd'

default['cookbook-openshift3']['redeploy_etcd_ca_control_flag'] = '/to_be_replaced_ca_etcd'
default['cookbook-openshift3']['redeploy_etcd_certs_control_flag'] = '/to_be_replaced_certs'

default['cookbook-openshift3']['redeploy_cluster_ca_certserver_control_flag'] = '/to_be_replaced_ca_cluster'
default['cookbook-openshift3']['redeploy_cluster_ca_masters_control_flag'] = '/to_be_replaced_masters'
default['cookbook-openshift3']['redeploy_cluster_ca_nodes_control_flag'] = '/to_be_replaced_nodes'
default['cookbook-openshift3']['redeploy_cluster_hosted_certserver_control_flag'] = '/to_be_replaced_hosted_cluster'

default['cookbook-openshift3']['adhoc_reset_control_flag'] = '/to_be_reset_node'

default['cookbook-openshift3']['adhoc_turn_off_openshift3_cookbook'] = '/to_be_replaced_turn_off_openshift3_cookbook'
default['cookbook-openshift3']['adhoc_uninstall_openshift3_cookbook'] = '/to_be_replaced_uninstall_openshift3_cookbook'

default['cookbook-openshift3']['adhoc_redeploy_registry_certificates_flag'] = '/to_be_replaced_registry_certificates'

default['cookbook-openshift3']['adhoc_recovery_etcd_certificate_server'] = '/to_be_recovered_etcd_certificate_server'
default['cookbook-openshift3']['adhoc_recovery_etcd_member'] = '/to_be_recovered_etcd_member'
default['cookbook-openshift3']['adhoc_recovery_etcd_emergency'] = '/to_be_recovered_etcd_emergency'
default['cookbook-openshift3']['adhoc_clean_etcd_flag'] = '/to_be_clean_etcd'
