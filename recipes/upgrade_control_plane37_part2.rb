#
# Cookbook Name:: cookbook-openshift3
# Recipe:: upgrade_control_plane37_part2
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

# This must be run before any upgrade takes place.
# It creates the service signer certs (and any others) if they were not in
# existence previously.

server_info = OpenShiftHelper::NodeHelper.new(node)
first_etcd = server_info.first_etcd
is_master_server = server_info.on_master_server?
is_node_server = server_info.on_node_server?
is_first_master = server_info.on_first_master?
master_servers = server_info.master_servers

if is_first_master
  log 'Pre master upgrade - Upgrade all storage' do
    level :info
  end

  execute 'Confirm OpenShift authorization objects are in sync' do
    command "#{node['cookbook-openshift3']['openshift_common_admin_binary']} \
            --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig \
            migrate authorization"
    not_if "#{node['cookbook-openshift3']['openshift_common_client_binary']} version | grep -w v3.7"
  end

  execute 'Migrate storage post policy reconciliation Pre upgrade' do
    command "#{node['cookbook-openshift3']['openshift_common_admin_binary']} \
            --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig \
            migrate storage --include=* --confirm"
    not_if "#{node['cookbook-openshift3']['openshift_common_client_binary']} version | grep -w v3.7"
  end

  execute 'Create key for upgrade all storage' do
    command "ETCDCTL_API=3 /usr/bin/etcdctl --cert #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-client.crt --key #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-client.key --cacert #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-ca.crt --endpoints https://#{first_etcd['ipaddress']}:2379 put /migration/storage ok"
    not_if "#{node['cookbook-openshift3']['openshift_common_client_binary']} version | grep -w v3.7"
  end
end

if is_master_server && !is_first_master
  execute 'Wait for First master to upgrade all storage' do
    command "ETCDCTL_API=3 /usr/bin/etcdctl --cert #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-client.crt --key #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-client.key --cacert #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-ca.crt --endpoints https://#{first_etcd['ipaddress']}:2379 get /migration/storage -w simple | grep -w ok"
    retries 120
    retry_delay 5
    not_if "#{node['cookbook-openshift3']['openshift_common_client_binary']} version | grep -w v3.7"
  end
end

if is_master_server
  log 'Upgrade for MASTERS [STARTED]' do
    level :info
  end

  log 'Stop all master services prior to upgrade for 3.6 to 3.7 transition' do
    level :info
    notifies :stop, "service[#{node['cookbook-openshift3']['openshift_service_type']}-master-api]", :immediately
    notifies :stop, "service[#{node['cookbook-openshift3']['openshift_service_type']}-master-controllers]", :immediately
    not_if { master_servers.size == 1 }
    not_if "#{node['cookbook-openshift3']['openshift_common_client_binary']} version | grep -w v3.7"
  end

  include_recipe 'cookbook-openshift3::master'
  include_recipe 'cookbook-openshift3::excluder' unless is_node_server

  log 'Restart Master services' do
    level :info
    notifies :restart, "service[#{node['cookbook-openshift3']['openshift_service_type']}-master]", :immediately unless node['cookbook-openshift3']['openshift_HA']
    notifies :restart, "service[#{node['cookbook-openshift3']['openshift_service_type']}-master-api]", :immediately if node['cookbook-openshift3']['openshift_HA']
    notifies :restart, "service[#{node['cookbook-openshift3']['openshift_service_type']}-master-controllers]", :immediately if node['cookbook-openshift3']['openshift_HA']
  end

  execute "Set upgrade markup for master : #{node['fqdn']}" do
    command "ETCDCTL_API=3 /usr/bin/etcdctl --cert #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-client.crt --key #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-client.key --cacert #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-ca.crt --endpoints https://#{first_etcd['ipaddress']}:2379 put /migration/#{node['cookbook-openshift3']['control_upgrade_version']}/#{node['fqdn']} ok"
  end

  log 'Upgrade for MASTERS [COMPLETED]' do
    level :info
  end
end

if is_master_server && !is_first_master
  execute 'Wait for First master to reconcile all roles' do
    command "[[ $(ETCDCTL_API=3 /usr/bin/etcdctl --cert #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-client.crt --key #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-client.key --cacert #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-ca.crt --endpoints https://#{first_etcd['ipaddress']}:2379 get /migration/storage -w simple | wc -l) -eq 0 ]]"
    retries 120
    retry_delay 5
  end
end

if is_master_server && is_first_master

  log 'Reconcile Cluster Roles & Cluster Role Bindings [STARTED]' do
    level :info
  end

  execute 'Delete key for upgrade all storage' do
    command "ETCDCTL_API=3 /usr/bin/etcdctl --cert #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-client.crt --key #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-client.key --cacert #{node['cookbook-openshift3']['openshift_master_config_dir']}/master.etcd-ca.crt --endpoints https://#{first_etcd['ipaddress']}:2379 del /migration/storage"
  end

  log 'Reconcile Cluster Roles & Cluster Role Bindings [COMPLETED]' do
    level :info
  end
end

if is_master_server
  log 'Cycle all controller services to force new leader election mode' do
    level :info
    notifies :restart, "service[#{node['cookbook-openshift3']['openshift_service_type']}-master-controllers]", :immediately
  end
end

include_recipe 'cookbook-openshift3::upgrade_managed_hosted' if is_first_master
include_recipe 'cookbook-openshift3::upgrade_node37' if is_node_server
