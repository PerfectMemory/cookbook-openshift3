#
# Cookbook Name:: cookbook-openshift3
# Recipe:: ng_nodes_certificates
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

server_info = OpenShiftHelper::NodeHelper.new(node)
node_servers = server_info.node_servers
is_master_server = server_info.on_master_server?

%W[/var/www/html/node #{node['cookbook-openshift3']['openshift_node_generated_configs_dir']}].each do |path|
  directory path do
    owner 'apache'
    group 'apache'
    mode '0755'
  end
end

if node['cookbook-openshift3']['encrypted_file_password']['data_bag_name'] && node['cookbook-openshift3']['encrypted_file_password']['data_bag_item_name']
  secret_file = node['cookbook-openshift3']['encrypted_file_password']['secret_file'] || nil
  encrypted_file_password = data_bag_item(node['cookbook-openshift3']['encrypted_file_password']['data_bag_name'], node['cookbook-openshift3']['encrypted_file_password']['data_bag_item_name'], secret_file)
else
  encrypted_file_password = node['cookbook-openshift3']['encrypted_file_password']['default']
end

execute 'Wait for API to become available' do
  command is_master_server ? "[[ $(curl --silent --tlsv1.2 --max-time 2 #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}/healthz/ready --cacert #{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/ca.crt --cacert #{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/ca-bundle.crt) =~ \"ok\" ]]" : "[[ $(curl --silent --tlsv1.2 --max-time 2 -k #{node['cookbook-openshift3']['openshift_master_api_url']}/healthz/ready) =~ \"ok\" ]]"
  environment 'no_proxy' => 'localhost'
  retries 150
  retry_delay 5
end

execute 'Create service account kubeconfig with csr rights' do
  command "#{node['cookbook-openshift3']['openshift_client_binary']} serviceaccounts create-kubeconfig ${openshift_master_csr_sa} -n ${openshift_master_csr_namespace} --config=#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/admin.kubeconfig > #{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/bootstrap.kubeconfig"
  environment(
    'openshift_master_csr_sa' => node['cookbook-openshift3']['openshift_master_csr_sa'],
    'openshift_master_csr_namespace' => node['cookbook-openshift3']['openshift_master_csr_namespace']
  )
  not_if { ::File.exist?("#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/bootstrap.kubeconfig") }
end

node_servers.each do |node_server|
  execute "Generate certificate directory for #{node_server['fqdn']}" do
    command "mkdir -p #{Chef::Config[:file_cache_path]}/#{node_server['fqdn']}"
    creates "#{node['cookbook-openshift3']['openshift_node_generated_configs_dir']}/#{node_server['fqdn']}.tar.gz"
  end

  remote_file "#{Chef::Config[:file_cache_path]}/#{node_server['fqdn']}/bootstrap.kubeconfig" do
    source "file://#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/bootstrap.kubeconfig"
    sensitive true
    not_if { ::File.exist?("#{node['cookbook-openshift3']['openshift_node_generated_configs_dir']}/#{node_server['fqdn']}.tar.gz") }
  end

  execute "Generate a tarball for #{node_server['fqdn']}" do
    command "tar --mode='0644' --owner=root --group=root -czvf #{node['cookbook-openshift3']['openshift_node_generated_configs_dir']}/#{node_server['fqdn']}.tar.gz -C #{Chef::Config[:file_cache_path]}/#{node_server['fqdn']} . --remove-files && chown apache:apache #{node['cookbook-openshift3']['openshift_node_generated_configs_dir']}/#{node_server['fqdn']}.tar.gz"
    creates "#{node['cookbook-openshift3']['openshift_node_generated_configs_dir']}/#{node_server['fqdn']}.tar.gz"
  end

  execute "Encrypt node servers tgz files for #{node_server['fqdn']}" do
    command "openssl enc -aes-256-cbc -in #{node['cookbook-openshift3']['openshift_node_generated_configs_dir']}/#{node_server['fqdn']}.tar.gz -out #{node['cookbook-openshift3']['openshift_node_generated_configs_dir']}/#{node_server['fqdn']}.tgz.enc -k '#{encrypted_file_password}' && chown apache:apache #{node['cookbook-openshift3']['openshift_node_generated_configs_dir']}/#{node_server['fqdn']}.tgz.enc"
    creates "#{node['cookbook-openshift3']['openshift_node_generated_configs_dir']}/#{node_server['fqdn']}.tgz.enc"
  end
end
