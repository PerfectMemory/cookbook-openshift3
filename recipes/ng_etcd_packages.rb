#
# Cookbook Name:: cookbook-openshift3
# Recipe:: ng_etcd_packages
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

server_info = OpenShiftHelper::NodeHelper.new(node)
is_etcd_server = server_info.on_etcd_server?
is_new_etcd_server = server_info.on_new_etcd_server?
is_certificate_server = server_info.on_certificate_server?
etcd_servers = server_info.etcd_servers

if is_etcd_server || is_new_etcd_server
  yum_package 'Install ETCD for ETCD servers' do
    package_name 'etcd'
    action :install
    version node['cookbook-openshift3']['upgrade'] ? (node['cookbook-openshift3']['upgrade_etcd_version'] unless node['cookbook-openshift3']['upgrade_etcd_version'].nil?) : (node['cookbook-openshift3']['etcd_version'] unless node['cookbook-openshift3']['etcd_version'].nil?)
    retries 3
    notifies :restart, 'service[etcd]', :immediately if node['cookbook-openshift3']['upgrade'] && !etcd_servers.find { |etcd| etcd['fqdn'] == node['fqdn'] }.nil?
  end
end

if is_certificate_server
  yum_package 'Install ETCD for certificate/master servers' do
    package_name 'etcd'
    version node['cookbook-openshift3']['upgrade'] ? (node['cookbook-openshift3']['upgrade_etcd_version'] unless node['cookbook-openshift3']['upgrade_etcd_version'].nil?) : (node['cookbook-openshift3']['etcd_version'] unless node['cookbook-openshift3']['etcd_version'].nil?)
  end
end
