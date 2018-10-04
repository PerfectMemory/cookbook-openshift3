#
# Cookbook Name:: cookbook-openshift3
# Recipe:: upgrade_control_plane39
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

# This must be run before any upgrade takes place.
# It creates the service signer certs (and any others) if they were not in
# existence previously.

Chef::Log.error("Upgrade will be skipped. Could not find the flag: #{node['cookbook-openshift3']['control_upgrade_flag']}") unless ::File.file?(node['cookbook-openshift3']['control_upgrade_flag'])

if ::File.file?(node['cookbook-openshift3']['control_upgrade_flag'])

  node.force_override['cookbook-openshift3']['upgrade'] = true
  node.force_override['cookbook-openshift3']['openshift_docker_image_version'] = node['cookbook-openshift3']['upgrade_openshift_docker_image_version']
  node.force_override['cookbook-openshift3']['ose_major_version'] = node['cookbook-openshift3']['upgrade_ose_major_version']
  node.force_override['cookbook-openshift3']['ose_version'] = node['cookbook-openshift3']['upgrade_ose_version']

  node.force_override['yum']['main']['exclude'] = node['cookbook-openshift3']['custom_pkgs_excluder'] unless node['cookbook-openshift3']['custom_pkgs_excluder'].nil?

  server_info = OpenShiftHelper::NodeHelper.new(node)
  first_etcd = server_info.first_etcd
  is_etcd_server = server_info.on_etcd_server?
  is_master_server = server_info.on_master_server?
  is_node_server = server_info.on_node_server?

  if defined? node['cookbook-openshift3']['upgrade_repos']
    node.force_override['cookbook-openshift3']['yum_repositories'] = node['cookbook-openshift3']['upgrade_repos']
  end

  if is_master_server
    return unless ::Mixlib::ShellOut.new("/usr/bin/etcdctl --cert-file #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-client.crt --key-file #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-client.key --ca-file #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-ca.crt -C https://#{first_etcd['ipaddress']}:2379 ls /migration/#{node['cookbook-openshift3']['control_upgrade_version']}/#{node['fqdn']}").run_command.error?
  end

  include_recipe 'yum::default'
  include_recipe 'cookbook-openshift3::packages'
  include_recipe 'cookbook-openshift3::disable_excluder'

  if is_master_server || is_node_server
    %w[excluder docker-excluder].each do |pkg|
      execute "Disable #{node['cookbook-openshift3']['openshift_service_type']}-#{pkg} for Control Plane" do
        command "#{node['cookbook-openshift3']['openshift_service_type']}-#{pkg} enable"
      end
    end
  end

  if is_etcd_server
    log 'Upgrade for ETCD [STARTED]' do
      level :info
    end

    execute 'Generate etcd backup before upgrade' do
      command "etcdctl backup --data-dir=#{node['cookbook-openshift3']['etcd_data_dir']} --backup-dir=#{node['cookbook-openshift3']['etcd_data_dir']}-pre-upgrade39"
      not_if { ::File.directory?("#{node['cookbook-openshift3']['etcd_data_dir']}-pre-upgrade39") }
      notifies :run, 'execute[Copy etcd v3 data store (PRE)]', :immediately
    end

    execute 'Copy etcd v3 data store (PRE)' do
      command "cp -a #{node['cookbook-openshift3']['etcd_data_dir']}/member/snap/db #{node['cookbook-openshift3']['etcd_data_dir']}-pre-upgrade39/member/snap/"
      only_if { ::File.file?("#{node['cookbook-openshift3']['etcd_data_dir']}/member/snap/db") }
      action :nothing
    end

    include_recipe 'cookbook-openshift3'
    include_recipe 'cookbook-openshift3::etcd_cluster'

    execute 'Generate etcd backup after upgrade' do
      command "etcdctl backup --data-dir=#{node['cookbook-openshift3']['etcd_data_dir']} --backup-dir=#{node['cookbook-openshift3']['etcd_data_dir']}-post-upgrade39"
      not_if { ::File.directory?("#{node['cookbook-openshift3']['etcd_data_dir']}-post-upgrade39") }
      notifies :run, 'execute[Copy etcd v3 data store (POST)]', :immediately
    end

    execute 'Copy etcd v3 data store (POST)' do
      command "cp -a #{node['cookbook-openshift3']['etcd_data_dir']}/member/snap/db #{node['cookbook-openshift3']['etcd_data_dir']}-post-upgrade39/member/snap/"
      only_if { ::File.file?("#{node['cookbook-openshift3']['etcd_data_dir']}/member/snap/db") }
      action :nothing
    end

    file node['cookbook-openshift3']['control_upgrade_flag'] do
      action :delete
      only_if { is_etcd_server && !is_master_server }
    end

    log 'Upgrade for ETCD [COMPLETED]' do
      level :info
    end
  end

  include_recipe 'cookbook-openshift3::upgrade_control_plane38_part1'
  include_recipe 'cookbook-openshift3::upgrade_control_plane39_part1'
end
