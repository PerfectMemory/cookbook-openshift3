#
# Cookbook Name:: cookbook-openshift3
# Recipe:: ng_master_cluster_certificates
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

server_info = OpenShiftHelper::NodeHelper.new(node)
first_master = server_info.first_master
is_certificate_server = server_info.on_certificate_server?
FOLDER = Chef::Config['file_cache_path'] + '/master_ca'

directory FOLDER.to_s do
  recursive true
  not_if { File.exist? "#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/aggregator-front-proxy.crt" }
end

if is_certificate_server
  directory node['cookbook-openshift3']['master_certs_generated_certs_dir'] do
    mode '0755'
    owner 'apache'
    group 'apache'
    recursive true
  end

  if node['cookbook-openshift3']['openshift_master_ca_certificate']['data_bag_name'] && node['cookbook-openshift3']['openshift_master_ca_certificate']['data_bag_item_name']
    secret_file = node['cookbook-openshift3']['openshift_master_ca_certificate']['secret_file'] || nil
    ca_vars = data_bag_item(node['cookbook-openshift3']['openshift_master_ca_certificate']['data_bag_name'], node['cookbook-openshift3']['openshift_master_ca_certificate']['data_bag_item_name'], secret_file)

    file "#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/ca.key" do
      content Base64.decode64(ca_vars['key_base64'])
      mode '0600'
      action :create_if_missing
    end

    file "#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/ca.crt" do
      content Base64.decode64(ca_vars['cert_base64'])
      mode '0644'
      action :create_if_missing
    end

    file 'Initialise Master CA Serial' do
      path "#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/ca.serial.txt"
      content '00'
      not_if { ::File.exist?("#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/ca.serial.txt") }
    end
  end

  execute 'Create the front-proxy CA if it does not already exist' do
    command "#{node['cookbook-openshift3']['openshift_client_binary']} adm ca create-signer-cert \
            --cert=#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/front-proxy-ca.crt \
            --key=#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/front-proxy-ca.key \
            --serial=#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/ca.serial.txt \
            --expire-days=#{node['cookbook-openshift3']['openshift_ca_cert_expire_days']} \
            --overwrite=false"
    creates "#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/front-proxy-ca.crt"
  end

  execute 'Create the master certificates if they do not already exist' do
    command "#{node['cookbook-openshift3']['openshift_client_binary']} adm ca create-master-certs \
		        ${legacy_certs} \
            --hostnames=#{(node['cookbook-openshift3']['erb_corsAllowedOrigins'] + [first_master['ipaddress'], first_master['fqdn'], node['cookbook-openshift3']['openshift_common_api_hostname']]).uniq.join(',')} \
            --master=#{node['cookbook-openshift3']['openshift_master_api_url']} \
            --public-master=#{node['cookbook-openshift3']['openshift_master_public_api_url']} \
            --cert-dir=#{node['cookbook-openshift3']['master_certs_generated_certs_dir']} \
						--expire-days=#{node['cookbook-openshift3']['openshift_master_cert_expire_days']} \
            --signer-expire-days=#{node['cookbook-openshift3']['openshift_ca_cert_expire_days']} \
            --overwrite=false"
    environment(
      'legacy_certs' => node['cookbook-openshift3']['adhoc_redeploy_cluster_ca'] && ::File.file?(node['cookbook-openshift3']['redeploy_cluster_ca_certserver_control_flag']) ? "--certificate-authority=#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}-legacy-ca/ca.crt" : ''
    )
    creates node['cookbook-openshift3']['openshift_master_ca_certificate']['data_bag_name'] ? "#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/serviceaccounts.private.key" : "#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/ca.crt"
  end

  execute 'Generate the aggregator api-client config' do
    command "#{node['cookbook-openshift3']['openshift_client_binary']} adm create-api-client-config \
            --certificate-authority=#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/front-proxy-ca.crt \
            --signer-cert=#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/front-proxy-ca.crt \
            --signer-key=#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/front-proxy-ca.key \
            --user aggregator-front-proxy \
            --client-dir=#{FOLDER}  \
            --signer-serial=#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/ca.serial.txt \
						--expire-days=#{node['cookbook-openshift3']['openshift_master_cert_expire_days']}"
    creates "#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/aggregator-front-proxy.kubeconfig"
  end

  %w(aggregator-front-proxy.crt aggregator-front-proxy.key aggregator-front-proxy.kubeconfig).each do |aggregator|
    remote_file "#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/#{aggregator}" do
      source "file://#{FOLDER}/#{aggregator}"
      not_if { File.exist? "#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/#{aggregator}" }
      sensitive true
    end
  end

  directory FOLDER.to_s do
    recursive true
    action :delete
  end
end
