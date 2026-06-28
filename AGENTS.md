# Ansible Repository Agent Instructions

Copy this file to the root of a new Ansible repository and adapt platform,
ownership, inventory-group, validator, and runtime-test details. It defines a
reusable architecture for repositories that manage different infrastructure
while retaining the same role, inventory, validation, testing, and operational
model.

## Purpose

Build automation that is:

- explicit about ownership and execution order;
- idempotent and safely rerunnable;
- configured through a small public inventory interface;
- split into isolated roles with stable interfaces;
- validated before replacing working configuration;
- testable through predictable playbooks and tags;
- documented as an operator-facing product.

Configuration describes what should exist. Roles implement how it is created.
Playbooks define when roles run. Runtime state and generated artifacts remain
outside source configuration.

## Working Agreement

- Read the relevant repository files before proposing architecture or editing.
- Implement actionable fix requests end to end unless the user asks only for a
  plan, explanation, or review.
- When the user asks for a concept or design before implementation, make no
  file changes until approval.
- Preserve unrelated worktree changes.
- Do not edit vendored, generated, archived, example-reference, or migration
  material unless the request explicitly targets it.
- Keep changes and commits narrowly scoped.
- Verify version-sensitive commands against installed help/man pages or
  official documentation.
- Never encode a guessed CLI option into a validator, migration, or destructive
  task.

Before designing or editing an Ansible repository, perform an architecture
preflight:

1. Identify the managed-object inventory group and any infrastructure groups
   those objects reference.
2. Classify every configurable value as project-wide, group-specific, or
   host-specific, and place it in the matching inventory layer.
3. List execution phases and their dependency order before naming playbooks.
4. Assign one owning role to every executable concern, including preparation,
   validation, transfer, configuration, and lifecycle.
5. Define the explicit inventory-to-role variable mapping for each role.

Do not start implementation with a single host, single role, or large defaults
object and postpone this classification. The initial structure must already
support the repository's declared managed-object model.

## Recommended Layout

```text
ansible.cfg
inventory/
  inventory.yml
  group_vars/
    all/
      <topic>.yml
    <group>/
      connection.yml
      <group-specific-topic>.yml
  host_vars/
    <host>/
      <identity>.yml
      <host-specific-topic>.yml
playbooks/
  site.yml
  10_<phase>.yml
  20_<phase>.yml
roles/
  <role>/
    defaults/main.yml
    handlers/main.yml
    tasks/main.yml
    tasks/<role>_<area>.yml
    templates/
    files/
docs/
README.md
AGENTS.md
Makefile
.ansible-lint.yml
```

Create only directories that are needed. Do not generate empty Galaxy role
scaffolding for decoration.

This layout is architectural, not merely illustrative:

- inventory owns all project and environment configuration, including values
  commonly called "defaults";
- playbooks own orchestration and role wiring;
- roles own executable implementation;
- role defaults document the role-local input contract and may provide
  genuinely role-specific reusable behavior defaults, but must not become a
  second repository configuration layer.

## Layering

### Inventory

Inventory is the public configuration API and the single source of truth for
project behavior. Repository function defaults belong under `group_vars`;
role defaults may provide role-specific behavior defaults, but not repository
function defaults or environment policy.

- `inventory.yml` defines topology: groups, managed objects, connection
  endpoints, and explicit relationships such as a VM referencing its
  hypervisor.
- `group_vars/all/` contains defaults for repository functions that apply to
  all managed objects, split into cohesive topic files such as networking,
  storage, paths, images, users, and connection policy.
- `group_vars/<group>/` contains defaults for repository functions that apply
  only to that logical functional inventory group, likewise split into
  thematic files.
- Use group-specific defaults when the inventory has multiple logical
  functional groups with different behavior or policy. Do not force such
  values into `group_vars/all/`.
- Host variables contain node identity, addresses, priorities, placement, and
  per-node overrides.
- Connection variables are kept separate from feature configuration.
- Prefer structured objects over many loose variables.
- Expose intent, not implementation steps.
- Use one small identity/sizing object per managed host where the repository
  manages multiple similar instances. Keep topology references such as
  `<object>_kvm_host` in inventory rather than hard-coding a single execution
  target into a play or role.
- Provide copyable example host definitions when operators are expected to add
  more instances.

Values that operators may reasonably change between environments, functional
groups, or managed instances belong in inventory, even when every current host
uses the same value. Place shared function defaults in `group_vars/all/`,
functional-group defaults in `group_vars/<group>/`, and instance differences
in `host_vars/<host>/`. Do not place image URLs, package lists, network ranges,
storage paths, VM sizing, usernames, or similar repository policy in role
defaults unless the role is deliberately generic and the value is intrinsic
to that reusable role rather than this repository's environment.

Good:

```yaml
application_cluster:
  mode: active_passive
  virtual_address: 192.0.2.10
```

Avoid:

```yaml
run_start_script: true
write_override_file: true
```

### Playbooks

`playbooks/site.yml` is orchestration only. It statically imports feature
or phase playbooks in dependency order. Use ordered filenames when execution
order matters, for example `10_prepare.yml`, `20_build.yml`, and
`30_configure.yml`.

Each feature playbook:

- targets one inventory group;
- maps inventory variables to explicit role-local variables;
- imports owning roles in the required order;
- owns a stable top-level tag.

Example:

```yaml
- name: Configure application
  hosts: application
  tags:
    - application
  tasks:
    - name: Run application role
      ansible.builtin.import_role:
        name: application
      vars:
        application_config:
          cluster: "{{ application_cluster }}"
          node: "{{ application_node }}"
```

Playbooks may contain only orchestration concerns:

- plays, target groups, ordering, serial strategy, and top-level tags;
- static role imports and explicit inventory-to-role variable mapping;
- dependency hand-off between roles when that hand-off cannot belong to either
  role.

Do not put resource-management tasks such as `package`, `file`, `copy`,
`template`, `service`, `command`, cloud API calls, or libvirt operations
directly in `site.yml` or feature/phase playbooks. Put those tasks in an owning
role. A transfer, validation, or preparation step is implementation, not
orchestration, and therefore normally requires a role task file.

### Roles

Each role owns one responsibility. Roles do not consume project-global
variables directly.

`tasks/main.yml` is only a static dispatcher. It must not accumulate the
implementation merely because the role is currently small:

```yaml
- name: Install application
  ansible.builtin.import_tasks: application_install.yml
  become: true
  tags:
    - application_install

- name: Configure application
  ansible.builtin.import_tasks: application_config.yml
  become: true
  tags:
    - application_config

- name: Manage application service
  ansible.builtin.import_tasks: application_service.yml
  become: true
  tags:
    - application_service
```

Rules:

- Task filenames are prefixed with the role name.
- Tags match task filenames without `.yml`.
- Split by feature or operational phase, not module type.
- Prefer static imports and fully qualified collection names.
- Avoid deeply nested include chains.
- Put executable tasks in `tasks/<role>_<area>.yml`, including validation,
  transfer, artifact preparation, configuration, and lifecycle management.
- Keep `tasks/main.yml` readable as an execution outline.
- If a playbook contains several executable tasks around a role import, that
  is a signal that an ownership role or an additional role is missing.

## Role Interface Contract

Every role receives explicit role-local variables:

```yaml
application_config:
  cluster: ...
  node: ...
```

Inside the role:

- validate inputs before changes;
- treat inputs as immutable;
- derive private values into short `_...` temp variables such as `_tmp`,
  `_url`, `_net`, or `_secret`;
- do not mutate group or host variables;
- do not read project-global inventory variables directly;
- keep `defaults/main.yml` limited to the role-local interface and genuinely
  role-specific reusable defaults;
- keep implementation constants private unless users genuinely need to
  configure them.

### Temporary Variables

Use short leading-underscore names for task-local registers and facts.
Prefer names that describe the immediate purpose, not the role. Examples:
`_install_complete`, `_htpasswd_tmp`, `_rhcos_iso_url`.

Use role-prefixed names only for public role inputs, reusable role outputs,
and other values that are part of the role interface.

Secrets and other sensitive values should be handled with `no_log: true` when
they cross task boundaries, and example values in inventory or docs must be
obviously fake or synthetic.

`defaults/main.yml` documents the role interface and may provide sensible
defaults for behavior owned by the role itself. Examples include a role-local
retry count, validation mode, optional feature toggle, file mode, or generic
tool fallback that remains valid wherever the role is reused. Empty mappings,
empty sequences, and empty strings are appropriate for required structured
inputs that the playbook must supply.

Role defaults are not the repository's environment configuration database.
Topology, environment policy, managed-object identity, shared function
configuration, and values that vary by inventory group or host belong in
inventory. Document the expected role input shape in `defaults/main.yml`; the
playbook must explicitly map inventory objects into those role-local variables.

Avoid merging a large role defaults object with a project object when that
would make role defaults determine environment behavior. Repository function
defaults belong in `inventory/group_vars/all/<topic>.yml` or, when limited to a
logical functional group, in `inventory/group_vars/<group>/<topic>.yml`.
Per-host differences belong in `inventory/host_vars/<host>/<topic>.yml`.
Genuinely role-specific reusable behavior defaults remain in
`roles/<role>/defaults/main.yml`.

Validate mappings, sequences, booleans, strings, ranges, uniqueness, and
runtime prerequisites with `ansible.builtin.assert`. Error messages must tell
the operator what is wrong and how to correct it.

## Ownership Model

Define exactly one owner for each concern:

- package installation;
- configuration files;
- service enablement;
- service start/stop or active/passive election;
- network state;
- logging;
- secrets;
- data migration;
- backup and restore.

A configuration role must not independently start a service that a cluster
manager intentionally keeps stopped. A logging role must not compete with
service-specific logging fragments. Avoid hidden cross-role ownership.

Document ownership in `README.md` and, for complex systems, in this file.

## Idempotency

- Tasks converge to desired state and tolerate reruns.
- Prefer native modules over shell commands.
- Validation and inspection commands use `changed_when: false`.
- Add `failed_when` when return-code semantics need clarification.
- Use `changed_when` explicitly for shell or command tasks that perform
  state-changing work so idempotency stays obvious.
- Avoid `ignore_errors`.
- Use handlers only for changes that require reload or restart.
- Validate before notifying a handler.
- Check service facts carefully: systemd may report a unit with
  `status: not-found`.
- Use drop-ins and fragments instead of overwriting complete vendor files.

## Safe Configuration Deployment

Validate candidate content before replacing a working file:

```yaml
- name: Install validated service configuration
  ansible.builtin.template:
    src: service.conf.j2
    dest: /etc/service/service.conf
    owner: root
    group: root
    mode: "0640"
    validate: /usr/sbin/service-validator --config %s
  notify: Reload service
```

Before using a validator:

1. Check its exact syntax for the target version.
2. Identify input, output, and log-file arguments.
3. Prove it cannot overwrite its input.
4. Confirm its exit-code semantics.
5. Test valid and invalid candidates.

Do not assume an option named `--check`, `--test`, or `--config-test` accepts
the input filename. Some tools use the attached value as an output file.

For structured formats, use parsers or native validation tools instead of
ad-hoc text matching.

## Services And High Availability

For clustered or redundant services, design before implementing:

- active/active or active/passive;
- election owner;
- health and failure detection;
- state replication;
- shared-storage requirements;
- split-brain behavior;
- restart behavior during configuration changes;
- single-node test procedure;
- migration and rollback.

Do not use a VIP manager to coordinate a service that provides its own
supported HA and state-replication protocol unless there is a documented
reason.

If two nodes may run simultaneously, ensure they do not create conflicting
state. If no shared storage exists, document how data is replicated or
partitioned.

## Risky Operations

Broad-impact operations must be opt-in:

```yaml
tags:
  - never
  - maintenance
```

Use this pattern for:

- distribution upgrades;
- destructive migrations;
- experimental replacement services;
- one-time cutovers;
- cleanup of legacy state;
- bulk restarts;
- reboots.

Do not hide destructive behavior behind an ordinary feature tag.

For reboots and network cutovers:

- make intent explicit in inventory;
- ensure a requested cutover still occurs after a previous preparation-only
  run;
- document repeated-run behavior;
- avoid taking all redundant nodes down together.

## Secrets

- Never commit private keys, passwords, API tokens, vault passwords, generated
  credentials, or sensitive runtime state.
- Use Ansible Vault or an external secret provider.
- Mark secret-bearing tasks `no_log: true` where appropriate.
- Do not expose secrets through debug tasks, diffs, command arguments, or
  generated logs.
- Public keys may be committed only when explicitly intended.

## Runtime And Generated State

Generated local artifacts belong under a dedicated ignored directory such as:

```text
state/<environment>/
```

Do not generate runtime content into roles, inventory, examples, or
documentation directories. Remote managed configuration belongs at its target
path and must be reproducible from source.

## Documentation

Update documentation in the same change as behavior.

At minimum document:

- prerequisites and supported platforms;
- inventory entry points;
- shared versus host-specific variables;
- normal execution;
- feature tags;
- opt-in and destructive tags;
- service ownership;
- validation behavior;
- cutover, rollback, and reboot expectations.

Do not describe planned work as implemented.

## Lint And Test Tooling

When the repository defines an Ansible Execution Environment, run lint,
inventory, syntax, and playbook commands through that environment. Do not mix
host-installed Ansible tooling with EE-provided collections and plugins.

Recommended `.ansible-lint.yml`:

```yaml
---
profile: production
strict: true

exclude_paths:
  - .ansible/
  - .git/
  - collections/
  - state/

warn_list:
  - experimental
  - jinja[spacing]
  - fqcn[deep]

skip_list: []
```

Recommended `Makefile`:

```makefile
.PHONY: lint lint-ansible syntax inventory tasks check

lint: check lint-ansible syntax inventory tasks

check:
	git diff --check

lint-ansible:
	ansible-lint

syntax:
	ansible-playbook --syntax-check playbooks/site.yml

inventory:
	ansible-inventory --graph >/dev/null
	ansible-inventory --list >/dev/null

tasks:
	ansible-playbook playbooks/site.yml --list-tasks >/dev/null
	ansible-playbook playbooks/site.yml --list-tags >/dev/null
```

Run at minimum:

```bash
make lint
```

If no Makefile exists, run the equivalent commands directly.

Use check mode separately:

```bash
ansible-playbook playbooks/site.yml --limit <test-host> --check --diff
```

Check mode requires reachable hosts, is module-dependent, and does not replace
lint, syntax checking, or native service validators.

For `never` tags, verify:

```bash
ansible-playbook playbooks/site.yml --list-tasks
ansible-playbook playbooks/site.yml --list-tasks --tags <opt-in-tag>
```

## Runtime Verification

Static checks prove structure, not service behavior. When safe and reachable,
add focused probes:

- service-native configuration test;
- systemd active/enabled state;
- listening sockets;
- protocol request over TCP and UDP where relevant;
- authoritative versus recursive behavior;
- cluster state and peer health;
- failover and recovery;
- idempotent second Ansible run.

State exactly what was and was not tested.

## Git Discipline

- Inspect `git status` before editing and before committing.
- Never revert unrelated changes.
- Stage explicit paths, not the entire worktree.
- Use focused imperative commit messages.
- Do not rewrite user history without explicit approval.
- Keep migrations, behavior changes, and unrelated refactors in separate
  commits.

## Agent Checklist

Before finishing:

- Is public configuration minimal and intent-oriented?
- Are repository function defaults in the correct `group_vars` layer while
  genuinely role-specific defaults remain with the role?
- Are shared and host-specific values separated?
- Does inventory model managed objects and their infrastructure relationships?
- Does each role consume an explicit local interface?
- Are task-local registers and facts short leading-underscore names?
- Do playbooks contain orchestration only, with no resource-management tasks?
- Is `tasks/main.yml` only a dispatcher?
- Does every executable concern live in an owning role task file?
- Do task names, files, and tags align?
- Is there exactly one lifecycle owner per service?
- Are risky operations opt-in?
- Are candidates validated safely before installation?
- Were CLI semantics verified rather than guessed?
- Is the change idempotent?
- Are secrets protected?
- Is documentation current?
- Did lint, inventory, syntax, task-list, and tag-list checks pass?
- Were runtime checks performed where safe?
- Are unrelated worktree changes untouched?

Prefer the design that is easiest to reason about during failure, rerun,
upgrade, and handover.
