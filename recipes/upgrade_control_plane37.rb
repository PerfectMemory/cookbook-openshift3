#
# Cookbook Name:: cookbook-openshift3
# Recipe:: upgrade_control_plane37
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

# This must be run before any upgrade takes place.
# It creates the service signer certs (and any others) if they were not in
# existence previously.

Chef::Log.error("Upgrade will be skipped. Could not find the flag: #{node['cookbook-openshift3']['control_upgrade_flag']}") unless ::File.file?(node['cookbook-openshift3']['control_upgrade_flag'])

if ::File.file?(node['cookbook-openshift3']['control_upgrade_flag'])

  node.force_override['cookbook-openshift3']['upgrade'] = true # ~FC019
  node.force_override['cookbook-openshift3']['ose_major_version'] = node['cookbook-openshift3']['upgrade_ose_major_version'] # ~FC019
  node.force_override['cookbook-openshift3']['ose_version'] = node['cookbook-openshift3']['upgrade_ose_version'] # ~FC019
  node.force_override['cookbook-openshift3']['openshift_docker_image_version'] = node['cookbook-openshift3']['upgrade_openshift_docker_image_version'] # ~FC019

  server_info = OpenShiftHelper::NodeHelper.new(node)
  is_master_server = server_info.on_master_server?

  if is_master_server
    return unless server_info.check_master_upgrade?(server_info.first_etcd, node['cookbook-openshift3']['control_upgrade_version'])

    config_options = YAML.load_file("#{node['cookbook-openshift3']['openshift_common_master_dir']}/master/master-config.yaml")
    unless config_options['kubernetesMasterConfig']['apiServerArguments'].key?('storage-backend')
      Chef::Log.error('The cluster must be migrated to etcd v3 prior to upgrading to 3.7')
      node.run_state['issues_detected'] = true
    end
  end

  include_recipe 'cookbook-openshift3::upgrade_control_plane37_part1' unless node.run_state['issues_detected']
end
