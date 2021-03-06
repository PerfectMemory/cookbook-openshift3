#
# Cookbook Name:: cookbook-openshift3
# Recipe:: upgrade_certificate_server
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

  if defined? node['cookbook-openshift3']['upgrade_repos']
    node.force_override['cookbook-openshift3']['yum_repositories'] = node['cookbook-openshift3']['upgrade_repos'] # ~FC019
  end

  log 'Upgrade for CERTIFICATE SERVER [STARTED]' do
    level :info
  end

  %w[excluder docker-excluder].each do |pkg|
    execute "Disable #{node['cookbook-openshift3']['openshift_service_type']}-#{pkg}" do
      command "#{node['cookbook-openshift3']['openshift_service_type']}-#{pkg} enable"
      only_if "rpm -q #{node['cookbook-openshift3']['openshift_service_type']}-#{pkg}"
    end
  end

  include_recipe 'cookbook-openshift3::packages'
  openshift_master_pkg 'Upgrade OpenShift Master Packages for Certificate Server'
  include_recipe 'cookbook-openshift3::etcd_packages'
  include_recipe 'cookbook-openshift3::excluder'

  include_recipe 'cookbook-openshift3::wire_aggregator_certificates' if node['cookbook-openshift3']['upgrade_ose_version'].split('.')[1].to_i == 7 && node['cookbook-openshift3']['upgrade']

  log 'Upgrade for CERTIFICATE SERVER [COMPLETED]' do
    level :info
  end
end
