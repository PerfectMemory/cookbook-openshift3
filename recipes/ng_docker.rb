#
# Cookbook Name:: cookbook-openshift3
# Recipe:: ng_docker
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

yum_package 'docker' do
  action :install
  version node['cookbook-openshift3']['upgrade'] ? (node['cookbook-openshift3']['upgrade_docker_version'] unless node['cookbook-openshift3']['upgrade_docker_version'].nil?) : (node['cookbook-openshift3']['docker_version'] unless node['cookbook-openshift3']['docker_version'].nil?)
  retries 3
  options node['cookbook-openshift3']['docker_yum_options'] unless node['cookbook-openshift3']['docker_yum_options'].nil?
  notifies :restart, 'service[docker]', :immediately if node['cookbook-openshift3']['upgrade']
  only_if do
    ::Mixlib::ShellOut.new('rpm -q docker').run_command.error? || node['cookbook-openshift3']['upgrade']
  end
end

template '/etc/sysconfig/docker-storage-setup' do
  source 'docker-storage.erb'
end

template '/etc/sysconfig/docker-network' do
  source 'service_docker-network.sysconfig.erb'
  notifies :restart, 'service[docker]', :immediately unless ::Mixlib::ShellOut.new('systemctl is-enabled docker').run_command.error?
end

template '/etc/sysconfig/docker' do
  source 'service_docker.sysconfig.erb'
  notifies :restart, 'service[docker]', :immediately
  notifies :enable, 'service[docker]', :immediately
end
