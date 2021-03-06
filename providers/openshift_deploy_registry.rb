#
# Cookbook Name:: cookbook-openshift3
# Resources:: openshift_deploy_registry
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

provides :openshift_deploy_registry if defined? provides

def whyrun_supported?
  true
end

action :create do
  converge_by 'Deploy Registry' do
    oc_client = node['cookbook-openshift3']['ose_major_version'].split('.')[1].to_i >= 10 ? node['cookbook-openshift3']['openshift_client_binary'] : node['cookbook-openshift3']['openshift_common_client_binary']
    if node['cookbook-openshift3']['ose_major_version'].split('.')[1].to_i < 10
      execute 'Annotate Hosted Registry Project' do
        command "#{oc_client} annotate --overwrite namespace/${namespace_registry} openshift.io/node-selector=${selector_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
        environment(
          'selector_registry' => node['cookbook-openshift3']['openshift_hosted_registry_selector'],
          'namespace_registry' => node['cookbook-openshift3']['openshift_hosted_registry_namespace']
        )
        not_if "#{oc_client} get namespace/${namespace_registry} --template '{{ .metadata.annotations }}' --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']} | fgrep -q openshift.io/node-selector:${selector_registry}"
        only_if "#{oc_client} get namespace/${namespace_registry} --no-headers --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
      end
    end

    execute 'Deploy Hosted Registry' do
      command "#{oc_client} adm registry --images=#{node['cookbook-openshift3']['openshift_docker_hosted_registry_image']} --selector=${selector_registry} -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
      environment(
        'selector_registry' => node['cookbook-openshift3']['openshift_hosted_registry_selector'],
        'namespace_registry' => node['cookbook-openshift3']['openshift_hosted_registry_namespace']
      )
      only_if "[[ `#{oc_client} get pod --selector=docker-registry=default --no-headers --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']} | wc -l` -eq 0 ]]"
    end

    unless node['cookbook-openshift3']['openshift_hosted_registry_insecure']
      execute 'Generate certificates for Hosted Registry' do
        command "#{oc_client} adm ca create-server-cert --signer-cert=#{node['cookbook-openshift3']['openshift_master_config_dir']}/ca.crt --signer-key=#{node['cookbook-openshift3']['openshift_master_config_dir']}/ca.key --signer-serial=#{node['cookbook-openshift3']['openshift_master_config_dir']}/ca.serial.txt --hostnames=\"$(#{oc_client} get service docker-registry -o jsonpath='{.spec.clusterIP}' --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']} -n #{node['cookbook-openshift3']['openshift_hosted_registry_namespace']}),docker-registry.#{node['cookbook-openshift3']['openshift_hosted_registry_namespace']}.svc,docker-registry.#{node['cookbook-openshift3']['openshift_hosted_registry_namespace']}.svc.cluster.local,${docker_registry_route_hostname}\" --cert=#{node['cookbook-openshift3']['openshift_master_config_dir']}/registry.crt --key=#{node['cookbook-openshift3']['openshift_master_config_dir']}/registry.key --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
        environment(
          'docker_registry_route_hostname' => "docker-registry-#{node['cookbook-openshift3']['openshift_hosted_registry_namespace']}-#{node['cookbook-openshift3']['openshift_master_router_subdomain']}"
        )
        not_if "[[ -f #{node['cookbook-openshift3']['openshift_master_config_dir']}/registry.crt && -f #{node['cookbook-openshift3']['openshift_master_config_dir']}/registry.key ]]"
      end

      execute 'Create secret for certificates' do
        command "#{oc_client} create secret generic registry-certificates --from-file=#{node['cookbook-openshift3']['openshift_master_config_dir']}/registry.crt --from-file=#{node['cookbook-openshift3']['openshift_master_config_dir']}/registry.key -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
        environment(
          'namespace_registry' => node['cookbook-openshift3']['openshift_hosted_registry_namespace'],
          'docker_registry_route_hostname' => "docker-registry-#{node['cookbook-openshift3']['openshift_hosted_registry_namespace']}-#{node['cookbook-openshift3']['openshift_master_router_subdomain']}"
        )
        only_if "[[ `#{oc_client} get secret registry-certificates -n ${namespace_registry} --no-headers --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']} | wc -l` -eq 0 ]]"
      end

      %w[default registry].each do |service_account|
        execute "Add secret to registry's pod service accounts (#{service_account})" do
          command "#{oc_client} secrets add ${sa} registry-certificates -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
          environment(
            'namespace_registry' => node['cookbook-openshift3']['openshift_hosted_registry_namespace'],
            'sa' => service_account
          )
          not_if "[[ `#{oc_client} get -o template sa/${sa} --template={{.secrets}} -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}` =~ \"registry-certificates\" ]]"
        end
      end

      execute 'Attach registry-certificates secret volume' do
        command "#{oc_client} volume deploymentconfig/docker-registry --add --type=secret --secret-name=registry-certificates -m /etc/secrets -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
        environment(
          'namespace_registry' => node['cookbook-openshift3']['openshift_hosted_registry_namespace']
        )
        not_if "#{oc_client} volume deploymentconfig/docker-registry -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']} | grep /etc/secrets"
      end

      execute 'Configure certificates in registry deplomentConfig' do
        command "#{oc_client} env deploymentconfig/docker-registry REGISTRY_HTTP_TLS_CERTIFICATE=/etc/secrets/registry.crt REGISTRY_HTTP_TLS_KEY=/etc/secrets/registry.key -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
        environment(
          'namespace_registry' => node['cookbook-openshift3']['openshift_hosted_registry_namespace']
        )
        not_if "[[ `#{oc_client} env deploymentconfig/docker-registry --list -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}` =~ \"REGISTRY_HTTP_TLS_CERTIFICATE=/etc/secrets/registry.crt\" && `#{oc_client} env deploymentconfig/docker-registry --list -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}` =~ \"REGISTRY_HTTP_TLS_KEY=/etc/secrets/registry.key\" ]]"
      end

      if node['cookbook-openshift3']['openshift_push_via_dns']
        execute 'Update registry environment variables when pushing via dns' do
          command "#{oc_client} env deploymentconfig/docker-registry ${environment} -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
          environment(
            'namespace_registry' => node['cookbook-openshift3']['openshift_hosted_registry_namespace'],
            'environment' => node['cookbook-openshift3']['ose_major_version'].split('.')[1].to_i >= 9 ? 'REGISTRY_OPENSHIFT_SERVER_ADDR=docker-registry.default.svc:5000' : 'OPENSHIFT_DEFAULT_REGISTRY=docker-registry.default.svc:5000'
          )
          not_if "[[ `#{oc_client} env deploymentconfig/docker-registry --list -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}` =~ \"${environment}\" ]]"
        end
      end

      execute 'Update registry liveness probe from HTTP to HTTPS' do
        command "#{oc_client} patch deploymentconfig/docker-registry -p '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"registry\",\"livenessProbe\":{\"httpGet\":{\"scheme\":\"HTTPS\"}}}]}}}}' -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
        environment(
          'namespace_registry' => node['cookbook-openshift3']['openshift_hosted_registry_namespace']
        )
        not_if "[[ `#{oc_client} get deploymentconfig/docker-registry -o jsonpath=\'{.spec.template.spec.containers[*].livenessProbe.httpGet.scheme}\' -n ${namespace_registry} --no-headers --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}` =~ \"HTTPS\" ]]"
      end

      execute 'Update registry readiness probe from HTTP to HTTPS' do
        command "#{oc_client} patch deploymentconfig/docker-registry -p '{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"registry\",\"readinessProbe\":{\"httpGet\":{\"scheme\":\"HTTPS\"}}}]}}}}' -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
        environment(
          'namespace_registry' => node['cookbook-openshift3']['openshift_hosted_registry_namespace']
        )
        not_if "[[ `#{oc_client} get deploymentconfig/docker-registry -o jsonpath=\'{.spec.template.spec.containers[*].readinessProbe.httpGet.scheme}\' -n ${namespace_registry} --no-headers --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}` =~ \"HTTPS\" ]]"
      end
    end

    if new_resource.persistent_registry
      execute 'Add volume to Hosted Registry' do
        command "#{oc_client} volume deploymentconfig/docker-registry --add --overwrite -t persistentVolumeClaim --claim-name=${registry_claim} --name=registry-storage -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
        environment(
          'namespace_registry' => node['cookbook-openshift3']['openshift_hosted_registry_namespace'],
          'registry_claim' => new_resource.persistent_volume_claim_name
        )
        not_if "[[ `#{oc_client} get -o template deploymentconfig/docker-registry --template={{.spec.template.spec.volumes}} -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}` =~ \"${registry_claim}\" ]]"
      end
      execute 'Auto Scale Registry based on label' do
        command "#{oc_client} scale deploymentconfig/docker-registry --replicas=${replica_number} -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
        environment(
          'replica_number' => Mixlib::ShellOut.new("#{oc_client} get node --no-headers --selector=#{node['cookbook-openshift3']['openshift_hosted_registry_selector']} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']} | wc -l").run_command.stdout.strip,
          'namespace_registry' => node['cookbook-openshift3']['openshift_hosted_registry_namespace']
        )
        not_if "[[ `#{oc_client} get pod --selector=docker-registry=default --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']} --no-headers | wc -l` -eq ${replica_number} ]]"
      end
    end
  end
end

action :redeploy_certificate do
  oc_client = node['cookbook-openshift3']['ose_major_version'].split('.')[1].to_i >= 10 ? node['cookbook-openshift3']['openshift_client_binary'] : node['cookbook-openshift3']['openshift_common_client_binary']
  execute 'Re-Generate certificates for Hosted Registry' do
    command "#{oc_client} adm ca create-server-cert --signer-cert=#{node['cookbook-openshift3']['openshift_master_config_dir']}/ca.crt --signer-key=#{node['cookbook-openshift3']['openshift_master_config_dir']}/ca.key --signer-serial=#{node['cookbook-openshift3']['openshift_master_config_dir']}/ca.serial.txt --hostnames=\"$(#{oc_client} get service docker-registry -o jsonpath='{.spec.clusterIP}' --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']} -n #{node['cookbook-openshift3']['openshift_hosted_registry_namespace']}),docker-registry.#{node['cookbook-openshift3']['openshift_hosted_registry_namespace']}.svc,docker-registry.#{node['cookbook-openshift3']['openshift_hosted_registry_namespace']}.svc.cluster.local,${docker_registry_route_hostname}\" --cert=#{node['cookbook-openshift3']['openshift_master_config_dir']}/registry.crt --key=#{node['cookbook-openshift3']['openshift_master_config_dir']}/registry.key --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
    environment(
      'docker_registry_route_hostname' => "docker-registry-#{node['cookbook-openshift3']['openshift_hosted_registry_namespace']}-#{node['cookbook-openshift3']['openshift_master_router_subdomain']}"
    )
    cwd node['cookbook-openshift3']['openshift_master_config_dir']
  end

  execute 'Update secret for certificates' do
    command "#{oc_client} create secret generic registry-certificates --from-file=#{node['cookbook-openshift3']['openshift_master_config_dir']}/registry.crt --from-file=#{node['cookbook-openshift3']['openshift_master_config_dir']}/registry.key -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']} --dry-run -o yaml | #{oc_client} apply -f - -n ${namespace_registry} --config=#{node['cookbook-openshift3']['openshift_master_config_dir']}/admin.kubeconfig --server #{node['cookbook-openshift3']['openshift_master_loopback_api_url']}"
    environment(
      'namespace_registry' => node['cookbook-openshift3']['openshift_hosted_registry_namespace'],
      'docker_registry_route_hostname' => "docker-registry-#{node['cookbook-openshift3']['openshift_hosted_registry_namespace']}-#{node['cookbook-openshift3']['openshift_master_router_subdomain']}"
    )
    cwd node['cookbook-openshift3']['openshift_master_config_dir']
  end
end
