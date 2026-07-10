# SNObox Tools

## boxctl

`boxctl` manages SNObox add-ons from the SNObox repository root.

```bash
tools/boxctl list
tools/boxctl install roxbox
tools/boxctl run roxbox --limit pubbox1
tools/boxctl status
```

Use `--` with `run` to pass additional arguments to `ansible-navigator run` or
`ansible-playbook`:

```bash
tools/boxctl run roxbox --limit pubbox1 -- -vvv
tools/boxctl run acsbox --limit pubbox1 -- --tags acsbox_compliance_reports
tools/boxctl run roxbox --limit pubbox1 -- -e '{"roxbox_overrides":{"compliance_reports":{"enabled":false}}}'
```

Arguments before `--` belong to `boxctl`; arguments after `--` are forwarded
unchanged.
