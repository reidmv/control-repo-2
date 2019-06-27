# enterprise_tasks

A collection of tasks for the installation, management, and configuration of Puppet Enterprise.

[PE-23295 Tracking ticket for Installer and Management team's efforts](https://tickets.puppetlabs.com/browse/PE-23295)

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with enterprise_tasks](#setup)
    * [What enterprise_tasks affects](#what-enterprise_tasks-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with enterprise_tasks](#beginning-with-enterprise_tasks)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
    * [Plans](#plans)
      * [Whitelisted Plans](#whitelisted-plans)
      * [Helper Plans](#helper-plans)
      * [Testing Plans](#testing-plans)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Description

This Bolt module provides a variety of tasks for PE-related operations. See [Reference](#reference) below for a list of plans (or bolt plan show once you are setup). Of course, the individual tasks that make up each of those plans are also available.

## Setup

First, this requires having an installation of Bolt. Steps for installing Bolt can be found in the [Bolt Documentation](https://puppet.com/docs/bolt/1.x/bolt_installing.html).

To use this module, you can add it as a dependency into your Bolt installation's default Puppetfile, or you can add it into a Puppetfile in your own custom Boltdir.

```
mod 'enterprise_tasks', :git: 'git@github.com:puppetlabs/enterprise_tasks.git'
```

If you would like to create a custom Boltdir, you first need to create a `bolt.yaml` file in the directory which you'd like to use for the Boltdir. Then, you can specify the modules you would like your Boltdir to have by creating a Puppetfile in that same directory. Then, you can call `bolt puppetfile install --boltdir <path-to-boltdir>` to install your specified modules into your Boltdir. Then your tasks/plans can be run by calling `bolt --boltdir <path-to-boltdir> task run <task>` or `bolt --boltdir <path-to-boltdir> plan run <plan>`

If you're interested in cloning this repo to use it as a module, rather than having it as a dependency in a Puppetfile, you should be able to clone the repo into either `$HOME/.puppetlabs/bolt/site` or clone it into `<path-to-custom-boltdir>/site`. You can also include it as a local module in your Puppetfile (`mod 'enterprise_tasks', local: true`) and copy it directly into the boltdir's `modules` directory.

## Usage

If this module is installed into the default Boltdir:

To show available tasks: `bolt task show`

To show available plans: `bolt plan show`

To run a task: `bolt task run enterprise_tasks::<name_of_task> <parameters>`

To run a plan: `bolt plan run enterprise_tasks::<name_of_plan> <parameters>`

If using a custom Boltdir, you need to use the `--boltdir <path-to-boltdir>` flag with the above commands to allow Bolt to recognize your modules.

The module has a Puppetfile, so you will need to ensure that these dependencies are installed.

To use the testing install/upgrade plans see [Testing Plans](#testing-plans) below.

## Reference

### Plans

Use `bolt plan show` for the most current listing.

Not every plan is necessarily in use in a PE install.

The `puppet infra run` action whitelists certain plans for use in PE.

#### Whitelisted Plans
##### agent_cert_regen.pp

Used to regenert Puppet agent certicates.

##### convert_legacy_compiler.pp

Converts a compiler from the legacy master profile to a master/puppetdb profile.

##### enable_ha_failover.pp

An HA helper plan, used to repurpose a failed master as a replica after a replica has been promoted.

##### master_cert_regen.pp

Used to regenerate the PE master's certificate, helpful if the master is renamed.

##### migrate_split_to_mono.pp

A plan for migrating a legacy split configuration of PE to a master/database
split. Legacy splits were deprecated in 2019.1 and will be dropped in 2019.2.

##### rebuild_ca.pp

Used to rebuild the Puppetserver's entire Certificate Authority.

#### Helper plans

Plans used by other plans.

##### create_tempdirs.pp

Uses mktemp to generate unique working directories on all targets. Stores the
path to the directory as a variable 'workdir' on each target.

##### ha_puppetdb_sync.pp

Will be used by upgrade plans to manage syncing and unsyncing master/replica
databases before and after upgrade.

##### verify_nodes.pp

Used to test that a PE infrastructure node is in a given role.

#### sync_enterprise_data.pp

Used to recover configuration on the master and sync it (user_data.conf and
nodes/\*) to a list of other infrastructure nodes.

Currently this plan is only used by the testing/upgrade_pe plan. It is not
clever enough to figure out what the rest of the infrastructure is from the
data it recovers, but could be improved to do so if necessary.

#### Testing Plans

The plans/testing/\* plans are intended for use in internal testing pipelines.

They are intended to be equally useful for manual testing. If you are set up to
run plans from this module on your workstation, then once you have vms checked
out, you should be able to run any of these plans to create a pe.conf, get a PE
tarball on to the nodes, or install as needed.

For resetting nodes:

`bolt command run '/opt/puppetlabs/bin/puppet-enterprise-uninstaller -y -d -p' -n [node,list]`

seemed simple enough to not be worth a plan of its own.

To get started using these plans manually, you can use these steps:

Check out an el7 vm (using [floaty](git@github.com/briancain/vmfloaty) for example).

Make sure and shell in with ssh-agent forwarding!

`ssh -A root@<newvm>`

```sh
# assumes root login
rpm -Uvh https://yum.puppet.com/puppet6-release-el-7.noarch.rpm
yum install -y puppet-bolt git

# Set up paths assumed by the enterprise_tasks/bolt.yaml
mkdir -p /opt/puppetlabs/installer/share/boltdir/site
mkdir -p /var/log/puppetlabs/installer

# Add an entry for github to known hosts so we don't get asked whether to accept key
echo "github.com,192.30.255.112 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" >> "${HOME}/.ssh/known_hosts"
git clone git@github.com:puppetlabs/enterprise_tasks.git
cd enterprise_tasks
bolt puppetfile install

# NOTE: puppetfile install will remove any path from the site dir that is not in the Puppetfile; this includes enterprise_tasks itself, so it is important not to link enterprise_tasks into the path until after you've run this...
ln -s "${HOME}/enterprise_tasks" /opt/puppetlabs/installer/share/boltdir/site/enterprise_tasks
bolt plan show
```

##### create_pe_conf

Generates a basic pe.conf suitable for initial installtion given a few key
parameters with optional overrides. See
[create_pe_conf.pp](plans/testing/create_pe_conf.pp) for details.

##### get_pe

Downloads and unpacks a PE tarball for the correct platform on some set of
nodes. Must be able to reach enterprise.delivery.puppetlabs.net, unless you are
uploading a tarball that you have built locally (with say,
[frankenbuilder](git@github.com:puppetlabs/frankenbuilder)).

See [get_pe.pp](plans/testing/get_pe.pp) for details.

##### install_pe

Handles installation of PE in CI for all layouts. See
[installe_pe.pp](plans/testing/install_pe.pp) for details.

##### run_installer

Runs the puppet-enterprise-installer on a node. Returns the installer log on
failure. See [run_installer.pp](plans/testing/install_pe.pp) for details.

##### upgrade_pe

Handles upgrade of PE in CI for all layouts. SEE
[upgrade_pe.pp](plans/testing/install_pe.pp) for details

## Limitations

This module is shipped with the pe-installer package, and is intended for use with PE installations from 2018.1.x forward.

## Development

### Testing

Run:

`bundle exec rake test`

to run all of the test targets.

There is a validate_plans target which can be run to get `puppet parser
validate --tasks` feedback for all the plans.

## Contributing

Fork the module, submit pull requests, please ensure that tests are passing and
new tests are added where appropriate.

Commit messages should follow standard Puppet practice. The header should start
with a (TICKET-1234) reference or (maint). Commit messages should provide a
summary of what the problem was, what you changed and how the change fixes the
problem. Typos are an obvious exception.
