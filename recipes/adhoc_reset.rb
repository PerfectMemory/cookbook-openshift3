#
# Cookbook Name:: cookbook-openshift3
# Recipe:: adhoc_reset
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

openshift_reset_host node['fqdn']

file node['cookbook-openshift3']['adhoc_reset_control_flag'] do
  action :delete
end
