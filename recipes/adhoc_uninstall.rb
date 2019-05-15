#
# Cookbook Name:: cookbook-openshift3
# Recipe:: adhoc_uninstall
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

include_recipe 'iptables::default'
include_recipe 'cookbook-openshift3::services'
openshift_delete_host node['fqdn']
