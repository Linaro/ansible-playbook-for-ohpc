# An Ansible Playbook for Stress-Free Installation of OpenHPC Environment onto A Cluster

## About this playbook

This Ansible playbook facilitates installation of an OpenHPC environment onto your supercomputer cluster after a nominal manual setup.

OpenHPC (http://openhpc.community/) is one of the major software frameworks for High-Performance Computing (HPC) on the Linux platform. It provides a large number of software packages and supports a wide range of applications.

Ansible is a more sophisticated package manager than conventional ones such as yum, apt, etc., and this playbook, a kind of script for Ansible, eliminates most of the potential conflicts and other issues associated with installing multiple HPC packages.


Below we explain how you can install an OpenHPC environment onto a CentOS7 cluster using this Ansible playbook.

## Usage

### Target Environment

This Ansible playbook is designed for a CentOS7 cluster that conforms to what is described in _Cluster Building Recipes_, which, when properly set up, has the following kinds of nodes.
1. System Management Server (SMS) --- This node provides managerial functions for the whole cluster, such as time synchronization by NTP and allocation of jobs to suitable CNs. Optionally, it compiles application programs.

1. Computing Nodes (CNs) --- Application programs run on these servers.
1. File Servers (I/O Nodes) --- These nodes are dedicated to file system services (e.g., Lustre, BeeGFS, etc.) (to be supported).
1. Baseboard Management Controllers (BMCs) --- These devices provide power control functions and console output redirection. Multiple computing nodes are controlled by a single BMC.
1. Development Nodes (DNs) --- These nodes provide development tools for application developers. Compilers (e.g., GCC/LLVM), scientific libraries, MPI libraries will be installed into these nodes.

### Network Configurations

Since our cluster conforms to what is described in _Cluster Building Recipes_, it has the following three kinds of networks:

1. Management Network --- System administrators manage the cluster by accessing relevant nodes via this network. Ansible uses this network.
1. Computing Network --- Computing jobs on CNs communicate with one another on this network, for example, using MPI.
1. BMC Network --- BMCs execute their functions exclusively on this network.

For coherence purposes, we assume that all nodes use the network device eth1 for the Management Network, eth2 for the Computing Network, and eth3 for the BMC Network.

Network Type|Network Address|Netmask|Ether device
---|---|---|---|---
Computing Network|192.168.44.0|255.255.255.0|eth2
Management Network|192.168.33.0|255.255.255.0|eth1
BMC Network|192.168.66.0 |255.255.255.0|eth3

We hereafter assume that our cluster has an SMS, two CNs and a BMC.

In addition to this, we assume that SMS and CNs double as DNs.

We assume that these networks are configured as follows:

Node Type |Hostname|IP address on Computing Network|IP address on Management Network|IP address on BMC Network
---|---|---|---|---
SMS|sms|192.168.44.11|192.168.33.11|192.168.66.11
CN1|c1|192.168.44.21|192.168.33.21|192.168.66.21
CN2|c2|192.168.44.22|192.168.33.22|192.168.66.22

### Preparations
For this Ansible playbook to work, a fully-functional Ansible installation needs to be present on SMS that can interact with other nodes,
which can be realized by following the two steps below:

* Step 1. Install Ansible on SMS.
* Step 2. Enable passwordless login for Ansible on all the nodes in the cluster except BMCs

#### Install Ansible on SMS

Run the following command at the command prompt on SMS to install Ansible:

```
$ sudo yum install -y epel ansible
```

#### Enable passwordless login for Ansible on all the nodes in the cluster except BMCs

For Ansible on SMS to be able to take necessary actions on other nodes, it needs to be able to log in to them without providing a password. This playbook does not require BMCs be open to passwordless login for historical reasons, which situation might change in the future.

The following steps need to be taken on all nodes on the cluster except BMCs. This will allow Ansible running on the SMS to be able to log on to those nodes as administrator without having to provide a password or respond to a prompt.

##### Creating `.ssh/config` to avoid strict host key checking

Creating a `.ssh/config` file to disable strict host key checking. Otherwise, when Ansible on SMS tries to contact a node via SSH, it will be asked if Ansible is connecting the node for the first time. A manual keytype is required there for the Ansible playbook to proceed; without it, the playbook will halt. When strict host key checking is disabled, this confirmation step will be skipped, thus allowing the Ansible playbook to continue without any problem.

Log in to the SMS and then create `${HOME}/.ssh/config` and write in there precisely the following:

```  .ssh/config
Host *
   StrictHostKeyChecking no
   UserKnownHostsFile /dev/null
```

Set the proper permissions to `${HOME}/.ssh/config`.

```
$ chmod 600 ${HOME}/.ssh/config
```

##### Set up public key authentication for root login

Follow the steps below:

1. Create an SSH key pair

Create an SSH key pair on the SMS by the following command:
```
$ ssh-keygen -t rsa -b 4096 -C ""
```
1. Add the public key you have just created above to the `/root/.ssh/authorized_keys` file on all the nodes except BMCs, including SMS

Please execute the following commands. Note the first two commands need to be performed by a non-privileged user; we will use centos as an example:


```
$   cp ~centos/.ssh/id_rsa.pub authorized_keys
$   sudo su -
#   touch /root/.ssh/authorized_keys
#   cat ~centos/authorized_keys >> /root/.ssh/authorized_keys
#   chmod 600 /root/.ssh/authorized_keys
```
Below is an example of the execution log of this step:
```
[centos@sms ~]$ ssh-keygen -t rsa -b 4096 -C ""
Generating public/private rsa key pair.
Enter file in which to save the key (/home/centos/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/centos/.ssh/id_rsa.
Your public key has been saved in /home/centos/.ssh/id_rsa.pub.
The key fingerprint is:
1a:91:5b:3c:52:76:21:36:0f:55:5f:16:b6:ce:67:82
The key's randomart image is:
+--[ RSA 4096]----+
|        B.+o.  o+|
|       * *   ..o.|
|      + + .   .. |
|       = .   .o  |
|      o S   E .oo|
|       o       o.|
|      .          |
|                 |
|                 |
+-----------------+
[centos@sms ~]$ cp .ssh/id_rsa.pub authorized_keys
[centos@sms ~]$ sudo su -
[root@sms ~]# cp .ssh/authorized_keys .ssh/authorized_keys.orig
[root@sms ~]# cat ~centos/authorized_keys > .ssh/authorized_keys
[root@sms ~]# chmod 600 .ssh/authorized_keys
[root@sms ~]# logout
[centos@sms ~]$ scp authorized_keys c1:
Warning: Permanently added 'c1,192.168.1.11' (ECDSA) to the list of known hosts.
authorized_keys                                                                      100%  750     0.7KB/s   00:00
[centos@sms ~]$ scp authorized_keys c2:
Warning: Permanently added 'c2,192.168.1.6' (ECDSA) to the list of known hosts.
authorized_keys
[centos@sms ~]$ ssh c1
Warning: Permanently added 'c1,192.168.1.11' (ECDSA) to the list of known hosts.
Last login: Tue May 22 02:43:55 2018 from 192.168.1.9
[centos@c1 ~]$ sudo su -
[root@c1 ~]# cp .ssh/authorized_keys .ssh/authorized_keys.orig
[root@c1 ~]# cat ~centos/authorized_keys > .ssh/authorized_keys
[root@c1 ~]# chmod 600 .ssh/authorized_keys
[root@c1 ~]# ls -l .ssh/authorized_keys
-rw-------. 1 root root 1655 May 22 02:47 .ssh/authorized_keys
[root@c1 ~]# logout
[centos@c1 ~]$ logout
Connection to c1 closed.
[centos@sms ~]$ ssh c2
Warning: Permanently added 'c2,192.168.1.6' (ECDSA) to the list of known hosts.
Last login: Tue May 22 02:36:54 2018 from 192.168.1.5
[centos@c2 ~]$ sudo su -
[root@c2 ~]# cp .ssh/authorized_keys .ssh/authorized_keys.orig
[root@c2 ~]# cat ~centos/authorized_keys > .ssh/authorized_keys
[root@c2 ~]# chmod 600 .ssh/authorized_keys
[root@c2 ~]# ls -l .ssh/authorized_keys
-rw-------. 1 root root 1655 May 22 02:48 .ssh/authorized_keys
[root@c2 ~]# logout
[centos@c2 ~]$ logout
Connection to c2 closed.
[centos@sms ~]$
```
### Install this playbook


Please execute the following command to download this playbook:
```
$ git clone https://github.com/takekato/ansible-playbook-for-ohpc.git
```
Move to the directory where the downloaded playbook is. In the instructions below, we assume this directory to be the current working directory.
```
$ cd ./ansible-playbook-for-ohpc/
```

### Replace sample values in configuration files to suit your cluster

Please edit the following files:
1. inventory/hosts --- List the IP addresses or hostnames of the nodes, and their roles in the cluster.
1. group_vars/all.yml --- Various cluster-specific configurations go in here.

#### Replace sample values in inventory/hosts with actual values

The inventory/hosts file has four sections, *[sms]*,*[cnodes]*,*[ionodes]*,*[devnodes]*. For each section, list the IP addresses or hostnames of the applicable node or nodes.
For the *[sms]* section, that of SMS; for the *[cnodes]* section, those of CNs; for the *[ionodes]* section, those of I/O Nodes; and for the *[devnodes]* sections, those of DNs. _Note that these IP addresses and hostnames should be those assigned on the Management Network_.

Here is an example of inventory/hosts:
```
[sms]
192.168.33.11
[cnodes]
192.168.33.21
192.168.33.22
[ionodes]
192.168.33.11
[devnodes]
192.168.33.11
192.168.33.21
192.168.33.22
```

#### Modify group_vars/all.yml


The following are the configuration variables with their default values. You can set the values of any of these variables in this file to suit your cluster.

1. sms_name ... Hostname of SMS.
1. sms_ip ... IP address of SMS, assigned on the Computing Network, not on the Management Network
1. internal_network ... Network address of the Computing Network.
1. internal_broadcast ... Broadcast address of the Computing Network.
1. internal_gateway  ...  Gateway address of the Computing Network.
1. internal_domain_name .. Domain name of the Computing Network
1. internal_domain_name_servers .. Domain name servers of the Computing Network
1. domain_name ... Same as internal_domain_name.  IGNORED until we support XCAT
1. iso_path ... This variable is used by XCAT. IGNORED until we support XCAT
1. eth_provision .. the Ethernet device name used for provisioning in the Warewulf environment if one is used.


##### Optional flags for installations and configurations of related software packages, and other miscellaneous configurations

 - enable_beegfs_client: true/false (default: false)
   \[NOT SUPPORTED YET\] Uses BeeGFS if true.
 - enable_mpi_defaults: true/false  (default: true)
   Installs MPI libraries if true.
 - enable_mpi_opa:  true/false  (default: false)
   Installs MPI libraries specifically for Intel interconnect if true.
 - enable_clustershell:  true/false  (default: true)
   Installs clustershell if true
 - enable_ipmisol: true/false  (default: false)
   Installs ipmisol if true. The Warewulf environment needs this, but this variable is not automatically set true even if you choose to install the Warewulf environment; it needs to be manually set true.
 - enable_opensm: true/false  (default: false)
   Installs packages specifically for Intel's interconnect if true.
 - enable_ipoib: true/false  (default: false)
   \[Not fully tested; feedback welcome\] Sets up IP over IB if true.
 - enable_ganglia: true/false  (default: true)
   Installs ganglia packages if true.
 - enable_genders: true/false  (default: true)
    Installs genders packages if true.
 - enable_kargs: true/false  (default: false)
   Sets up kargs for TFTP boot kernels if true.
   Normally needs to be set true if the Warewulf environment is to be installed.
 - enable_lustre_client: true/false  (default: false)
   \[NOT SUPPORTED YET\] Uses Lustre if true.
 - enable_mrsh: true/false  (default: false)
   Installs mrsh packages if true.
 - enable_nagios: true/false  (default: true)
   Installs nagios packages.
 - enable_powerman: true/false  (default: false)
   Installs powerman packages if true. Normally needs to be set true if the Warewulf environment is to be installed.
 - enable_intel_packages: true/false  (default: false)
   Installs packages useful for the compiler included in Parallel Studio XE, informally known as "the Intel Compiler," if true.
 - enable_dhcpd_server: true/false  (default: false)
   Enables dhcpd on SMS for CNs if true. Must be set false if you use Warewulf or have already configured SMS to run dhcpd.
 - enable_ifup: true/false  (default: false)
   \[Not fully tested; feedback welcome\] Sets up Ethernet devices in the Computing Network if true. Must be set false if you have already set up Ethernet for CNs.
 - enable_warewulf: true/false  (default: false)
   Enables Warewulf if true.
 - enable_nfs_ohpc: true/false  (default: false)
   To export /opt/ohpc directory from SMS, set this variable true. Our playbook installs the OHPC packages into CNs, or, if Warewulf is to be installed, installs them into the chroot directories for CNs. So it should be false in typical cases.
 - enable_nfs_home: true/false  (default: true)
   To export `/home` directory from SMS, set this variable true.
   It would be advisable to set this *false* in the Linaro Lab because it is a diskful cluster and you would not want to overshadow the `/home` directory of a member node.
 - internal_default_lease_time
   default DHCP lease time.
 - internal_max_lease_time
   max DHCP lease time.
 - num_computes
   Number of CNs.
 - compute_regex and compute_prefix
   regex and prefix letters that match hostnames of CNs. They are used by Slurm.
 - compute_nodes
    Blindly ported from recipe.sh in OpenHPC. Refer to recipe.sh for its use. An array each of whose elements is an associative array that holds the following five kinds of information of a CN:
     * A unique number assigned to this CN (key: "num"),
     * The hostname of the CN (key: "c_name"),
     * The IP address of the CN (key: "c_ip"),
     * The MAC address of the CN (key: "c_mac"), and
     * The IP address of the BMC (key: "c_bmc").

     An example follows:




```
compute_nodes:
 - { num: 1, c_name: "c1", c_ip: "192.168.44.21", c_mac: "52:54:00:44:00:01", c_bmc: "192.168.66.11"}
 - { num: 2, c_name: "c2", c_ip: "192.168.44.22", c_mac: "52:54:00:44:00:02", c_bmc: "192.168.66.12"}
```
 - compute_ipoib
   \[Reserved; not currently used\] network settings for the IB network
 - beegfs_repo
   \[Reserved; not currently used\] BeeGFS-related settings

##### Other variables

Ansible provides a feature called Roles, which are a compartmentalization unit that allows for reuse across multiple playbooks (For details, see <https://docs.ansible.com/ansible/2.5/user_guide/playbooks_reuse_roles.html>).  With this playbook, role-specific settings can be specified in the following files.

1. roles/common/vars/main.yml

    - ohpc_release_rpm
      URL of an _ohpc-release_ package.
      Note: This option is to be moved to all.yml soon.

1. roles/ganglia/vars/main.yml

    - ganglia_grid_name
      Grid name used in Ganglia.

1. roles/ipmisol/vars/main.yml

    - bmc_username
      Login name for BMC

    - bmc_password
      Password for BMC

1. roles/lmod/vars/main.yml

    - ohpc_lmod_mpi_default
      Default module file referenced by Environment Module for MPI selection.

1. roles/lustre-client/vars/main.yml

    - mgs_fs_name
      \[NOT SUPPORTED YET\] mount point for Lustre MGS

1. roles/net-ib/vars/main.yml

    - ipoib_netmask
    - sms_ipoib
      These variables are here for the portability of roles. They might be moved to all.yml at some point in the future.

1. roles/ntp/vars/main.yml

    - ntp_server
      NTP server for the whole cluster

1. roles/warewulf/vars/main.yml

    - provision_wait
      Delay time to ensure completion of provisioning (unit: seconds)

    - compute_chroot
      Chroot OS version (Current: centos7.3)

    - compute_chroot_loc
      Location of chroot directory on SMS

    - kargs
      Sets up kargs for TFTP boot kernels

##  Run this playbook

Please execute the following command:
```
./scripts/run.sh
```
