#
# Cookbook Name:: cookbook-openshift3
# Recipe:: master_cluster_certificates
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

server_info = OpenShiftHelper::NodeHelper.new(node)
first_master = server_info.first_master
is_certificate_server = server_info.on_certificate_server?

ose_major_version = node['cookbook-openshift3']['deploy_containerized'] == true ? node['cookbook-openshift3']['openshift_docker_image_version'] : node['cookbook-openshift3']['ose_major_version']

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
  end

  file 'Initialise Master CA Serial' do
    path "#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/ca.serial.txt"
    content '00'
    not_if { ::File.exist?("#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/ca.serial.txt") }
  end

  execute "Create the master certificates for #{first_master['fqdn']}" do
    command "#{node['cookbook-openshift3']['openshift_common_admin_binary']} ca create-master-certs \
		        ${legacy_certs} \
            --hostnames=#{(node['cookbook-openshift3']['erb_corsAllowedOrigins'] + [first_master['ipaddress'], first_master['fqdn'], node['cookbook-openshift3']['openshift_common_api_hostname']]).uniq.join(',')} \
            --master=#{node['cookbook-openshift3']['openshift_master_api_url']} \
            --public-master=#{node['cookbook-openshift3']['openshift_master_public_api_url']} \
            --cert-dir=#{node['cookbook-openshift3']['master_certs_generated_certs_dir']} ${validity_certs} --overwrite=false"
    environment(
      'validity_certs' => ose_major_version.split('.')[1].to_i < 5 ? '' : "--expire-days=#{node['cookbook-openshift3']['openshift_master_cert_expire_days']}",
      'legacy_certs' => node['cookbook-openshift3']['adhoc_redeploy_cluster_ca'] && ::File.file?(node['cookbook-openshift3']['redeploy_cluster_ca_certserver_control_flag']) ? "--certificate-authority=#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}-legacy-ca/ca.crt" : ''
    )
    creates node['cookbook-openshift3']['openshift_master_ca_certificate']['data_bag_name'] ? "#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/serviceaccounts.private.key" : "#{node['cookbook-openshift3']['master_certs_generated_certs_dir']}/ca.crt"
  end
end
