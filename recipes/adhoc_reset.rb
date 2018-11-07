#
# Cookbook Name:: cookbook-openshift3
# Recipe:: adhoc_reset
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

server_info = OpenShiftHelper::NodeHelper.new(node)
is_control_plane_server = server_info.on_control_plane_server?

openshift_reset_host node['fqdn'] do
  not_if { is_control_plane_server }
end

include_recipe 'cookbook-openshift3::docker'

file node['cookbook-openshift3']['adhoc_reset_control_flag'] do
  action :delete
end
