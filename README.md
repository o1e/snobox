# SNObox

SNObox provisions **Single Node OpenShift** labs on libvirt/KVM with Ansible.
It is built for repeatable local and homelab installs where one VM should become
a usable OCP or OKD cluster with a generated handover summary.

The name is literal: **SNO in a box**. Inventory describes the cluster, Ansible
prepares the installer assets, libvirt creates the VM, and post-install roles
configure useful lab defaults. Depending on the selected DNS mode, SNObox can
run without local DNS by resolving API, ingress and node names through public
wildcard DNS such as `sslip.io`.

## Features

- OpenShift Container Platform (OCP) and OKD support
- libvirt/KVM VM provisioning with bridge or NAT networking
- local DNS or public wildcard DNS modes
- static bridge networking, DHCP reservation workflows and libvirt NAT DHCP
  reservations
- optional LVMS setup for OCP labs
- generated kubeconfig, login and SSH handover file
- Ansible Execution Environment friendly workflow through `ansible-navigator`
- focused inventory examples for local, NAT and public wildcard DNS labs

SNObox is intended for labs and development environments. It is not a production
OpenShift installer or security hardening framework.

## How It Works

SNObox uses a small set of ordered playbooks:

| Phase | Playbook | Purpose |
|---|---|---|
| Prepare | `playbooks/10_sno_prep.yml` | create workdirs, keys, install-config, ignition and ISO assets |
| Build | `playbooks/20_sno_build.yml` | validate networking, upload ISO, create/start the VM and wait for install |
| Configure | `playbooks/30_sno_conf.yml` | configure OAuth users, certificates, OperatorHub and optional LVMS |
| Full run | `playbooks/site.yml` | run all phases in order |

Inventory is the public configuration API. Host vars define the cluster identity,
network mode and optional storage choices; group vars define shared defaults.
See [inventory/README.md](inventory/README.md) for the full model.

## Requirements

### Controller

- Ansible, preferably through `ansible-navigator`
- access to the configured Ansible Execution Environment
- SSH key available to reach the KVM host as the inventory `ansible_user`
- for OCP: a Red Hat pull secret at `.secrets/pull-secret.json` or an override
  through `sno_pullsecret_path`

### KVM Host

- Debian or another Linux host with KVM and libvirt
- a libvirt storage pool available to the provisioning user
- the provisioning user can access `qemu:///system` without sudo
- the provisioning user can manage libvirt domains, networks and storage volumes
- for bridge mode: an existing bridge device such as `br0`

The provisioning user is the Ansible SSH user configured on the KVM host in
inventory, for example:

```yaml
kvm_hosts:
  hosts:
    kvm:
      ansible_host: host.containers.internal
      ansible_user: ansible_kvm
```

In lab environments this is commonly implemented through `libvirt` group
membership and, where required, `kvm`. This grants broad VM control; see
[docs/security.md](docs/security.md) before using it on shared systems.

### VM Sizing

OpenShift SNO is resource hungry. The example profiles use lab-oriented sizing:

| Resource | Typical minimum |
|---|---:|
| vCPU | 8 |
| Memory | 24 GiB |
| System disk | 120 GiB or more |
| Additional data disk | optional, required for useful LVMS testing |

For recent OCP versions with LVMS enabled, 32 GiB memory is a more practical
starting point.

## Quickstart

### 1. Choose An Example

| Example | Network | DNS | Typical use |
|---|---|---|---|
| `snobox1_example` | bridge/static | local | existing local DNS |
| `natbox1_example` | libvirt NAT | public wildcard | isolated KVM lab |
| `pubbox1_example` | bridge/static | public wildcard | LAN VM without local DNS |

### 2. Create Local Inventory

```bash
cp inventory/inventory_example.yml inventory/inventory.yml

cp -r inventory/host_vars/snobox1_example inventory/host_vars/snobox1
cp -r inventory/host_vars/natbox1_example inventory/host_vars/natbox1
cp -r inventory/host_vars/pubbox1_example inventory/host_vars/pubbox1
```

Then edit the copied files for your host:

- `inventory/inventory.yml`: KVM host address and `ansible_user`
- `inventory/host_vars/<host>/sno_box.yml`: cluster name, OCP/OKD
  distribution, version and VM size
- `inventory/host_vars/<host>/sno_net.yml`: bridge/NAT, IPs and DNS mode
- `inventory/host_vars/<host>/sno_lvms.yml`: optional LVMS settings

Choose OCP or OKD and set the release in `sno_box.yml`:

```yaml
sno_box:
  distribution: ocp
  ocp:
    version: stable-4.21
```

```yaml
sno_box:
  distribution: okd
  okd:
    version: 5.0.0-okd-scos.ec.0
```

For OCP, place your pull secret here:

```bash
mkdir -p .secrets
cp ~/Downloads/pull-secret.json .secrets/pull-secret.json
```

OKD does not require a Red Hat pull secret.

### 3. Run Provisioning

Full run:

```bash
ansible-navigator run playbooks/site.yml
```

Single host:

```bash
ansible-navigator run playbooks/site.yml --limit pubbox1
```

Phase-only runs, cleanup and resume commands are documented in
[docs/operations.md](docs/operations.md).

### 4. Read The Summary

After a successful run, SNObox writes the cluster handover file:

```text
state/<cluster>.<domain>/SNOBOX-SUMMARY.txt
```

It contains the kubeconfig path, console URL, kubeadmin login, API login command,
SSH command and configured htpasswd users. Treat this file like a secret.

## Common Commands

```bash
# Static checks
make lint

# Syntax only
make syntax

# Inspect inventory
make inventory

# Targeted provisioning
ansible-navigator run playbooks/site.yml --limit natbox1

# Resume after VM creation
ansible-navigator run playbooks/20_sno_build.yml --limit <host> --tags sno_build_ocp_inst
ansible-navigator run playbooks/30_sno_conf.yml --limit <host>
```

## Documentation

| Path | Purpose |
|---|---|
| [inventory/README.md](inventory/README.md) | inventory model, DNS modes, networking, storage and users |
| [docs/operations.md](docs/operations.md) | full runs, targeted runs, resume, cleanup and access commands |
| [docs/security.md](docs/security.md) | lab security notes, pull secrets, generated credentials and libvirt access |
| [AGENTS.md](AGENTS.md) | repository and Ansible style rules for contributors and agents |

Upstream documentation:

- [Red Hat OpenShift Container Platform](https://docs.redhat.com/en/documentation/openshift_container_platform/)
- [OKD](https://docs.okd.io/)
- [Red Hat Developer](https://developers.redhat.com/) account, free for lab use
- [Red Hat pull secret](https://console.redhat.com/openshift/install/pull-secret)

## Repository Layout

```text
inventory/        inventory, examples and configuration defaults
playbooks/        execution entry points
roles/            implementation roles
docs/             operator and security documentation
state/            generated runtime artifacts, ignored by git
```

## License

MIT License.
