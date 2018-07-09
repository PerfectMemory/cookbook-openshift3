#
# Cookbook Name:: cookbook-openshift3
# Recipe:: excluder
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

server_info = OpenShiftHelper::NodeHelper.new(node)
is_node_server = server_info.on_node_server?
is_master_server = server_info.on_master_server?

ose_major_version = node['cookbook-openshift3']['deploy_containerized'] == true ? node['cookbook-openshift3']['openshift_docker_image_version'] : node['cookbook-openshift3']['ose_major_version']

if is_node_server || node['cookbook-openshift3']['deploy_containerized']
  yum_package "#{node['cookbook-openshift3']['openshift_service_type']}-docker-excluder" do
    action :upgrade if node['cookbook-openshift3']['upgrade']
    version node['cookbook-openshift3']['excluder_version'] unless node['cookbook-openshift3']['excluder_version'].nil?
    not_if { ose_major_version.split('.')[1].to_i < 5 && node['cookbook-openshift3']['openshift_deployment_type'] != 'enterprise' }
  end

  execute "Enable #{node['cookbook-openshift3']['openshift_service_type']}-docker-excluder" do
    command "#{node['cookbook-openshift3']['openshift_service_type']}-docker-excluder disable"
    not_if { ose_major_version.split('.')[1].to_i < 5 && node['cookbook-openshift3']['openshift_deployment_type'] != 'enterprise' }
  end
end

if is_master_server || is_node_server
  yum_package "#{node['cookbook-openshift3']['openshift_service_type']}-excluder" do
    action :upgrade if node['cookbook-openshift3']['upgrade']
    version node['cookbook-openshift3']['excluder_version'] unless node['cookbook-openshift3']['excluder_version'].nil?
    not_if { ose_major_version.split('.')[1].to_i < 5 && node['cookbook-openshift3']['openshift_deployment_type'] != 'enterprise' }
  end

  execute "Enable #{node['cookbook-openshift3']['openshift_service_type']}-excluder" do
    command "#{node['cookbook-openshift3']['openshift_service_type']}-excluder disable"
    not_if { ose_major_version.split('.')[1].to_i < 5 && node['cookbook-openshift3']['openshift_deployment_type'] != 'enterprise' }
  end
end
