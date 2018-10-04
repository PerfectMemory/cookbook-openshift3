#
# Cookbook Name:: cookbook-openshift3
# Resources:: openshift_deploy_logging
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

provides :openshift_deploy_logging
resource_name :openshift_deploy_logging

actions %i[create delete]

default_action :create
