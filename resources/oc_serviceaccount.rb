#
# Cookbook Name:: cookbook-openshift3
# Resources:: oc_sa
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

provides :oc_serviceaccount
property :name, String, required: true
property :namespace, String, required: true

action :create do
  execute "Create ServiceAccount [#{new_resource.name}]" do
    command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create serviceaccount #{new_resource.name} -n #{new_resource.namespace} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
    not_if "#{node['cookbook-openshift3']['openshift_common_client_binary']} get serviceaccount/#{new_resource.name} --no-headers --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig -n #{new_resource.namespace}"
  end
end
