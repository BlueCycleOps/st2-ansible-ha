# st2-ansible-ha

## TODO

- [x] MongoDB auth
- [x] RabbitMQ auth
- [x] Configure workers to point at controller in st2.conf
  - API
  - MongoDB
  - RabbitMQ
- [x] Datastore key distribution
- [x] distributed CA (directory from repo)
- [x] firewal configs
- [x] nginx configs
- [x] redis
  - install redis python module
- [x] `st2chatops` on controller
- [x] `st2notifier` on controller
- [x] ability to disable certain services (st2ctl)
- [x] `st2timersservice` on controller
- [x] Pack management workflows
- [x] backup workflows
- [ ] monitoring
  - [x] grafana
    - [ ] dashboards
  - [x] influxdb
    - [x] influxdb auth
  - [ ] telegraf agent
    - [x] base
    - [ ] mongod
    - [ ] rabbitmq
    - [ ] nginx
    - [ ] stackstorm (statsd)
- [ ] Ansible Collections formatting
- [ ] Makefile (or similar) to setup "all of the things"
  - virtualenv
  - python requirements
  - ansible collections
- [ ] Terraform deploy
- [ ] Packer builder
- [ ] inject SSL certs
  - where do we get these from? (see questions)

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
- python packages to install redis module:
  - https://github.com/StackStorm/ansible-st2/pull/281


## Development

### Ansible Setup

```shell
python3 -m venv virtualenv
source ./virtualenv/bin/activate
pip install ansible
```

```shell
# collections setup
ansible-galaxy collection install community.general community.mongodb community.rabbitmq ansible.posix
```

### Vagrant Setup

Install Vagrant: https://www.vagrantup.com/docs/installation

Note: our Vagrantfile uses `libvirt` by default, can be made to use VirtualBox though

Start up the Vagrant VMs:
```shell
vagrant up
```

### Datastore encryption key

When the `st2ha` playbook is run, it checks for and generates a StackStorm encryption
key, placing it in `files/st2/datastore.json`.

If you already have a datastore encryption key, simply create the directory `files/st2`
and place your `datastore.json` file in there. Our role checks for the existence of this
file and will use the existing key if it already exists.

This key will be copied over to the hosts during the `stackstorm-workers.yaml` 
and `stackstorm-controllers.yaml` playbooks as part of the `StackStorm.st2` role.

### Distributing CA certificates

The `BlueCycleOps.ssl` role is able to distribute a CA certificate to all of the
StackStorm nodes and install it as a trusted CA cert in each of those OSes.

To do this we look, by default, in the directory `files/ssl/ca/` and install all of
those CA certificates onto the target hosts.

So, to get started make that directory:
```shell
mkdir -p files/ssl/ca
```

Next, move all of the CA certificates into that directory
```
cp xxx.crt yyy.pem files/ssl/ca/
```

Finally, run the playbooks and those CA certificates will be pushed to the hosts!


### Provisioning the controller

```shell
ansible-playbook -i inventories -l controllers stackstorm-controller.yml
```

### Provisioning workers

```shell
ansible-playbook -i inventories -l workers stackstorm-worker.yml
```

### Provisioning monitoring

```shell
ansible-playbook -i inventories -l monitoring stackstorm-monitoring.yml
```

### Deploying packs to workers

```shell
ansible-playbook -i inventories -l workers stackstorm-packs-deploy.yml
```

#### Deploying pack configs

At some point it will be necessary to populate pack configs on the StackStorm workers.
On the worker nodes, these files reside in the `/opt/stackstorm/configs` directory.
We support populating these configs!

Simply create your configs inside of `files/st2/configs` and all files within this directory
will be copied over to the workers into the directory `/opt/stackstorm/configs` during
the `stackstorm-packs-deploy.yml` playbook.

#### Deploying datastore keys

Often times during content deployment there will be a need to set values of some
datastore keys. Our playbook `stackstorm-packs-deploy.yml` happily supports this use case.

The deployment process works by copying the keys files in the `files/st2/keys` directory
and importing them into the datastore using the `st2 key load` command.

To take advatange of this, create either a YAML or JSON keys file in the format
described in the [StackStorm Datastore docs](https://docs.stackstorm.com/datastore.html#loading-key-value-pairs-from-a-file)
then place these files inside of `files/st2/keys`.

Now, running the `stackstorm-packs-deploy.yml` playbook will copy these keys files and
load them into the datastore.

If you're interested in storing pre-encrypted values in your keys files, so they don't
have to be stored unencrypted, this is fully supported using the pattern described
in the [StackStorm docs](https://docs.stackstorm.com/datastore.html#storing-pre-encrypted-secrets)

### StackStorm Backups

#### Perform a full backup

```shell
ansible-playbook -i inventories -l workers,controllers stackstorm-backup.yml
```

This will create a directory on each host `/opt/stackstorm/backups/2020xxx` where the last
part is the date/time the backup was performed.

Within that directory will contain the following files
```
# Controller - Dump of the MongoDB database 
mongodb_dump_2020xxx.gzip.archive

# Controller - Archive of the important StackStorm files
#  /etc/st2 - contains the stackstorm core config along with the datastore encryption key
#  /etc/nginx - contains the nginx configs
#  /opt/stackstorm/chatops/st2chatops.env - contains the ChatOps config
stackstorm_2020xxx.tar.gz

# Worker - Archive of the important StackStorm files
#  /etc/st2 - contains the stackstorm core config along with the datastore encryption key
#  /etc/nginx - contains the nginx configs
#  /opt/stackstorm/configs - contains the pack configs
#  /opt/stackstorm/packs - contains the pack content itself
#  /opt/stackstorm/virtualenvs - contains the pack virtualenvs
stackstorm_2020xxx.tar.gz
```


#### Restoring from a backup

MongoDB
```shell
mongorestore -u admin -p 'xxx' --drop --gzip --archive=/opt/stackstorm/backups/2020xxx/mongodb_dump_2020xxx.gzip.archive
```

StackStorm
```shell
st2ctl stop
cd /opt/stackstorm/backups/2020xxx
tar -xvf stackstorm_2020xxx.tar.gz
/bin/cp -rf etc /
/bin/cp -rf opt /
st2ctl start
# only need to do this on one worker
st2ctl reload --register-all
```


### Monitoring

Configuring the monitoring server (InfluxDB + Grafana)
```shell
ansible-playbook -i inventories -l monitoring stackstorm-monitoring.yml
```

Configuring the StackStorm servers with monitoring agents (Telegraf)
```shell
ansible-playbook -i inventories -l controllers,workers stackstorm-telegraf.yml
```
