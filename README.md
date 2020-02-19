# a4amp
Ansible4AMP is a collection of Ansible playbooks and other scripts for deploying and managing a set of AMP ([Active Measurement Project](https://github.com/wanduow/amplet2)) probes.

## Requirements
### Environment
a4amp is designed for an environment with a number of AMP nodes in the field (probes) testing towards the internet, and some nodes which are targets for probe throughput and latency tests (endpoints). Specifically:
* probes
  * must be in a mesh called `probes`
  * may be behind NAT, but must be able to SSH to the server to set up a reverse SSH tunnel
  * probes are numbered from 000-999, and set up local SSH tunnels on ports 2000-2999
  * the description field must follow the format `<hardware>;<owner>;<site>;<test endpoint>;`
* endpoints
  * must be in a mesh starting with `endpoints`
  * should have a pubic IP and DNS record (must be reachable from all probes)
  * the description field must follow the format `<hardware>;<owner>;<site>; ;<static IP details>`

### Server
Server must have Ansible installed (tested with v2.8). Tested with Ubuntu 18.04.

### Probes
Tested with:
* Ubuntu 16.04 aarch64
* Ubuntu 16.04 x86_64
* Ubuntu 18.04 x86_64
* Ubuntu 14.04 armv7l

## Installation
### Install scripts
Clone the repository:
```
git clone https://github.com/vfnz-quality/a4amp.git
````
Rename the YAML files in `a4amp/ansible/vars` (remove `.example` from the end), and edit as appropriate

### Set up main user
The user managing the probes will need sudo rights to the following:
* `/bin/ss` - identifying connected probes
* `/usr/sbin/ampca` - updating AMPCA keys
* `/bin/cp <keyDir>/authorized_keys /home/tunnel/.ssh/authorized_keys` - setting up SSH tunnel keys

Example `/etc/sudoers`:
```
<user>    ALL=(ALL) NOPASSWD: /bin/ss, /usr/sbin/ampca, /bin/cp <keyDir>/authorized_keys /home/tunnel/.ssh/authorized_keys
```

### Set up SSH tunnel management
Create a user called `tunnel` that isn't able to login:
```
sudo useradd tunnel -m -s /usr/sbin/nologin
```
and create a ```.ssh``` folder (to store the authorised keys):
```
sudo -u tunnel mkdir -m 0700 /home/tunnel/.ssh
```

For other users, add some SSH config (to `~/.ssh/config`):
```
UserKnownHostsFile ~/.ssh/known_hosts <keyDir>/known_hosts

# create aliases to the probes
Host 800
    Hostname localhost
    Port 2800
Host 801
    Hostname localhost
    Port 2801
Host 802
    Hostname localhost
    Port 2802
</snip>
```

### AMP certificates
Copy the AMP CA cert from `/etc/amppki/cacert.pem` to `<keyDir>/<serverFQDN>.pem`

### Packages
Custom packages have been built and need to be hosted somewhere the probes can access. The built .deb files are in the `packages` folder, and the URL to host them at is set in `main.yml`, with the task itself in `packages.yml`. The following packages have been built:
* iperf3_3.6
* ndt_3.7.0

### Failsafe
A probe failsafe is implemented in case the main server is lost. See `main.yml` for an example.

### Endpoint stats
Endpoint OS stats are sent to an InfluxDB instance, which can be the same as that used for the AMP measurements. Set server and credentials (if used) in `main.yml`.

## Usage

### Scripts
Scripts are in the `a4amp/scripts` folder. Once installed, a probe or endpoint can be built by running `build.sh <probeID>`, tests scheduled by running `schedule.py`, and connected probes checked by running `probes.py`. The complete list of scripts includes:

* `amplet.sh` - start/stop the AMP service on chosen probes
* `build.sh` - deploy packages and configuration to a chosen probe. It is intended to be run once since it will rotate the SSH keys, so the corresponding playbook (`build.yml`) should be run as a regular task.
* `capture.sh` - get a packet capture from a probe and endpoint, and upload to the management server
* `cmd.sh` - shortcut to run a command on one or more probes
* `localFW.sh` - apply the firewall rules used on the endpoints to the management server
* `probelog.sh` - keep track of probe connections and disconnections
* `probes.py` - show connected probes, or update the list from the AMP database
* `schedule.py` - deploy the AMP test schedule to the probes, or review it to check for conflicts
* `speedtest.sh` - run a selection of different speedtests against a chosen probe

### Playbooks
All playbooks are in the `a4amp/ansible` folder. Two playbooks provide the main functions.
* `build.yml` - deploy packages and configuration to a chosen probe
* `pushSchedule.yml` - used by the `schedule.py` script

Other playbooks are included for convenience:
* `localFW.yml` - apply the same firewall rules used on the endpoints to the management server
* `ndt.yml` - run an [NDT](https://www.measurementlab.net/tests/ndt/) speedtest
* `tcpdump.yml` - get a packet capture from a probe and endpoint, and upload to the management server
* `updatePackages.yml` - update AMP or all packages on probes/endpoints
* `vlan10.yml` - add/remove a second interface with VLAN10 configured, to allow connection directly to a UFB ONT or HFC cable modem.
