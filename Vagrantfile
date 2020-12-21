# -*- mode: ruby -*-
# vi: set ft=ruby :

# options:
#  'virtualbox'
#  'libvirt'
provider = ENV['PROVIDER'] || 'libvirt'
provider = provider.to_sym

# virtualbox:
#  - centos/6
#  - centos/7
#  - generic/centos8
#  - 'ubuntu/trusty64'
#  - 'ubuntu/xenial64'
# libvirt
#  - centos/6
#  - centos/7
#  - generic/centos8
#  - generic/ubuntu1404
#  - generic/ubuntu1604
box_centos = ENV['BOX'] || 'generic/centos8'

vms = [
  {
    name: 'st2ctr',
    ip: '192.168.121.100'
  },
  {
    name: 'st2wrk1',
    ip: '192.168.121.101'
  },
  {
    name: 'st2wrk2',
    ip: '192.168.121.102'
  }
]

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = '2'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  vms.each do |vm|
    config.vm.define(vm[:name]) do |centos|
      hostname = "#{vm[:name]}.localdomain"
      # Box details
      centos.vm.box = box_centos
      centos.vm.hostname = hostname
      centos.vm.network :private_network, ip: vm[:ip]
      centos.vm.synced_folder '.', '/vagrant', disabled: true

      # Box Specifications
      if provider == :virtualbox
        centos.vm.provider :virtualbox do |vb|
          vb.name = hostname
          vb.memory = 2048
          vb.cpus = 2
          vb.customize ['modifyvm', :id, '--uartmode1', 'disconnected']
        end
      elsif provider == :libvirt
        centos.vm.provider :libvirt do |lv|
          lv.host = hostname
          lv.memory = 2048
          lv.cpus = 2
          lv.uri = 'qemu:///system'
          lv.storage_pool_name = 'images'
        end
      else
        raise "Unsupported provider: #{provider}"
      end
    end
  end
end
