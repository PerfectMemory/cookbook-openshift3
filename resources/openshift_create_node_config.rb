property :node_file, String

provides :openshift_create_node_config

action :create do
  converge_by 'Create Node configuration file' do
    helper = OpenShiftHelper::NodeHelper.new(node)
    group_label = helper.openshift_node_groups
    template "#{Chef::Config[:file_cache_path]}/node-config.yaml" do
      source 'openshift_node/node-config.yaml.erb'
      variables(
        node_labels: node['cookbook-openshift3']['openshift_node_groups'].find { |group| group['name'] == group_label }['labels']
      )
    end

    ruby_block 'Prepare Node Configuration YAML' do
      block do
        pre_node = YAML.load_file("#{Chef::Config[:file_cache_path]}/node-config.yaml")
        openshift_node_kubelet_args = node['cookbook-openshift3']['openshift_node_groups'].find { |group| group['name'] == group_label }.key?('kubeletArguments') ? node['cookbook-openshift3']['openshift_node_groups'].find { |group| group['name'] == group_label }['kubeletArguments'] : {}
        pre_node['kubeletArguments'] = pre_node['kubeletArguments'].merge(openshift_node_kubelet_args.to_hash)

        file new_resource.node_file do
          content pre_node.to_yaml
          owner 'root'
          group 'root'
          mode '0600'
        end
      end
    end
  end
end

action :create_node_groups do
  converge_by 'Build node config maps' do
    node['cookbook-openshift3']['openshift_node_groups'].each do |group|
      template "#{Chef::Config[:file_cache_path]}/node-config-#{group['name']}.yaml" do
        source 'openshift_node/node-config.yaml.erb'
        variables(
          node_labels: group['labels']
        )
      end

      ruby_block "Prepare ConfigMap for #{group['name']}" do
        block do
          pre_node = YAML.load_file("#{Chef::Config[:file_cache_path]}/node-config-#{group['name']}.yaml")
          openshift_node_kubelet_args = group.key?('kubeletArguments') ? group['kubeletArguments'] : {}
          pre_node['kubeletArguments'] = pre_node['kubeletArguments'].merge(openshift_node_kubelet_args.to_hash)

          file "#{Chef::Config[:file_cache_path]}/configmap-#{group['name']}.yaml" do
            content pre_node.to_yaml
            owner 'root'
            group 'root'
            mode '0600'
          end
        end
      end

      execute "Create/Amend ConfigMap for #{group['name']}" do
        command "#{node['cookbook-openshift3']['openshift_client_binary']} create configmap #{group['name']} --from-file=node-config.yaml=#{Chef::Config[:file_cache_path]}/configmap-#{group['name']}.yaml -n ${namespace_nodes} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --dry-run -o yaml | #{node['cookbook-openshift3']['openshift_client_binary']} apply -f - -n ${namespace_nodes} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
        environment(
          'namespace_nodes' => 'openshift-node'
        )
      end
    end
  end
end

action :create_sync do
  converge_by 'Setup automatic node config reconcilation' do
    remote_directory "#{Chef::Config[:file_cache_path]}/sync" do
      source 'openshift_control_plane/sync'
    end

    ruby_block 'Update the image tag for sync' do
      block do
        pre_sync = YAML.load_file("#{Chef::Config[:file_cache_path]}/sync/images.yaml")
        pre_sync['tag']['from']['name'] = "#{node['cookbook-openshift3']['openshift_docker_node_image']}:#{node['cookbook-openshift3']['openshift_docker_image_version']}"

        file "#{Chef::Config[:file_cache_path]}/sync/sync-images.yaml" do
          content pre_sync.to_yaml
        end
      end
    end

    execute 'Ensure the sync service account can run privileged' do
      command "#{node['cookbook-openshift3']['openshift_client_binary']} adm policy add-scc-to-user privileged system:serviceaccount:openshift-node:sync --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
      not_if "#{node['cookbook-openshift3']['openshift_client_binary']} get scc privileged --template {{.users}} | grep system:serviceaccount:openshift-node:sync --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
    end

    execute 'Temporary fix until we fix "oc apply" for image stream tags (sync)' do
      command "#{node['cookbook-openshift3']['openshift_client_binary']} delete -n openshift-node istag node:v3.10 --ignore-not-found --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
    end

    ruby_block 'Apply the config for sync node config reconcilation' do
      block do
        run_context = Chef::RunContext.new(Chef::Node.new, {}, Chef::EventDispatch::Dispatcher.new)
        Dir.glob("#{Chef::Config[:file_cache_path]}/sync/sync*").grep(/\.(?:yaml)$/).uniq.each do |file|
          action = Chef::Resource::Execute.new(file, run_context)
          action.command "#{node['cookbook-openshift3']['openshift_client_binary']} apply -f #{file} -n openshift-node --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
          action.run_action(:run)
        end
      end
    end
  end
end

action :create_sdn do
  converge_by 'Setup SDN for nodes' do
    remote_directory "#{Chef::Config[:file_cache_path]}/sdn" do
      source 'openshift_control_plane/sdn'
    end

    ruby_block 'Update the image tag for sdn' do
      block do
        pre_sdn = YAML.load_file("#{Chef::Config[:file_cache_path]}/sdn/images.yaml")
        pre_sdn['tag']['from']['name'] = "#{node['cookbook-openshift3']['openshift_docker_node_image']}:#{node['cookbook-openshift3']['openshift_docker_image_version']}"

        file "#{Chef::Config[:file_cache_path]}/sdn/sdn-images.yaml" do
          content pre_sdn.to_yaml
        end
      end
    end

    execute 'Ensure project openshift-sdn exists' do
      command "#{node['cookbook-openshift3']['openshift_client_binary']} adm new-project openshift-sdn --node-selector=\"\" --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
      not_if "#{node['cookbook-openshift3']['openshift_client_binary']} get project openshift-sdn --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
    end

    execute 'Ensure the sdn service account can run privileged' do
      command "#{node['cookbook-openshift3']['openshift_client_binary']} adm policy add-scc-to-user privileged system:serviceaccount:openshift-sdn:sdn --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
      not_if "#{node['cookbook-openshift3']['openshift_client_binary']} get scc privileged --template {{.users}} | grep system:serviceaccount:openshift-sdn:sdn --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
    end

    execute 'Temporary fix until we fix "oc apply" for image stream tags (sdn)' do
      command "#{node['cookbook-openshift3']['openshift_client_binary']} delete -n openshift-sdn istag node:v3.10 --ignore-not-found --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
    end

    ruby_block 'Apply the config for sdn node config' do
      block do
        run_context = Chef::RunContext.new(Chef::Node.new, {}, Chef::EventDispatch::Dispatcher.new)
        Dir.glob("#{Chef::Config[:file_cache_path]}/sdn/sdn*").grep(/\.(?:yaml)$/).uniq.each do |file|
          action = Chef::Resource::Execute.new(file, run_context)
          action.command "#{node['cookbook-openshift3']['openshift_client_binary']} apply -f #{file} -n openshift-sdn --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
          action.run_action(:run)
        end
      end
    end
  end
end

action :create_bootstrap_controller do
  converge_by 'Setup the node bootstrap auto approver' do
    remote_directory "#{Chef::Config[:file_cache_path]}/autoapprover" do
      source 'openshift_control_plane/autoapprover'
    end

    ruby_block 'Update the image tag for autoapprover' do
      block do
        pre_autoapprover = YAML.load_file("#{Chef::Config[:file_cache_path]}/autoapprover/images.yaml")
        pre_autoapprover['tag']['from']['name'] = "#{node['cookbook-openshift3']['openshift_docker_node_image']}:#{node['cookbook-openshift3']['openshift_docker_image_version']}"

        file "#{Chef::Config[:file_cache_path]}/autoapprover/openshift-bootstrap-images.yaml" do
          content pre_autoapprover.to_yaml
        end
      end
    end

    execute 'Temporary fix until we fix "oc apply" for image stream tags (autoapprover)' do
      command "#{node['cookbook-openshift3']['openshift_client_binary']} delete -n openshift-infra istag node:v3.10 --ignore-not-found --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
    end

    ruby_block 'Apply the config for autoapprover node config' do
      block do
        run_context = Chef::RunContext.new(Chef::Node.new, {}, Chef::EventDispatch::Dispatcher.new)
        Dir.glob("#{Chef::Config[:file_cache_path]}/autoapprover/openshift-bootstrap*").grep(/\.(?:yaml)$/).uniq.each do |file|
          action = Chef::Resource::Execute.new(file, run_context)
          action.command "#{node['cookbook-openshift3']['openshift_client_binary']} apply -f #{file} -n openshift-infra --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig"
          action.run_action(:run)
        end
      end
    end
  end
end
