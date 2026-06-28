.PHONY: lint check lint-ansible syntax inventory tasks examples

ANSIBLE_NAVIGATOR ?= ansible-navigator
SITE_PLAYBOOK ?= playbooks/site.yml
EXAMPLE_INVENTORY ?= inventory/inventory_example.yml
EXAMPLE_HOSTS ?= snobox1 natbox1 pubbox1

lint: check lint-ansible syntax inventory tasks examples

check:
	git diff --check

lint-ansible:
	$(ANSIBLE_NAVIGATOR) exec -- ansible-lint

syntax:
	$(ANSIBLE_NAVIGATOR) exec -- ansible-playbook --syntax-check $(SITE_PLAYBOOK)

inventory:
	$(ANSIBLE_NAVIGATOR) exec -- ansible-inventory --graph >/dev/null
	$(ANSIBLE_NAVIGATOR) exec -- ansible-inventory --list >/dev/null

tasks:
	$(ANSIBLE_NAVIGATOR) exec -- ansible-playbook $(SITE_PLAYBOOK) --list-tasks >/dev/null
	$(ANSIBLE_NAVIGATOR) exec -- ansible-playbook $(SITE_PLAYBOOK) --list-tags >/dev/null

examples:
	$(foreach host,$(EXAMPLE_HOSTS),$(ANSIBLE_NAVIGATOR) exec -- ansible-inventory -i $(EXAMPLE_INVENTORY) --host $(host) >/dev/null && ) true
