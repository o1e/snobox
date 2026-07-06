# Inventory Model

The inventory defines the full declarative configuration of SNObox.

It describes:

- infrastructure topology
- cluster identity
- network configuration
- sizing

The inventory is the single source of truth for provisioning and configuration.

---

## Naming and DNS Convention

All systems follow a consistent naming pattern:

`<hostname>.<clustername>.<base_domain>`

Example:

snobox1.snobox1.example.org

This naming is used consistently across:

- hostnames
- API endpoints
- ingress routes
- generated configuration

With `dns_mode: public_wildcard`, the effective base domain is derived from the
configured node IP and public wildcard DNS provider. In that mode, no local DNS
server is required for the generated API, ingress and node names.

For multi-cluster labs, keep `sno_box.clustername` unique. The repository
examples use the inventory host name as the cluster name so API, apps, console
and state paths remain self-identifying, for example
`apps.pubbox1.192-168-2-15.sslip.io` instead of
`apps.pubbox.192-168-2-15.sslip.io`.

Static NetworkManager profiles keep the connection hostname short, persist the
node FQDN through `/etc/hostname`, and write a static `/etc/resolv.conf`.
NetworkManager DNS updates are disabled for those profiles so the cluster base
domain is not derived as a resolver search domain. With wildcard providers such
as `sslip.io`, that derived search domain would make external names like
`quay.io.<base_domain>` resolve back to the node IP.

---

## Structure

```text
inventory.yml
inventory_example.yml
group_vars/
host_vars/
  snobox1_example/
  natbox1_example/
  pubbox1_example/
```

### Layers

1. topology → `inventory.yml`
2. shared defaults → `group_vars/snobox/`
3. cluster config → `host_vars/<host>/`

The `*_example` files are intended for repository documentation and as copy templates for new deployments. Local files such as `inventory.yml`, `host_vars/snobox1/`, `host_vars/natbox1/`, and `host_vars/pubbox1/` may contain site-specific values and should be adapted locally.

---

## Topology (`inventory.yml`)

Defines infrastructure relationships:

- `kvm_hosts` → libvirt/KVM hypervisors
- `snobox` → all managed SNO clusters

Each SNO host must define `sno_kvm_host`. The repository example is provided in `inventory/inventory_example.yml`:

```yaml
snobox:
  hosts:
    snobox1:
      sno_kvm_host: kvm

    natbox1:
      sno_kvm_host: kvm
```

### Required fields

| Field | Purpose |
|--------|--------|
| `sno_kvm_host` | hypervisor used for provisioning |

`sno_kvm_host` links the VM to the libvirt host used during provisioning.

---

## Cluster Model (`host_vars`)

Each cluster is defined using host-specific variable files:

```text
host_vars/<host>/sno_box.yml
host_vars/<host>/sno_net.yml
host_vars/<host>/sno_lvms.yml      # optional / only needed when overriding LVMS defaults
```

Repository examples:

```text
host_vars/snobox1_example/sno_box.yml
host_vars/snobox1_example/sno_net.yml
host_vars/snobox1_example/sno_lvms.yml
host_vars/natbox1_example/sno_box.yml
host_vars/natbox1_example/sno_net.yml
```
The repository examples model `snobox1` as an OCP cluster with bridged local DNS, `natbox1` as a libvirt NAT lab cluster, and `pubbox1` as a bridged public-wildcard DNS cluster.

---

## Cluster Identity (`sno_box.yml`)

Minimal example, based on `host_vars/snobox1_example/sno_box.yml`:

```yaml
sno_box:
  hostname: snobox1
  clustername: snobox1
  base_domain: example.org
  distribution: ocp
  ocp:
    version: stable-4.21
  okd:
    version: 4.22.0-okd-scos.ec.9
  specs:
    vcpu: 8
    mem: 32768
```

### Key Fields

| Field | Purpose |
|--------|--------|
| `distribution` | selected distribution (`ocp` or `okd`) |
| `ocp.version` | OpenShift release or update channel |
| `okd.version` | exact OKD release tag |
| `hostname` | VM hostname |
| `clustername` | cluster identifier |
| `base_domain` | DNS base domain |
| `specs.vcpu` | VM vCPU count |
| `specs.mem` | VM memory in MiB |

These values drive:

- VM provisioning
- DNS/FQDN construction
- install-config generation
- installer and client downloads
- certificate path resolution

---

## Network Model (`sno_net.yml`)

Networking is host-specific and part of the minimum configuration.

Supported modes:

- `nat`
- `bridge`

The selected type determines which configuration is used during provisioning and for generated OpenShift configuration.

### Network behavior (bridge vs nat, dhcp vs static)

The network configuration separates two concerns:

1. **Attachment type (host side)**
   - `bridge`: VM is attached to an existing host bridge (e.g. `br0`)
   - `nat`: VM is attached to a libvirt NAT network

2. **IP configuration (guest side)**

   **Bridge**
   - `mode: dhcp` → IP is assigned by an external DHCP server
   - `mode: static` → IP is injected into the RHCOS ISO via a NetworkManager keyfile

   **NAT**
   - Always uses DHCP
   - The configured `nat.ip` is enforced via **libvirt DHCP reservation**

Important notes:

- `virt-install` does NOT configure the guest IP
- Bridge networks do NOT assign IPs by themselves
- Static IPs only work via ISO customization (NetworkManager keyfile)
- NAT IPs are not truly static — they are DHCP reservations bound to the MAC

### Example Network Modes

The repository examples intentionally cover both supported network modes:

| Host | Example path | Network mode |
|------|--------------|--------------|
| `snobox1` | `host_vars/snobox1_example/sno_net.yml` | `bridge/static` |
| `natbox1` | `host_vars/natbox1_example/sno_net.yml` | `nat` |
| `pubbox1` | `host_vars/pubbox1_example/sno_net.yml` | `bridge/static` |

For bridged networking, only the `bridge:` configuration needs to be active. The `nat:` block may be kept commented as a template.

For NAT networking, only the `nat:` configuration needs to be active. The `bridge:` block may be kept commented as a template.

### Bridge IP assignment

A libvirt bridge attachment only connects the VM NIC to an existing host bridge such as `br0`; it does not assign an IP address inside the guest. SNObox therefore supports two intended bridge addressing modes:

| Mode | Behavior | When to use |
|------|----------|-------------|
| `mode: dhcp` | The VM boots on the bridge and receives its address from the external LAN DHCP service. Use `sno_net.mac` for a DHCP reservation. | Existing LAN DHCP should own address management. |
| `mode: static` | The static address, gateway and DNS settings from `sno_net.bridge.specs.static` are embedded into the RHCOS live ISO as a NetworkManager profile. | No DHCP reservation is available or the node should be self-contained. |

Bridge mode is required and must be either `dhcp` or `static`.

#### Minimal bridge example with external DHCP reservation:

```yaml
sno_net:
  type: bridge
  mac: "de:ad:be:ef:02:74"

  bridge:
    virt_dev: br0
    cidr: 192.168.2.0/24

    mode: dhcp   # dhcp | static

    specs:
      dhcp: {}
```

#### Minimal bridge example with static guest configuration:

```yaml
sno_net:
  type: bridge
  mac: "de:ad:be:ef:02:74"

  bridge:
    virt_dev: br0
    cidr: 192.168.2.0/24

    mode: static   # dhcp | static

    specs:
      static:
        ip: 192.168.2.116
        prefix: 24
        gw: 192.168.2.1
        dns:
          - 192.168.2.1
      dhcp: {}
```

For static bridge mode, `prefix` is preferred for the guest NetworkManager profile. `cidr` remains the OpenShift `machineNetwork`.

#### Minimal NAT example

```yaml
sno_net:
  type: nat
  mac: "de:ad:be:ef:64:0a"

  nat:
    network: snobox-net
    ip: 192.168.100.10
    cidr: 192.168.100.0/24
    create_net: true
    gateway: 192.168.100.1
    netmask: 255.255.255.0
    dhcp_start: 192.168.100.50
    dhcp_end: 192.168.100.200
```

Notes:

- The VM always uses DHCP inside the NAT network
- The configured ip is enforced via libvirt DHCP reservation (virsh net-update)
- The MAC address must match the reservation
- Although the IP appears static, it is DHCP-based

---

## Shared Configuration (`group_vars/snobox`)

### Paths

`group_vars/snobox/sno_paths.yml`

Defines runtime directory layout:

- `sno_repo_root` → repository root
- `sno_state_root` → runtime state directory
- `sno_workdir` → per-cluster working directory
- `sno_workdirs.*` → structured subdirectories

The final handover summary is written to:

```text
state/<cluster>.<domain>/SNOBOX-SUMMARY.txt
```

It contains the kubeconfig path, kubeadmin login information, API login command,
SSH command and configured users. Treat this file as credential-bearing runtime
state.

---

### Downloads

`group_vars/snobox/sno_urls.yml`

Defines sources for:

- OpenShift / OKD installer
- `oc` client
- CoreOS installer

Values are derived dynamically from:

- `sno_box.distribution`
- `sno_box.ocp.version`
- `sno_box.okd.version`

---

### OpenShift Networking Defaults

`group_vars/snobox/sno_ocp_net.yml`

Defines shared SDN defaults:

- `network_type`
- `cluster_network`
- `service_network`
- `machine_network`

`machine_network` is derived dynamically from the active network configuration:

- `sno_net.bridge.cidr` when `type: bridge`
- `sno_net.nat.cidr` when `type: nat`

It must match the subnet of the SNO node IP.

Example:
- Node IP: `192.168.2.116`
- CIDR: `192.168.2.0/24`

---

### Storage

`group_vars/snobox/sno_storage.yml`

Defines the default VM disk layout:

- storage pool
- installer ISO volume format
- system disk
- optional data disks

The installer ISO is uploaded into the configured libvirt storage pool as a
volume. SNObox does not require direct write access to `/var/lib/libvirt` on
the KVM host.

`data_disks` only controls which additional virtual disks are attached to the
VM. It does not decide what those disks are used for.

May be overridden per host if required.

---

### LVMS

`group_vars/snobox/sno_lvms.yml`

Defines the default LVMS behavior:

- LVMS is disabled by default
- default volume group / device class name
- whether the LVMS StorageClass should become default
- selected disk `name_suffixes`

LVMS usage is host-specific. Enable it in `host_vars/<host>/sno_lvms.yml` only for OCP or OKD hosts that should use LVMS.

Example:

```yaml
sno_lvms:
  enabled: true
  set_default_sc: true
  vg_name: vg-lvms
  disks:
    name_suffixes:
      - lvms1-1
      - lvms1-2
```

The values under `sno_lvms.disks.name_suffixes` must match entries from `sno_storage.data_disks`.

Example:

```yaml
sno_storage:
  data_disks:
    - name_suffix: localstorage1-1
      size: 15
    - name_suffix: lvms1-1
      size: 75
    - name_suffix: lvms1-2
      size: 75
```

Only the selected LVMS suffixes are passed to the LVMS Operator. Other attached data disks remain available for other use cases.

Important:

- LVMS is optional and disabled by default.
- For OKD, SNObox uses the documented LVM Storage Operator path from
  OperatorHub and installs it into `openshift-lvm-storage` by default.
- OKD with LVMS needs valid `registry.redhat.io` credentials because the
  default `lvms-operator` source is the Red Hat Operator catalog. A fake OKD
  pull secret is not sufficient for this feature.
- For OCP, SNObox keeps the existing default namespace `openshift-storage`.
- Operator settings can be overridden under `sno_lvms.operator`.

---

### TLS

`group_vars/snobox/sno_certs.yml`

Defines optional wildcard ingress certificate paths:

```
files/certs/apps.<cluster>.<base_domain>/
```

Applied only if both cert and key exist locally.

---

### Users

`group_vars/snobox/sno_users.yml`

Optional htpasswd-based authentication configuration:

- secret name
- users
- cluster roles

The default inventory creates these lab users:

- `admin` with `cluster-admin`
- `cluster-status` with `cluster-status`
- `developer` with `admin`

The example password is `ChangeMe`. Replace it before using the inventory
outside a disposable lab.

---

### OperatorHub

`roles/sno_conf/defaults/main.yml`

For OKD, SNObox disables the default OperatorHub catalog sources by default
unless LVMS is enabled. The OKD example does not use a Red Hat pull secret, and
the default catalogs otherwise leave pods in `ImagePullBackOff` against
`registry.redhat.io`.

When LVMS is enabled on OKD, default sources stay enabled because LVM Storage is
installed from OperatorHub. In that mode, provide valid `registry.redhat.io`
credentials in the global pull secret or override
`sno_lvms.operator.catalog_source` and `sno_lvms.operator.catalog_namespace` to
an alternate catalog that provides `lvms-operator`.

Override `sno_conf_operatorhub.disable_all_default_sources` when you want to
manage the OperatorHub source state explicitly.

---

### Pull Secret

`group_vars/snobox/sno_pullsecret.yml`

Defines default pull-secret location:

```
.secrets/pull-secret.json
```

Can be overridden via CLI extra vars.

Notes:

- OCP requires a valid pull secret.
- OKD itself does not require a Red Hat pull secret.
- For OKD without Red Hat catalog features, a valid dummy pull secret is used
  internally.
- OKD LVMS requires valid `registry.redhat.io` credentials unless the LVMS
  Operator catalog is overridden.
- When `.secrets/pull-secret.json` exists for an OKD host, SNObox uses it in
  `install-config.yaml`; otherwise it falls back to the dummy pull secret when
  no enabled feature requires Red Hat registry access.

---

## Using the Example Inventory

To start from the repository examples, copy the example files to the local inventory names and adapt them to your environment:

```bash
cp inventory/inventory_example.yml inventory/inventory.yml
cp -r inventory/host_vars/snobox1_example inventory/host_vars/snobox1
cp -r inventory/host_vars/natbox1_example inventory/host_vars/natbox1
cp -r inventory/host_vars/pubbox1_example inventory/host_vars/pubbox1
```

Then update DNS names, IP addresses, bridge device names, and the base domain as required. For bridged networking, also decide whether the address is provided by external DHCP reservation (`mode: dhcp`) or embedded as static guest configuration (`mode: static`).

The copied `host_vars/<host>/sno_lvms.yml` can be used to enable LVMS for OCP
or OKD hosts and to select which `data_disks` LVMS may consume.

The example FQDNs are based on `example.org` and should be replaced for real deployments.

---

## Design Principles

The inventory model follows these rules:

- declarative over procedural
- derive values instead of duplicating them
- keep shared defaults in group_vars
- keep cluster-specific values in host_vars
- keep minimum configuration small and explicit

---

## Notes

- `example.org` is used as placeholder domain.
- Replace it with your own domain before deployment.
