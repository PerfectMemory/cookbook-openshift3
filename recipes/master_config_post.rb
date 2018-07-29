#
# Cookbook Name:: cookbook-openshift3
# Recipe:: master_config_post
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

server_info = OpenShiftHelper::NodeHelper.new(node)
master_servers = server_info.master_servers
node_servers = server_info.node_servers
ose_major_version = node['cookbook-openshift3']['deploy_containerized'] == true ? node['cookbook-openshift3']['openshift_docker_image_version'] : node['cookbook-openshift3']['ose_major_version']

service_accounts = node['cookbook-openshift3']['openshift_common_service_accounts_additional'].any? ? node['cookbook-openshift3']['openshift_common_service_accounts'] + node['cookbook-openshift3']['openshift_common_service_accounts_additional'] : node['cookbook-openshift3']['openshift_common_service_accounts']

execute 'Check Master API' do
  command "[[ $(curl --silent #{node['cookbook-openshift3']['openshift_master_api_url']}/healthz/ready --cacert #{node['cookbook-openshift3']['openshift_master_config_dir']}/ca.crt --cacert #{node['cookbook-openshift3']['openshift_master_config_dir']}/ca-bundle.crt) =~ \"ok\" ]]"
  retries 120
  retry_delay 1
end

service_accounts.each do |serviceaccount|
  execute "Creation of namespace \"#{serviceaccount['namespace']}\"" do
    command "#{node['cookbook-openshift3']['openshift_common_client_binary']} adm new-project ${namespace} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
    environment(
      'namespace' => serviceaccount['namespace']
    )
    cwd node['cookbook-openshift3']['openshift_master_config_dir']
    not_if "#{node['cookbook-openshift3']['openshift_common_client_binary']} get project #{serviceaccount['namespace']} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
  end

  execute "Creation service account: \"#{serviceaccount['name']}\" ; Namespace: \"#{serviceaccount['namespace']}\"" do
    command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create sa ${serviceaccount} -n ${namespace} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
    environment(
      'serviceaccount' => serviceaccount['name'],
      'namespace' => serviceaccount['namespace']
    )
    cwd node['cookbook-openshift3']['openshift_master_config_dir']
    not_if "#{node['cookbook-openshift3']['openshift_common_client_binary']} get sa #{serviceaccount['name']} -n #{serviceaccount['namespace']} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
  end

  if node['cookbook-openshift3']['openshift_hosted_router_deploy_shards']
    node['cookbook-openshift3']['openshift_hosted_router_shard'].each do |shard|
      execute "Add cluster-reader for router sharing service account: \"#{shard['service_account']}\"" do
        command "#{node['cookbook-openshift3']['openshift_common_client_binary']} adm policy add-cluster-role-to-user cluster-reader ${serviceaccount} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
        environment(
          'serviceaccount' => "system:serviceaccount:#{shard['namespace']}:#{shard['service_account']}"
        )
        cwd node['cookbook-openshift3']['openshift_master_config_dir']
        not_if "#{node['cookbook-openshift3']['openshift_common_client_binary']} get clusterrolebinding/cluster-readers -o yaml --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig | grep ${serviceaccount}"
      end
    end
  end

  next unless serviceaccount.key?('scc')

  sccs = serviceaccount['scc'].is_a?(Array) ? serviceaccount['scc'] : serviceaccount['scc'].split(' ') # Backport old logic

  sccs.each do |scc|
    execute "Add SCC [#{scc}] to service account: \"#{serviceaccount['name']}\" ; Namespace: \"#{serviceaccount['namespace']}\"" do
      command "#{node['cookbook-openshift3']['openshift_common_admin_binary']} policy add-scc-to-user #{scc} -z #{serviceaccount['name']} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig -n #{serviceaccount['namespace']}"
      cwd node['cookbook-openshift3']['openshift_master_config_dir']
      not_if "#{node['cookbook-openshift3']['openshift_common_client_binary']} get scc/#{scc} -n #{serviceaccount['namespace']} -o yaml --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig | grep system:serviceaccount:#{serviceaccount['namespace']}:#{serviceaccount['name']}"
    end
  end
end

execute 'Import Openshift Hosted Examples' do
  command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create -f #{node['cookbook-openshift3']['openshift_common_hosted_base']} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig -n openshift || #{node['cookbook-openshift3']['openshift_common_client_binary']} replace -f #{node['cookbook-openshift3']['openshift_common_hosted_base']} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig -n openshift"
  cwd node['cookbook-openshift3']['openshift_master_config_dir']
  ignore_failure true
end

execute 'Import Openshift db templates' do
  command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/db-templates --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig -n openshift || #{node['cookbook-openshift3']['openshift_common_client_binary']} replace -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/db-templates --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig -n openshift"
  cwd node['cookbook-openshift3']['openshift_master_config_dir']
  only_if { node['cookbook-openshift3']['deploy_example'] && node['cookbook-openshift3']['deploy_example_db_templates'] }
  ignore_failure true
end

execute 'Import Openshift Examples Base image-streams' do
  command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/image-streams/#{node['cookbook-openshift3']['openshift_base_images']} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig -n openshift || #{node['cookbook-openshift3']['openshift_common_client_binary']} replace -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/image-streams/#{node['cookbook-openshift3']['openshift_base_images']} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig -n openshift"
  cwd node['cookbook-openshift3']['openshift_master_config_dir']
  only_if { node['cookbook-openshift3']['deploy_example'] && node['cookbook-openshift3']['deploy_example_image-streams'] }
  ignore_failure true
end

execute 'Import Openshift Examples quickstart-templates' do
  command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/quickstart-templates --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig -n openshift"
  cwd node['cookbook-openshift3']['openshift_master_config_dir']
  only_if { node['cookbook-openshift3']['deploy_example'] && node['cookbook-openshift3']['deploy_example_quickstart-templates'] }
  ignore_failure true
end

execute 'Import Openshift Examples xpaas-streams' do
  command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/xpaas-streams --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig -n openshift"
  cwd node['cookbook-openshift3']['openshift_master_config_dir']
  only_if { node['cookbook-openshift3']['deploy_example'] && node['cookbook-openshift3']['deploy_example_xpaas-streams'] }
  ignore_failure true
end

execute 'Import Openshift Examples xpaas-templates' do
  command "#{node['cookbook-openshift3']['openshift_common_client_binary']} create -f #{node['cookbook-openshift3']['openshift_common_examples_base']}/xpaas-templates --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig -n openshift"
  cwd node['cookbook-openshift3']['openshift_master_config_dir']
  only_if { node['cookbook-openshift3']['deploy_example'] && node['cookbook-openshift3']['deploy_example_xpaas-templates'] }
  ignore_failure true
end

openshift_create_pv 'Create Persistent Storage' do
  persistent_storage node['cookbook-openshift3']['persistent_storage']
  not_if { node['cookbook-openshift3']['persistent_storage'].empty? }
end

node_servers.reject { |h| h.key?('skip_run') }.each do |nodes|
  execute "Set schedulability for Master node : #{nodes['fqdn']}" do
    command "#{node['cookbook-openshift3']['openshift_common_admin_binary']} manage-node #{nodes['fqdn']} --schedulable=${schedulability} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
    environment(
      'schedulability' => !nodes.key?(:schedulable) && master_servers.find { |server_node| server_node['fqdn'] == nodes['fqdn'] } ? 'False' : nodes['schedulable'].to_s
    )
    cwd node['cookbook-openshift3']['openshift_master_config_dir']
    only_if do
      master_servers.find { |server_node| server_node['fqdn'] == nodes['fqdn'] } &&
        !Mixlib::ShellOut.new("#{node['cookbook-openshift3']['openshift_common_client_binary']} get node | grep #{nodes['fqdn']}").run_command.error?
    end
  end

  execute "Set schedulability for node : #{nodes['fqdn']}" do
    command "#{node['cookbook-openshift3']['openshift_common_admin_binary']} manage-node #{nodes['fqdn']} --schedulable=${schedulability} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
    environment(
      'schedulability' => !nodes.key?(:schedulable) && node_servers.find { |server_node| server_node['fqdn'] == nodes['fqdn'] } ? 'True' : nodes['schedulable'].to_s
    )
    cwd node['cookbook-openshift3']['openshift_master_config_dir']
    not_if do
      master_servers.find { |server_node| server_node['fqdn'] == nodes['fqdn'] } ||
        Mixlib::ShellOut.new("#{node['cookbook-openshift3']['openshift_common_client_binary']} get node | grep #{nodes['fqdn']}").run_command.error?
    end
  end

  execute "Set Labels for node : #{nodes['fqdn']}" do
    command "#{node['cookbook-openshift3']['openshift_common_client_binary']} label node #{nodes['fqdn']} ${labels} --overwrite --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
    environment(
      'labels' => nodes['labels'].to_s
    )
    cwd node['cookbook-openshift3']['openshift_master_config_dir']
    only_if do
      nodes.key?('labels') &&
        !Mixlib::ShellOut.new("#{node['cookbook-openshift3']['openshift_common_client_binary']} get node | grep #{nodes['fqdn']}").run_command.error?
    end
  end
end

include_recipe 'cookbook-openshift3::web_console' if ose_major_version.split('.')[1].to_i >= 9

openshift_deploy_router 'Deploy Router' do
  deployer_options node['cookbook-openshift3']['openshift_hosted_router_options']
  only_if do
    node['cookbook-openshift3']['openshift_hosted_manage_router']
  end
end

openshift_deploy_registry 'Deploy Registry' do
  persistent_registry node['cookbook-openshift3']['registry_persistent_volume'].empty? ? false : true
  persistent_volume_claim_name "#{node['cookbook-openshift3']['registry_persistent_volume']}-claim"
  only_if do
    node['cookbook-openshift3']['openshift_hosted_manage_registry']
  end
end

openshift_deploy_metrics 'Remove Cluster Metrics' do
  action :delete
  only_if do
    node['cookbook-openshift3']['openshift_hosted_cluster_metrics'] &&
      !node['cookbook-openshift3']['openshift_metrics_install_metrics']
  end
end

openshift_deploy_metrics 'Deploy Cluster Metrics' do
  only_if do
    node['cookbook-openshift3']['openshift_hosted_cluster_metrics'] &&
      node['cookbook-openshift3']['openshift_metrics_install_metrics']
  end
end

openshift_deploy_logging 'Remove Cluster Logging' do
  action :delete
  only_if do
    node['cookbook-openshift3']['openshift_hosted_cluster_logging'] &&
      !node['cookbook-openshift3']['openshift_logging_install_logging']
  end
end

openshift_deploy_logging 'Deploy Cluster Logging' do
  only_if do
    node['cookbook-openshift3']['openshift_hosted_cluster_logging'] &&
      node['cookbook-openshift3']['openshift_logging_install_logging']
  end
end
