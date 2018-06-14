#
# Cookbook Name:: cookbook-openshift3
# Providers:: openshift_reset_host
#
# Copyright (c) 2015 The Authors, All Rights Reserved.

use_inline_resources
provides :openshift_reset_host if defined? provides

def whyrun_supported?
  true
end

action :reset do
  converge_by 'Resetting server' do
    helper = OpenShiftHelper::NodeHelper.new(node)
    is_node_server = helper.on_node_server?

    systemd_unit 'docker' do
      action :nothing
      retry_delay 2
      retries 5
    end

    %W(#{node['cookbook-openshift3']['openshift_service_type']}-node openvswitch #{node['cookbook-openshift3']['openshift_service_type']}-master #{node['cookbook-openshift3']['openshift_service_type']}-master-api #{node['cookbook-openshift3']['openshift_service_type']}-master-controllers etcd etcd_container haproxy).each do |svc|
      systemd_unit svc do
        action %i(stop disable)
        ignore_failure true
      end
    end

    Mixlib::ShellOut.new('systemctl reset-failed').run_command
    Mixlib::ShellOut.new('systemctl daemon-reload').run_command

    execute 'Remove br0 interface' do
      command 'ovs-vsctl del-br br0 || true'
    end

    %w(lbr0 vlinuxbr vovsbr).each do |interface|
      execute "Remove linux interfaces #{interface}" do
        command "ovs-vsctl del #{interface} || true"
      end
    end

    ::Dir.glob('/var/lib/origin/openshift.local.volumes/**/*').select { |fn| ::File.directory?(fn) }.each do |dir|
      execute "Unmount kube volumes for #{dir}" do
        command "$ACTION #{dir} || true"
        environment 'ACTION' => 'umount'
      end
    end

    %W(#{node['cookbook-openshift3']['openshift_service_type']} #{node['cookbook-openshift3']['openshift_service_type']}-master #{node['cookbook-openshift3']['openshift_service_type']}-node #{node['cookbook-openshift3']['openshift_service_type']}-sdn-ovs #{node['cookbook-openshift3']['openshift_service_type']}-clients cockpit-bridge cockpit-docker cockpit-shell cockpit-ws openvswitch tuned-profiles-#{node['cookbook-openshift3']['openshift_service_type']}-node #{node['cookbook-openshift3']['openshift_service_type']}-excluder #{node['cookbook-openshift3']['openshift_service_type']}-docker-excluder etcd haproxy).each do |remove_package|
      package remove_package do
        action :remove
        ignore_failure true
      end
    end

    %W(/var/lib/origin/* /etc/dnsmasq.d/origin-dns.conf /etc/dnsmasq.d/origin-upstream-dns.conf /etc/NetworkManager/dispatcher.d/99-origin-dns.sh /etc/sysconfig/openvswitch* /etc/sysconfig/#{node['cookbook-openshift3']['openshift_service_type']}-node /etc/sysconfig/#{node['cookbook-openshift3']['openshift_service_type']}-node-dep /etc/systemd/system/openvswitch.service* /etc/systemd/system/#{node['cookbook-openshift3']['openshift_service_type']}-master.service /etc/systemd/system/#{node['cookbook-openshift3']['openshift_service_type']}-master-controllers.service* /etc/systemd/system/#{node['cookbook-openshift3']['openshift_service_type']}-master-api.service* /etc/systemd/system/#{node['cookbook-openshift3']['openshift_service_type']}-node-dep.service /etc/systemd/system/#{node['cookbook-openshift3']['openshift_service_type']}-node.service /etc/systemd/system/#{node['cookbook-openshift3']['openshift_service_type']}-node.service.wants /run/openshift-sdn /etc/sysconfig/#{node['cookbook-openshift3']['openshift_service_type']}-master* /etc/sysconfig/#{node['cookbook-openshift3']['openshift_service_type']}-master-api* /etc/systemd/system/docker.service.wants/#{node['cookbook-openshift3']['openshift_service_type']}-master-controllers.service /etc/sysconfig/#{node['cookbook-openshift3']['openshift_service_type']}-master-controllers* /etc/sysconfig/openvswitch* /root/.kube /usr/share/openshift/examples /usr/share/openshift/hosted /usr/local/bin/openshift /usr/local/bin/oadm /usr/local/bin/oc /usr/local/bin/kubectl #{node['cookbook-openshift3']['etcd_conf_dir']}/* /etc/systemd/system/etcd.service.d /etc/systemd/system/etcd* /usr/lib/systemd/system/etcd* /etc/profile.d/etcdctl.sh #{node['cookbook-openshift3']['openshift_master_api_systemd']} #{node['cookbook-openshift3']['openshift_master_controllers_systemd']} /etc/bash_completion.d/oc /etc/systemd/system/haproxy.service.d /etc/haproxy /etc/yum.repos.d/centos-openshift-origin*.repo).each do |file_to_remove|
      helper.remove_dir(file_to_remove)
    end

    ::Dir.glob('/var/lib/origin/openshift.local.volumes/**/*').select { |fn| ::File.directory?(fn) }.each do |dir|
      execute "Force Unmount kube volumes #{dir}" do
        command "$ACTION #{dir} || true"
        environment 'ACTION' => 'umount'
      end
    end

    helper.remove_dir('/var/lib/origin/*')

    execute 'Clean Iptables rules' do
      command 'sed -i \'/OS_FIREWALL_ALLOW/d\'  /etc/sysconfig/iptables'
    end

    helper.remove_dir('/etc/iptables.d/firewall_*')

    execute 'Clean Iptables saved rules' do
      command 'sed -i \'/OS_FIREWALL_ALLOW/d\' /etc/sysconfig/iptables.save'
      only_if '[ -f /etc/sysconfig/iptables.save ]'
    end

    Mixlib::ShellOut.new('systemctl daemon-reload').run_command

    systemd_unit 'iptables' do
      action :restart
    end

    execute '/usr/sbin/rebuild-iptables' do
      retry_delay 10
      retries 3
    end

    if is_node_server || node['cookbook-openshift3']['deploy_containerized']

      ruby_block 'Remove docker directory (Contents Only)' do
        block do
          helper.remove_dir('/var/lib/docker/*')
        end
        notifies :stop, 'systemd_unit[docker]', :before
      end

      execute 'Resetting docker storage' do
        command '/usr/bin/docker-storage-setup --reset'
      end

      ruby_block 'Reload SystemD Daemon services' do
        block do
          Mixlib::ShellOut.new('systemctl daemon-reload').run_command
        end
        notifies :start, 'systemd_unit[docker]', :immediately
      end

      # Add to force the daemon-reload mechanism as we do not remove files within /etc/origin
      ruby_block 'Insert Dummy line for forcing node to reload' do
        block do
          file = Chef::Util::FileEdit.new('/etc/origin/node/node-config.yaml')
          file.insert_line_if_no_match('/^#DUMMY_LINE/', '#DUMMY_LINE FOR RESTARTING')
          file.write_file
        end
        only_if { ::File.exist?('/etc/origin/node/node-config.yaml') }
      end
    end
  end
end
