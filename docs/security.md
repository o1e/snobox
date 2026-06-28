# Security Notes For Labs

SNObox is optimized for reproducible lab and development clusters. Several
defaults are intentionally convenient for ephemeral environments and should be
reviewed before use on shared or persistent infrastructure.

## Public Wildcard DNS

`dns_mode: public_wildcard` avoids local DNS by deriving the effective base
domain from the node IP and a public wildcard provider such as `sslip.io`.

Operational tradeoffs:

- RFC1918/private IP addresses become visible in public DNS queries.
- Cluster API, ingress and node names depend on the external wildcard DNS
  provider.
- Some routers or resolvers block DNS responses for private addresses as DNS
  rebinding protection.

Use `dns_mode: local` when the environment requires private DNS ownership or
does not allow public wildcard DNS resolution.

## Libvirt Provisioning User

The provisioning user is the effective Ansible SSH user configured on the KVM
host, for example `ansible_user: ansible_kvm` on the `kvm` inventory host.

SNObox expects this user to access `qemu:///system` without sudo and to manage
libvirt domains, networks and storage volumes. In labs this is commonly done by
adding the user to groups such as `libvirt` and, where required, `kvm`.

That group membership grants broad control over local virtual machines. Treat it
as an administrative permission and avoid granting it broadly on shared or
production hypervisors.

## SSH Host Key Checking

The repository disables strict SSH host key checking for lab convenience:

- `ansible.cfg` sets `host_key_checking = False`.
- `inventory/group_vars/all/ansible_ssh.yml` sets
  `StrictHostKeyChecking=no` and `UserKnownHostsFile=/dev/null`.

This reduces friction for ephemeral VMs and execution environments, but it also
removes host identity verification. For persistent environments, replace these
settings with normal known-hosts management.

## Generated Credentials

Generated state lives below:

```text
state/<cluster>.<domain>/
```

Credential-bearing files include:

- `SNOBOX-SUMMARY.txt`
- `ocp/auth/kubeconfig`
- `ocp/auth/kubeadmin-password`
- `ssh/id_<hostname>`

Keep the `state/` directory out of version control and restrict filesystem
access to operators who should administer the cluster.

## Pull Secret And Lab Users

OCP requires a Red Hat pull secret, expected by default at:

```text
.secrets/pull-secret.json
```

Do not commit pull secrets or vault passwords.

For lab and development use, a Red Hat Developer account is usually the right
starting point. Red Hat Developer membership can be used to create a Red Hat
login, which is then used for Red Hat services such as the Hybrid Cloud Console.

Useful Red Hat links:

- [Red Hat Developer](https://developers.redhat.com/)
- [Join Red Hat Developer](https://developers.redhat.com/register)
- [OpenShift pull secret](https://console.redhat.com/openshift/install/pull-secret)
- [Red Hat pull-secret documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/latest/html/images/managing-images#using-image-pull-secrets)

Place the downloaded pull secret at `.secrets/pull-secret.json`, or override
`sno_pullsecret_path` with an Ansible extra var.

The example htpasswd users are lab defaults. Replace placeholder passwords such
as `ChangeMe` before using the cluster for anything beyond a disposable lab.

## Upstream Documentation

Use the upstream product documentation for platform-specific behavior that is
outside SNObox's automation layer:

- [Red Hat OpenShift Container Platform documentation](https://docs.redhat.com/en/documentation/openshift_container_platform/)
- [OKD documentation](https://docs.okd.io/)
