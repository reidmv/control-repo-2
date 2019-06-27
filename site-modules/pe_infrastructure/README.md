# pe_infrastructure

#### Table of Contents

1. [Overview](#overview)
2. [Module Description - What the module does and why it is useful](#module-description)
3. [Setup - The basics of getting started with pe_infrastructure](#setup)
    * [What pe_infrastructure affects](#what-pe_infrastructure-affects)
4. [Usage - Configuration options and additional functionality](#usage)
5. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Overview

This module provides the minimal set of classes needed to configure
puppet-agent in a PE installation and also the classification functions
allowing MEEP to configure PE from the pe.conf data. It is intended to be the
only PE Module in both the basemodulepath and the MEEP modulepath.

If you are looking for the puppet-infrastructure face, it is located in the
[pe_manager
module](https://github.com/puppetlabs/puppetlabs-pe_manager/blob/2018.1.4/lib/puppet/face/infrastructure.rb).
Historically it was the puppet-enterprise face and the tool was the Puppet
Enterprise Manager...

## Module Description

The pe_infrastructure module will take over for the agent side profiles currently
in puppet_enterprise so that the puppet_enterprise module can be restricted to
the MEEP modulepath and no longer be a source of naming contention in customer
environments.

This is not yet done.

The module is also providing functions needed by both MEEP, HA faces and normal
catalog production to determine the mapping of infrastructure nodes to
roles/components in PE.  (So, lists of puppetdb, console, replica,
compile_master nodes, etc, based on MEEP configuration).

## Setup

### What pe_infrastructure affects

* pe_infrastructure::profile::agent
* pe_infrastructure::profile::mcollective::agent

## Usage

### Classification Functions

Can be accessed directly from within a face by instantiating a:

    scope = { "::trusted" => { "certname" => "pe.node.fqdn" }
    PuppetX::Puppetlabs::Meep::Config.new(scope)

The scope can be a full Puppet::Parser::Scope, but ultimately just needs to be
a hash supplying the minimal trusted::certname fact as above so that hiera can
lookup within the MEEP conf.d/nodes hierarchy.

Or it can be accessed within manifests through various pe\_\* shim functions
listed below.

All of the core functionality is in the
[PuppetX::Puppetlabs::Meep::Config](lib/puppet_x/puppetlabs/meep/config.rb)
object.

* list_nodes() is the primary function mapping component -> profiles -> roles
  -> nodes to provide the lists of hosts with which to configure PE
* get_node_profiles() is the ENC function used by
  [pe_manager](https://github.com/puppetlabs/puppetlabs-pe_manager) to
  determine which classes to include for the node MEEP is executing on.

### MEEP Data Modification Functions

Functions to programatically update pe.conf are available in the Config class,
and are specifically encapsulated in the module
[PuppetX::Puppetlabs::Meep::Modify](lib/puppet_x/puppetlabs/meep/config/modify.rb)
for clarity.

## Reference

### Classes

The module has two groups of classes. One set applies to all agent nodes, the
second applies only to infrastructure agent nodes (masters, compile masters,
replicas, etc).

#### PE Agents

* pe_infrastructure::agent - general agent configuration
* pe_infrastructure::agent::meep - this class only acts if the agent is
  classified as infrastructure in pe.conf.  If it is, it includes
  pe_infrastructure::infrastructure, and then kicks off meep in a final
  pe_meep stage.

To prevent meep from running on agent nodes, you would remove
pe_infrastructure::agent::meep from the PE Agents node group.

#### PE Infrastructure Agents

* pe_infrastructure::infrastructure - used by the agent to prepare an
  infrastructure node for a meep run. Conditionally included by the
  pe_infrastructure::agent::meep class above.

This class includes:

* pe_infrastructure::infrastructure::agents - a superset of
  pe_infrastructure::agent that includes the configuration to configure the
  puppet-infrastructure shim to help with running meep.
* pe_infrastructure::infrastructure::sync - the class that synchronizes meep
  data and pe-modules

#### Classes included by Meep

* pe_infrastructure::infrastructure::agent - includes pe_infrastructure::agent
  and pe_infrastructure::puppet_infra_shims

Meep does not include any of the classes to sync enterprise configuration or
the pe-modules, as this should be taken care of either by the installer-shim,
the agent, or potentially an earlier stage in the configure action.

It also does not include any classes to kickstart meep itself, as this would
trap meep in a loop.

### Functions

Terms:

* *PE infrastructure*: the server nodes running one or more of the components
  of a PE stack (puppetserver, puppetdb, console-services,
  orchestration-services, activemq), as opposed to an agent node which only has
  puppet-agent configured on it.
* *host parameters*: the puppet_enterprise parameters which configure the pe
  infrastructure hostnames required for the components of PE to communicate
  with one another

Configuration of PE using MEEP in 2016.2/3 relied on the puppet_enterprise
module's host parameters for classification, principally:

* puppet_enterprise::puppet_master_host
* puppet_enterprise::puppetdb_host
* puppet_enterprise::classifier_host
* puppet_enterprise::database_host

The purpose of these parameters in the puppet_enterprise module is to ensure
that any given PE infrastructure node is configured with the hostnames it needs
to reach the other PE services it relies on. In MEEP's idempotent installer,
these parameters took on an additional function in determining the role of the
node being configured and implicitly which puppet_enterprise::profile classes
would be included on it.

We are now clarifying that process by explicitly adding a node_roles hash to
pe.conf which exists only to map role classes to lists of nodes. This
information is then processed by functions in this module to provide the
default values for the host parameters, which should no longer be specified
directly in pe.conf.

They might be specified in conf.d/nodes files as overrides if a complex layout
required it.

#### `pe_infrastructure_nodes()`

The full set of nodes listed in the pe_conf node_roles arrays. These are all of
the nodes being managed by MEEP as parts of the Puppet Enterprise
infrastructure itself.  So all primary masters, compile masters, puppetdb,
console, etc.

#### `pe_is_infrastructure([certname])`

Complimentary to pe_infrastructure_nodes, returns true false depending on
whether the current node is listed as PE infrastructure by MEEP.  Optionally
can be called with another certname.

#### `pe_list_\{component\}_nodes()`

These functions return lists of nodes matching a particular component in PE:

* primary_master
* certificate_authority
* puppetdb
* console
* database
* orchestrator
* primary_master_replica
* enabled_primary_master_replica
* compile_master
* mco_hub
* mco_broker

(The current definition comes from
[Config#pe_components()](lib/puppet_x/puppetlabs/meep/config.rb))

These are the functions used to determine defaults for the host parameters.

#### `pe_is_node_a(component, [certname])`

Generic function returns true if the passed component is configured on the
current node or optional certname, according to the MEEP data.

#### `pe_services_list()`

Returns a hash of components mapped to arrays of server, port pairs.  It is
intended to be used for configuration of tools and services which need to talk
to all the PE infrastructure services (`puppet enterprise status` for example).

## Limitations

The pe_infrastructure class requires that the MEEP configuration data be current
on the node.

## Development

There is rspec-puppet coverage testing the module behavior.

Specs can be run as follows using the puppetlabs_spec_helper tasks:

    $ bundle config specific_platform true # If not set, bundler will not pull in OSX/Linux specific gems
    $ bundle install
    $ bundle exec rake spec

If you encounter errors related to `cfpropertylist` when running specs on OSX,
try making sure that `bundle config specific_platform true` is set and then
re-run bundle install. That may solve that particular problem.

## Maintenance

Maintainers: Josh Partlow <joshua.partlow@puppetlabs.com>

Tickets: https://tickets.puppetlabs.com/browse/PE. Make sure to set component to 'PE Modules'.
