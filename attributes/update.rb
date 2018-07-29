default['cookbook-openshift3']['control_rollback_flag'] = '/to_be_rollback'
default['cookbook-openshift3']['asynchronous_upgrade'] = false

if node['cookbook-openshift3']['control_upgrade']
  default['cookbook-openshift3']['control_upgrade_version'] = ''
  default['cookbook-openshift3']['control_upgrade_flag'] = '/to_be_replaced'
  default['cookbook-openshift3']['etcd_migrated'] = true

  if node['cookbook-openshift3']['openshift_deployment_type'] == 'enterprise'
    case node['cookbook-openshift3']['control_upgrade_version']
    when '15'
      default['cookbook-openshift3']['upgrade_ose_major_version'] = '3.5'
      default['cookbook-openshift3']['upgrade_ose_version'] = '3.5.5.31.48-1.git.0.245c039.el7'
      default['cookbook-openshift3']['upgrade_openshift_docker_image_version'] = 'v3.5.5.31.48'
    when '36'
      default['cookbook-openshift3']['upgrade_ose_major_version'] = '3.6'
      default['cookbook-openshift3']['upgrade_ose_version'] = '3.6.173.0.96-1.git.0.8f6ff22.el7'
      default['cookbook-openshift3']['upgrade_openshift_docker_image_version'] = 'v3.6.173.0.96'
    when '37'
      default['cookbook-openshift3']['upgrade_ose_major_version'] = '3.7'
      default['cookbook-openshift3']['upgrade_ose_version'] = '3.7.23-1.git.0.8edc154.el7'
      default['cookbook-openshift3']['upgrade_openshift_docker_image_version'] = 'v3.7.23'
    when '39'
      default['cookbook-openshift3']['upgrade_ose_major_version'] = '3.9'
      default['cookbook-openshift3']['upgrade_ose_version'] = '3.9.0-1.el7.git.0.ba7faec'
      default['cookbook-openshift3']['upgrade_openshift_docker_image_version'] = 'v3.9.0'
    end
  else
    case node['cookbook-openshift3']['control_upgrade_version']
    when '15'
      default['cookbook-openshift3']['upgrade_ose_major_version'] = '1.5'
      default['cookbook-openshift3']['upgrade_ose_version'] = '1.5.1-1.el7'
      default['cookbook-openshift3']['upgrade_openshift_docker_image_version'] = 'v1.5.1'
    when '36'
      default['cookbook-openshift3']['upgrade_ose_major_version'] = '3.6'
      default['cookbook-openshift3']['upgrade_ose_version'] = '3.6.1-1.0.008f2d5'
      default['cookbook-openshift3']['upgrade_openshift_docker_image_version'] = 'v3.6.1'
    when '37'
      default['cookbook-openshift3']['upgrade_ose_major_version'] = '3.7'
      default['cookbook-openshift3']['upgrade_ose_version'] = '3.7.2-1.el7.git.0.cd74924'
      default['cookbook-openshift3']['upgrade_openshift_docker_image_version'] = 'v3.7.2'
    when '39'
      default['cookbook-openshift3']['upgrade_ose_major_version'] = '3.9'
      default['cookbook-openshift3']['upgrade_ose_version'] = '3.9.0-1.el7.git.0.ba7faec'
      default['cookbook-openshift3']['upgrade_openshift_docker_image_version'] = 'v3.9.0'
    end
  end
end
