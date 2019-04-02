#
# Cookbook Name:: cookbook-openshift3
# Recipe:: upgrade_control_plane15
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
  node.force_override['yum']['main']['exclude'] = node['cookbook-openshift3']['custom_pkgs_excluder'] unless node['cookbook-openshift3']['custom_pkgs_excluder'].nil? # ~FC019

  server_info = OpenShiftHelper::NodeHelper.new(node)
  is_etcd_server = server_info.on_etcd_server?
  is_master_server = server_info.on_master_server?
  is_node_server = server_info.on_node_server?
  is_first_master = server_info.on_first_master?

  if defined? node['cookbook-openshift3']['upgrade_repos']
    node.force_override['cookbook-openshift3']['yum_repositories'] = node['cookbook-openshift3']['upgrade_repos'] # ~FC019
  end

  if is_master_server
    return unless server_info.check_master_upgrade?(server_info.first_etcd, node['cookbook-openshift3']['control_upgrade_version'])
  end

  include_recipe 'yum::default'
  include_recipe 'cookbook-openshift3::packages'
  include_recipe 'cookbook-openshift3::disable_excluder'

  if is_etcd_server
    log 'Upgrade for ETCD [STARTED]' do
      level :info
    end

    openshift_upgrade 'Generate etcd backup before upgrade' do
      action :create_backup
      etcd_action 'pre'
      target_version node['cookbook-openshift3']['control_upgrade_version']
    end

    include_recipe 'cookbook-openshift3'
    include_recipe 'cookbook-openshift3::etcd_cluster'

    openshift_upgrade 'Generate etcd backup after upgrade' do
      action :create_backup
      etcd_action 'post'
      target_version node['cookbook-openshift3']['control_upgrade_version']
    end

    log 'Upgrade for ETCD [COMPLETED]' do
      level :info
    end

    file node['cookbook-openshift3']['control_upgrade_flag'] do
      action :delete
      only_if { is_etcd_server && !is_master_server }
    end
  end

  if is_master_server
    log 'Upgrade for MASTERS [STARTED]' do
      level :info
    end

    include_recipe 'cookbook-openshift3::master'
    include_recipe 'cookbook-openshift3::excluder' unless is_node_server

    log 'Restart Master services' do
      level :info
      notifies :restart, "service[#{node['cookbook-openshift3']['openshift_service_type']}-master]", :immediately unless node['cookbook-openshift3']['openshift_HA']
      notifies :restart, "service[#{node['cookbook-openshift3']['openshift_service_type']}-master-api]", :immediately if node['cookbook-openshift3']['openshift_HA']
      notifies :restart, "service[#{node['cookbook-openshift3']['openshift_service_type']}-master-controllers]", :immediately if node['cookbook-openshift3']['openshift_HA']
      notifies :restart, 'service[openvswitch]', :immediately if is_node_server
    end

    openshift_upgrade "Mark upgrade complete for #{node['fqdn']}" do
      action :set_mark_upgrade
      target_version node['cookbook-openshift3']['control_upgrade_version']
      not_if { is_first_master }
    end

    log 'Upgrade for MASTERS [COMPLETED]' do
      level :info
    end
  end

  if is_first_master
    log 'Reconcile Cluster Roles & Cluster Role Bindings [STARTED]' do
      level :info
    end

    openshift_upgrade 'Reconcile Cluster Roles & Cluster Role Bindings' do
      action :reconcile_cluster_roles
      target_version node['cookbook-openshift3']['control_upgrade_version']
    end

    log 'Reconcile Cluster Roles & Cluster Role Bindings [COMPLETED]' do
      level :info
    end

    include_recipe 'cookbook-openshift3::upgrade_managed_hosted'

    openshift_upgrade "Mark upgrade complete for #{node['fqdn']}" do
      action :set_mark_upgrade
      target_version node['cookbook-openshift3']['control_upgrade_version']
    end

    log 'Post Upgrade for MASTERS [COMPLETED]' do
      level :info
    end
  end
  include_recipe 'cookbook-openshift3::upgrade_node15' if is_node_server
end
