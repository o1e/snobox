# Operational Commands

This page collects the commands most often used after the inventory has been
adapted for a local SNObox environment.

## Full Provisioning Run

Run the full ordered workflow:

```bash
ansible-navigator run playbooks/site.yml
```

This executes:

- `playbooks/10_sno_prep.yml`
- `playbooks/20_sno_build.yml`
- `playbooks/30_sno_conf.yml`

## Target One Instance

When multiple SNO instances exist in `inventory.yml`, use `--limit` to install
or re-run only one host:

```bash
ansible-navigator run playbooks/site.yml --limit pubbox1
```

The same pattern applies to every phase playbook:

```bash
ansible-navigator run playbooks/10_sno_prep.yml --limit pubbox1
ansible-navigator run playbooks/20_sno_build.yml --limit pubbox1
ansible-navigator run playbooks/30_sno_conf.yml --limit pubbox1
```

## Resume After VM Creation

`sno_build_vm` fails intentionally when a VM already exists. If the VM was
created successfully and only the install wait or post-install configuration
needs to continue, run the later phase or tag directly:

```bash
ansible-navigator run playbooks/20_sno_build.yml --limit <host> --tags sno_build_ocp_inst
ansible-navigator run playbooks/30_sno_conf.yml --limit <host>
```

Use this only when the VM and installer ISO were already created by an earlier
run.

## Summary File

After `sno_conf` completes, the cluster handover file is written to:

```text
state/<cluster>.<domain>/SNOBOX-SUMMARY.txt
```

Examples:

```text
state/snobox1.snobox1.example.org/SNOBOX-SUMMARY.txt
state/pubbox1.pubbox1.192-168-2-15.sslip.io/SNOBOX-SUMMARY.txt
```

The file contains the cluster FQDN, distribution/version, kubeconfig export,
console URL, kubeadmin login, API login command, SSH command and configured
users. It contains credentials and should be treated as a secret.

## Kubeconfig

The generated kubeconfig is stored under the per-cluster state directory:

```bash
export KUBECONFIG=state/<cluster>.<domain>/ocp/auth/kubeconfig
```

The exact command is also written to `SNOBOX-SUMMARY.txt`.

## SSH Access

SNObox generates a per-cluster SSH key and writes the matching command to the
summary file.

Generic form:

```bash
ssh -i state/<cluster>.<domain>/ssh/id_<hostname> core@<node-fqdn>
```

Example:

```bash
ssh -i state/pubbox1.pubbox1.192-168-2-15.sslip.io/ssh/id_pubbox1 core@pubbox1.pubbox1.192-168-2-15.sslip.io
```

## Cleanup And Recreate

Clean VM removal is intentionally not hidden behind a normal provisioning run.
If a lab VM must be recreated, remove the libvirt domain and its storage on the
KVM host, then re-run the playbook.

Example command shape:

```bash
virsh -c "<sno_libvirt_uri>" destroy "<node-fqdn>"
virsh -c "<sno_libvirt_uri>" undefine --remove-all-storage "<node-fqdn>"
```

Verify the target domain and libvirt URI before running cleanup commands. They
are destructive.

Depending on why the cluster is recreated, also remove the matching local state
directory before the next full provisioning run:

```bash
rm -rf state/<cluster>.<domain>/
```

This removes generated install assets, kubeconfig, kubeadmin password, SSH keys
and `SNOBOX-SUMMARY.txt` for that cluster. Keep the directory when you only
want to inspect a failed run or resume a later phase with the existing generated
artifacts.

## Inspect Playbook Structure

Use Ansible's list modes before a focused run when you need to confirm tags or
task order:

```bash
ansible-navigator run playbooks/site.yml --list-tags
ansible-navigator run playbooks/site.yml --list-tasks
```

## Static Checks

The repository provides a `Makefile` for lint and static validation. The Ansible
commands run through `ansible-navigator exec`, so they use the configured
execution environment instead of host-installed collections.

Run all checks:

```bash
make lint
```

Individual targets:

```bash
make check
make lint-ansible
make syntax
make inventory
make tasks
make examples
```

`make examples` validates that the copyable example inventory can render host
variables for `snobox1`, `natbox1` and `pubbox1`.
