# st2-ansible-ha

## TODO

- [x] MongoDB auth
- [x] RabbitMQ auth
- [x] Configure workers to point at controller in st2.conf
  - API
  - MongoDB
  - RabbitMQ
- [x] Datastore key distribution
- [ ] inject SSL certs
  - where do we get these from? (see questions)
- [ ] distributed CA (directory from repo)
- [x] firewal configs
- [ ] nginx configs
- [ ] redis
  - install redis python module
- [ ] Makefile (or similar) to setup "all of the things"
  - virtualenv
  - python requirements
  - ansible collections
- [ ] monitoring
- [ ] Ansible Collections formatting
- [ ] Terraform deploy
- [ ] Pack management workflows
- [ ] backup workflows
- [ ] st2schedule on one host
- [ ] Packer builder

## Thoughts/questions

- need nginx configs
- RHEL (preferred) vs Ubuntu
- will all of the hosts be defined in inventory?
  - if not, how will we enumerate/adjust/whatever the backend workers in the controller nginx config when a new one is added?
  - should we just use Consul/service-discovery?
- For SSL certs
  - where is the CA?
  - Will each node have its own cert or just distribute a wildcard?

## Requirements

- StackStorm Controller setup (not HA Mongo, Redis, RabbitMQ)
- Stackstorm worker setup
- Coordination database (Redis)
- Simple monitoring (prometheus, grafana)
- Make encryption key on the ansible host, copy to workers
- Any UST requriements
- Structure in "ansible collections" https://docs.ansible.com/ansible/latest/dev_guide/developing_collections.html#developing-collections
- Terraform deployment in Azure
- Pack management deployment workflows
- Backup workflows
- st2scheduler only run on one worker (or just run it on the controller)
- Packer builder for Azure images
- Inject SSL certs (from vars)

## Upstream PRs needed

- st2web, remove st2 dependency
  - https://github.com/StackStorm/ansible-st2/pull/279
- datastore key distribution
  - https://github.com/StackStorm/ansible-st2/pull/280


## Development

### Ansible Setup

```shell
python3 -m venv virtualenv
source ./virtualenv/bin/activate
pip install ansible
```

```shell
# collections setup
ansible-galaxy collection install community.mongodb community.rabbitmq ansible.posix geerlingguy.redis

# roles setup
ansible-galaxy install geerlingguy.redis

```

### Vagrant Setup

Install Vagrant: https://www.vagrantup.com/docs/installation

Note: our Vagrantfile uses `libvirt` by default, can be made to use VirtualBox though

Start up the Vagrant VMs:
```shell
vagrant up
```

### Provisioning the controller

```shell
ansible-playbook -i inventories -l controllers stackstorm-controller.yml
```

```shell
ansible-playbook -i inventories -l workers stackstorm-worker.yml
```
