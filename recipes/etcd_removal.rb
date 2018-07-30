#
# Cookbook Name:: cookbook-openshift3
# Recipe:: etcd_removal
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

server_info = OpenShiftHelper::NodeHelper.new(node)
remove_etcd_servers = server_info.remove_etcd_servers
is_remove_etcd_server = server_info.on_remove_etcd_server?
is_certificate_server = server_info.on_certificate_server?
is_removing_etcd = server_info.removing_etcd?
etcds = etcd_servers.map { |srv| "#{srv['fqdn']}=https://#{srv['ipaddress']}:2379" }.join(',')

unless remove_etcd_servers.empty?
  if is_certificate_server

    if is_removing_etcd
      Chef::Log.error('[Remove ETCD - SKIP]. Cannot have etcd members in both roles!!!!. Make sure etcd members from etcd_servers are NOT part of remove_etcd_servers group.')
      return
    end

    directory node['cookbook-openshift3']['etcd_generated_remove_dir'] do
      mode '0755'
      owner 'apache'
      group 'apache'
      recursive true
    end

    remove_etcd_servers.each do |etcd|
      next if ::File.file?("#{node['cookbook-openshift3']['etcd_generated_remove_dir']}/.removed-#{etcd['fqdn']}")
      file "#{node['cookbook-openshift3']['etcd_generated_remove_dir']}/.removed-#{etcd['fqdn']}" do
        action :nothing
      end

      execute "Remove #{etcd['fqdn']} to the cluster" do
        command "/usr/bin/etcdctl --cert-file #{node['cookbook-openshift3']['etcd_generated_certs_dir']}/etcd-#{first_etcd['fqdn']}/peer.crt --key-file #{node['cookbook-openshift3']['etcd_generated_certs_dir']}/etcd-#{first_etcd['fqdn']}/peer.key --ca-file #{node['cookbook-openshift3']['etcd_generated_ca_dir']}/ca.crt -C #{etcds} member remove $(/usr/bin/etcdctl --cert-file #{node['cookbook-openshift3']['etcd_generated_certs_dir']}/etcd-#{first_etcd['fqdn']}/peer.crt --key-file #{node['cookbook-openshift3']['etcd_generated_certs_dir']}/etcd-#{first_etcd['fqdn']}/peer.key --ca-file #{node['cookbook-openshift3']['etcd_generated_ca_dir']}/ca.crt -C #{etcds} member list | awk '/name=#{etcd['fqdn']}/ {print substr($1,0,length($1)-1)}')"
        notifies :run, "execute[Check #{etcd['fqdn']} has successfully been removed]", :immediately
      end

      execute "Check #{etcd['fqdn']} has successfully been removed" do
        command "[[ $(/usr/bin/etcdctl --cert-file #{node['cookbook-openshift3']['etcd_generated_certs_dir']}/etcd-#{first_etcd['fqdn']}/peer.crt --key-file #{node['cookbook-openshift3']['etcd_generated_certs_dir']}/etcd-#{first_etcd['fqdn']}/peer.key --ca-file #{node['cookbook-openshift3']['etcd_generated_ca_dir']}/ca.crt -C #{etcds} member list | grep -c #{etcd['fqdn']}) -eq 0 ]]"
        retries 5
        retry_delay 5
        notifies :run, "execute[Check #{etcd['fqdn']} left the cluster in Healthy condition before proceeding]", :immediately
        action :nothing
      end

      execute "Check #{etcd['fqdn']} left the cluster in Healthy condition before proceeding" do
        command "/usr/bin/etcdctl --cert-file #{node['cookbook-openshift3']['etcd_generated_certs_dir']}/etcd-#{first_etcd['fqdn']}/peer.crt --key-file #{node['cookbook-openshift3']['etcd_generated_certs_dir']}/etcd-#{first_etcd['fqdn']}/peer.key --ca-file #{node['cookbook-openshift3']['etcd_generated_ca_dir']}/ca.crt -C #{etcds} cluster-health | grep -w 'cluster is healthy'"
        retries 5
        retry_delay 5
        action :nothing
        notifies :create, "file[#{node['cookbook-openshift3']['etcd_generated_remove_dir']}/.removed-#{etcd['fqdn']}]", :immediately
      end
    end
  end

  if is_remove_etcd_server

    unless ::File.file?("#{node['cookbook-openshift3']['etcd_data_dir']}/.removed")
      execute 'Check member has been removed from cluster' do
        command "[[ $(/usr/bin/etcdctl --cert-file #{node['cookbook-openshift3']['etcd_peer_file']} --key-file #{node['cookbook-openshift3']['etcd_peer_key']} --ca-file #{node['cookbook-openshift3']['etcd_ca_cert']} -C #{etcds} member list | grep -c #{node['fqdn']}) -eq 0 ]]"
        retries 60
        retry_delay 5
        notifies :stop, 'service[etcd-service]', :immediately
        notifies :disable, 'service[etcd-service]', :immediately
      end

      file "#{node['cookbook-openshift3']['etcd_data_dir']}/.removed" do
        action :create_if_missing
      end
    end
  end
end
