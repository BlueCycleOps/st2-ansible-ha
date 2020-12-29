#!/bin/bash -e

IAM_INSTANCE_ROLE="CloudWatchAgentServerInstanceRole"

SUBNET_GATEWAY=${DEFAULT_GATEWAY:-10.5.1.254}

detect_linux_flavor() {

  if [[ grep -qsF 'CentOS Linux release 8' /etc/centos-release ]]; then

    DEFAULT_USER=centos

    LINUX_FLAVOR=centos

  elif0 [[ grep -sF "Amazon Linux release 2" /etc/system-release ]]; then

    DEFAULT_USER=ec2-user

    LINUX_FLAVOR=amazon

  fi

}

set_default_gateway() {

    # Setting Default Gateway for subnet we are in

    # NetworkManager.service works for amazon linux 2 and centos 8

    sudo grep -qsF "${SUBNET_GATEWAY}" /etc/sysconfig/network || (echo "GATEWAY=${SUBNET_GATEWAY}" | sudo tee -a /etc/sysconfig/network)

    if [[ "${LINUX_FLAVOR}" = "centos" ]]; then

      sudo systemctl restart NetworkManager.service

    elif [[ "${LINUX_FLAVOR}" = "amazon" ]]; then

      sudo systemctl restart network.service

    fi

    echo "Set default gateway to: ${SUBNET_GATEWAY}"

}

detect_mounted_xfs_volumes() {

    mounted_volumes=($(mount | grep xfs | awk '{ print $3 }'))

    disk_prefix="--disk-path="

    for mount in "${mounted_volumes[@]}"

      do

        volumes_string+="${disk_prefix}${mount}"

        echo -e "Found xfs mount at: ${mount}"

      done

}

install_cloud_watch_metrics() {

    # Monitoring memory and disk metrics for Amazon EC2 Linux instances

    # ref: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/mon-scripts.html

    if [[ "${LINUX_FLAVOR}" = "centos" ]]; then

      sudo dnf config-manager --set-enabled PowerTools

      sudo yum install -y perl-Switch perl-DateTime perl-Sys-Syslog perl-LWP-Protocol-https perl-Digest-SHA.x86_64 unzip

      sudo dnf config-manager --set-disabled PowerTools

    elif [[ "${LINUX_FLAVOR}" = "amazon" ]]; then

      echo "Found Amazon Linux"

      sudo yum install -y perl-Switch perl-core perl-DateTime perl-Sys-Syslog perl-LWP-Protocol-https perl-Digest-SHA.x86_64

    fi

    # Download Cloudwatch Monitoring Scripts

    # TODO: Need to detect centos or amazon linux

    # cat /etc/centos-release

    cd "/home/${DEFAULT_USER}" || exit # ~/

    curl -s https://aws-cloudwatch.s3.amazonaws.com/downloads/CloudWatchMonitoringScripts-1.2.2.zip -O

    unzip -o CloudWatchMonitoringScripts-1.2.2.zip && rm CloudWatchMonitoringScripts-1.2.2.zip && cd aws-scripts-mon || exit

    # test

    # exclude from script

    ./mon-put-instance-data.pl --mem-util --verify --verbose

    # Check for IAM role - we do this by querying the EC2 instance metadata for the current IAM role

    # If we get a 404, then there isn't one and the script should exit

    # Success:

    # curl  http://169.254.169.254/latest/meta-data/iam/info

    # {

    #   "Code" : "Success",

    #   "LastUpdated" : "2020-09-16T18:55:46Z",

    #   "InstanceProfileArn" : "arn:aws:iam::675479424983:instance-profile/CloudWatchLogsAgent",

    #   "InstanceProfileId" : "AIPAZ2RNWB7L7DAFLT4HE"

    # Failure

    # [ec2-user@ip-10-15-11-138 ~]$ curl  http://169.254.169.254/latest/meta-data/iam/info

    # <?xml version="1.0" encoding="iso-8859-1"?>

    # <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"

    #        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

    # <html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">

    #  <head>

    #   <title>404 - Not Found</title>

    #  </head>

    #  <body>

    #   <h1>404 - Not Found</h1>

    #  </body>

    # </html>

    # Should be pulled in from environment variable at runtime

    response=$(curl http://169.254.169.254/latest/meta-data/iam/info)

    if (echo "$response" | grep "404 - Not Found"); then

        echo "IAM Role query return 404. Exiting..."

        exit 1

    fi

    # If Instance role present, ensure it's the one we are expecting, set at the top of the script

    if ! (echo "$response" | grep "instance-profile/${IAM_INSTANCE_ROLE}"); then

        echo "IAM Instance Role not found... Exiting"

        exit 1

    fi

    /home/"${DEFAULT_USER}"/aws-scripts-mon/mon-put-instance-data.pl --mem-used-incl-cache-buff --mem-util --disk-space-util "${volumes_string}"

    # add to cron

    # Only overwrite crontab if this is the first time or we need to update the volume string

    sudo grep -qsF "'${volumes_string}'" /var/spool/cron/root || echo "*/5 * * * * /home/${DEFAULT_USER}/aws-scripts-mon/mon-put-instance-data.pl --mem-used-incl-cache-buff --mem-util --disk-space-util ${volumes_string} --from-cron" | sudo tee -a /var/spool/cron/root

}

detect_linux_flavor

set_default_gateway

detect_mounted_xfs_volumes

install_cloud_watch_metrics

