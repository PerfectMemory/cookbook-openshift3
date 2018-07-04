#
# Cookbook Name:: cookbook-openshift3
# Recipe:: adhoc_uninstall
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

openshift_delete_host node['fqdn']
