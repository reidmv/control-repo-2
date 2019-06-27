# Extension namespace for Puppet
module PuppetX
  # Under the Puppet organization namespace
  module Puppetlabs
    module Meep
      # To be able to answer questions about PE configuration both from within
      # puppet functions and from other code outside of the context of a
      # compiling catalog, it is necessary to make a general class for any
      # default parameter values we need to present.
      #
      # To make port information available, there has to be a
      # source of default port information outside of the class parameter
      # defaults which are not generally accessible.
      #
      # TODO Add the Defaults::PE_INFRASTRUCTURE port information to
      # pe_infrastructure::data().  This could then be used to expose these in
      # catalogs, and puppet_enterprise::data() could then be used to lookup
      # these defaults as the basis for the defaults that it passes
      # on.
      class Defaults

        # Shared defaults
        PE_INFRASTRUCTURE = {
          "puppet_master_port"          => 8140,
          "code_manager_port"           => 8170,
          "puppetdb_port"               => 8081,
          "console_api_port"            => 4433,
          "database_port"               => 5432,
          "orchestrator_port"           => 8143,
          "pcp_broker_port"             => 8142,
          "mcollective_middleware_port" => 61613,
          "mcollective_middleware_user" => 'mcollective',
          'code_manager_status_port'    => 8140,
          'console_status_port'         => 4433,
          'orchestrator_status_port'    => 8143,
          'pcp_broker_status_port'      => 8143,
          'puppetdb_status_port'        => 8081,
          'puppetserver_status_port'    => 8140,
        }.freeze

        # Mapping of key PE components to the principal profile that manages it
        COMPONENTS_TO_PROFILES = {
          'certificate_authority'  => 'puppet_enterprise::profile::certificate_authority',
          'primary_master'         => 'puppet_enterprise::profile::primary_master',
          'orchestrator'           => 'puppet_enterprise::profile::orchestrator',
          'puppetdb'               => 'puppet_enterprise::profile::puppetdb',
          'database'               => 'puppet_enterprise::profile::database',
          'console'                => 'puppet_enterprise::profile::console',
          'primary_master_replica' => 'puppet_enterprise::profile::primary_master_replica',
          'compile_master'         => 'puppet_enterprise::profile::compile_master',
          'mco_hub'                => 'puppet_enterprise::profile::amq::hub',
          'mco_broker'             => 'puppet_enterprise::profile::amq::broker',
          'mco_client'             => 'puppet_enterprise::profile::mcollective::peadmin',
          'enabled_primary_master_replica' => 'puppet_enterprise::profile::primary_master_replica',
        }.freeze

        # Multiple profiles may configure a specific PE service (in different roles)
        SERVICES_TO_PROFILES = {
          'puppetserver' => [
            'puppet_enterprise::profile::primary_master',
            'puppet_enterprise::profile::primary_master_replica',
            'puppet_enterprise::profile::compile_master',
          ].freeze,
          'file-sync-storage' => [
            'puppet_enterprise::profile::primary_master',
          ].freeze,
          'file-sync-client' => [
            'puppet_enterprise::profile::primary_master',
            'puppet_enterprise::profile::primary_master_replica',
            'puppet_enterprise::profile::compile_master',
          ].freeze,
          'code-manager' => ['puppet_enterprise::profile::primary_master'].freeze,
          'puppetdb'     => [
            'puppet_enterprise::profile::puppetdb',
            'puppet_enterprise::profile::primary_master_replica',
          ].freeze,
          'orchestrator' => ['puppet_enterprise::profile::primary_master'].freeze,
          'pcp-broker'   => ['puppet_enterprise::profile::primary_master'].freeze,
          'classifier'   => [
            'puppet_enterprise::profile::console',
            'puppet_enterprise::profile::primary_master_replica',
          ].freeze,
          'rbac'         => [
            'puppet_enterprise::profile::console',
            'puppet_enterprise::profile::primary_master_replica',
          ].freeze,
          'activity'     => [
            'puppet_enterprise::profile::console',
            'puppet_enterprise::profile::primary_master_replica',
          ].freeze,
        }.freeze

        # A mapping of services to basic information about each service.
        COMPONENT_SERVICES = {
          'puppetserver' => {
            'display_name' => 'Puppet Server',
            'status_key'   => 'pe-master',
            'status_port'  => PE_INFRASTRUCTURE['puppetserver_status_port'],
            'status_prefix' => 'status',
            'port'         => PE_INFRASTRUCTURE["puppet_master_port"],
            'prefix'       => '',
            'protocol'     => 'https',
            'type'         => 'master',
          }.freeze,
          'file-sync-storage' => {
            'display_name' => 'File Sync Storage Service',
            'status_key'   => 'file-sync-storage-service',
            'status_port'  => PE_INFRASTRUCTURE['puppetserver_status_port'],
            'status_prefix' => 'status',
            'port'         => PE_INFRASTRUCTURE["puppet_master_port"],
            'prefix'       => '',
            'protocol'     => 'https',
            'type'         => 'file-sync-storage',
          }.freeze,
          'file-sync-client' => {
            'display_name' => 'File Sync Client Service',
            'status_key'   => 'file-sync-client-service',
            'status_port'  => PE_INFRASTRUCTURE['puppetserver_status_port'],
            'status_prefix' => 'status',
            'port'         => PE_INFRASTRUCTURE["puppet_master_port"],
            'prefix'       => '',
            'protocol'     => 'https',
            'type'         => 'file-sync-client',
          }.freeze,
          'code-manager' => {
            'display_name' => 'Code Manager',
            'status_key'   => 'code-manager-service',
            'status_port'  => PE_INFRASTRUCTURE['code_manager_status_port'],
            'status_prefix' => 'status',
            'port'         => PE_INFRASTRUCTURE["code_manager_port"],
            'prefix'       => '',
            'protocol'     => 'https',
            'type'         => 'code-manager',
          }.freeze,
          'puppetdb'     => {
            'display_name' => 'PuppetDB',
            'status_key'   => 'puppetdb-status',
            'status_port'  => PE_INFRASTRUCTURE['puppetdb_status_port'],
            'status_prefix' => 'status',
            'port'         => PE_INFRASTRUCTURE["puppetdb_port"],
            'prefix'       => 'pdb',
            'protocol'     => 'https',
            'type'         => 'puppetdb',
          }.freeze,
          'orchestrator' => {
            'display_name' => 'Orchestrator',
            'status_key'   => 'orchestrator-service',
            'status_port'  => PE_INFRASTRUCTURE['orchestrator_status_port'],
            'status_prefix' => 'status',
            'port'         => PE_INFRASTRUCTURE["orchestrator_port"],
            'prefix'       => 'orchestrator',
            'protocol'     => 'https',
            'type'         => 'orchestrator',
          }.freeze,
          'pcp-broker'   => {
            'display_name' => 'PCP Broker',
            'status_key'   => 'broker-service',
            'status_port'  => PE_INFRASTRUCTURE['pcp_broker_status_port'],
            'status_prefix' => 'status',
            'port'         => PE_INFRASTRUCTURE["pcp_broker_port"],
            'prefix'       => 'pcp',
            'protocol'     => 'wss',
            'type'         => 'pcp-broker',
          }.freeze,
          'classifier'   => {
            'display_name' => 'Classifier',
            'status_key'   => 'classifier-service',
            'status_port'  => PE_INFRASTRUCTURE['console_status_port'],
            'status_prefix' => 'status',
            'port'         => PE_INFRASTRUCTURE["console_api_port"],
            'prefix'       => 'classifier-api',
            'protocol'     => 'https',
            'type'         => 'classifier',
          }.freeze,
          'rbac'         => {
            'display_name' => 'RBAC',
            'status_key'   => 'rbac-service',
            'status_port'  => PE_INFRASTRUCTURE['console_status_port'],
            'status_prefix' => 'status',
            'port'         => PE_INFRASTRUCTURE["console_api_port"],
            'prefix'       => 'rbac-api',
            'protocol'     => 'https',
            'type'         => 'rbac',
          }.freeze,
          'activity'     => {
            'display_name' => 'Activity Service',
            'status_key'   => 'activity-service',
            'status_port'  => PE_INFRASTRUCTURE['console_status_port'],
            'status_prefix' => 'status',
            'port'         => PE_INFRASTRUCTURE["console_api_port"],
            'prefix'       => 'activity-api',
            'protocol'     => 'https',
            'type'         => 'activity',
          }.freeze,
        }.freeze

        # A mapping of services to the parameters we need to lookup to identify
        # a modified parameter.
        OVERRIDEABLE_COMPONENT_SERVICES_PARAMS = {
          'puppetserver' => {
            'port' => [
              'puppet_enterprise::profile::master::puppet_master_port',
              'puppet_enterprise::puppet_master_port',
            ].freeze,
            'status_port' => [
              'puppet_enterprise::master::puppetserver::puppetserver_webserver_ssl_port',
            ].freeze,
          }.freeze,
          'file-sync-storage' => {
            'port' => [
              'puppet_enterprise::profile::master::puppet_master_port',
              'puppet_enterprise::puppet_master_port',
            ].freeze,
            'status_port' => [
              'puppet_enterprise::master::puppetserver::puppetserver_webserver_ssl_port',
            ].freeze,
          }.freeze,
          'file-sync-client' => {
            'port' => [
              'puppet_enterprise::profile::master::puppet_master_port',
              'puppet_enterprise::puppet_master_port',
            ].freeze,
            'status_port' => [
              'puppet_enterprise::master::puppetserver::puppetserver_webserver_ssl_port',
            ].freeze,
          }.freeze,
          'code-manager' => {
            'port' => [
              'puppet_enterprise::master::code_manager::webserver_ssl_port',
            ].freeze,
            'status_port' => [
              'puppet_enterprise::master::puppetserver::puppetserver_webserver_ssl_port',
            ].freeze,
          }.freeze,
          'puppetdb' => {
            'port' =>  [
              'puppet_enterprise::profile::puppetdb::ssl_listen_port',
              'puppet_enterprise::puppetdb_port',
            ].freeze,
            'status_port' =>  [
              'puppet_enterprise::profile::puppetdb::ssl_listen_port',
              'puppet_enterprise::puppetdb_port',
            ].freeze,
          }.freeze,
          'orchestrator' => {
            'port' => [
              'puppet_enterprise::profile::orchestrator::ssl_listen_port',
              'puppet_enterprise::orchestrator_port',
            ].freeze,
            'status_port' => [
              'puppet_enterprise::profile::orchestrator::ssl_listen_port',
              'puppet_enterprise::orchestrator_port',
            ].freeze,
          }.freeze,
          'pcp-broker' => {
            'port' => [
              'puppet_enterprise::profile::orchestrator::pcp_listen_port',
              'puppte_enterprise::pcp_broker_port'
            ].freeze,
            'status_port' => [
              'puppet_enterprise::profile::orchestrator::ssl_listen_port',
              'puppet_enterprise::orchestrator_port',
            ].freeze,
          }.freeze,
          'classifier' => {
            'port' => [
              'puppet_enterprise::profile::console::console_services_api_ssl_listen_port',
              'puppet_enterprise::api_port',
            ].freeze,
            'status_port' => [
              'puppet_enterprise::profile::console::console_services_api_ssl_listen_port',
              'puppet_enterprise::api_port',
            ].freeze,
          }.freeze,
          'rbac' => {
            'port' => [
              'puppet_enterprise::profile::console::console_services_api_ssl_listen_port',
              'puppet_enterprise::api_port',
            ].freeze,
            'status_port' => [
              'puppet_enterprise::profile::console::console_services_api_ssl_listen_port',
              'puppet_enterprise::api_port',
            ].freeze,
          }.freeze,
          'activity' =>  {
            'port' => [
              'puppet_enterprise::profile::console::console_services_api_ssl_listen_port',
              'puppet_enterprise::api_port',
            ].freeze,
            'status_port' => [
              'puppet_enterprise::profile::console::console_services_api_ssl_listen_port',
              'puppet_enterprise::api_port',
            ].freeze,
          }.freeze,
        }.freeze

        # Mapping the default ports to their respective services
        DEFAULT_PORTS_FOR_SERVICES = {
          "puppetserver" => PE_INFRASTRUCTURE["puppet_master_port"],
          "code-manager" => PE_INFRASTRUCTURE["code_manager_port"],
          "puppetdb"     => PE_INFRASTRUCTURE["puppetdb_port"],
          "orchestrator" => PE_INFRASTRUCTURE["orchestrator_port"],
          "pcp-broker"   => PE_INFRASTRUCTURE["pcp_broker_port"],
          "classifier"   => PE_INFRASTRUCTURE["console_api_port"],
          "rbac"         => PE_INFRASTRUCTURE["console_api_port"],
          "activity"     => PE_INFRASTRUCTURE["console_api_port"],
        }.freeze

        # Puppet Enterprise default role definitions
        ROLE_DEFINITIONS = {
          ############
          # Monolithic
          'pe_role::monolithic::primary_master' => [
            'puppet_enterprise',
            'pe_install',
            'puppet_enterprise::profile::database',
            'puppet_enterprise::profile::primary_master',
            'puppet_enterprise::profile::certificate_authority',
            'puppet_enterprise::profile::orchestrator',
            'puppet_enterprise::profile::puppetdb',
            'puppet_enterprise::profile::console',
            'puppet_enterprise::profile::amq::broker',
            'puppet_enterprise::profile::mcollective::peadmin',
            'pe_infrastructure::agent::mcollective',
            'pe_infrastructure::enterprise::agent',
          ].freeze,
          'pe_role::monolithic::primary_master_replica' => [
            'puppet_enterprise',
            'pe_install',
            'puppet_enterprise::profile::primary_master_replica',
            'puppet_enterprise::profile::mcollective::peadmin',
            'pe_infrastructure::agent::mcollective',
            'pe_infrastructure::enterprise::agent',
          ].freeze,
          'pe_role::monolithic::compile_master' => [
            'puppet_enterprise',
            'pe_install',
            'puppet_enterprise::profile::compile_master',
            'puppet_enterprise::profile::mcollective::peadmin',
            'pe_infrastructure::agent::mcollective',
            'pe_infrastructure::enterprise::agent',
          ].freeze,
          'pe_role::monolithic::mco_hub' => [
            'puppet_enterprise',
            'pe_install',
            'puppet_enterprise::profile::amq::hub',
            'pe_infrastructure::agent::mcollective',
            'pe_infrastructure::enterprise::agent',
          ].freeze,
          'pe_role::monolithic::mco_broker' => [
            'puppet_enterprise',
            'pe_install',
            'puppet_enterprise::profile::amq::broker',
            'pe_infrastructure::agent::mcollective',
            'pe_infrastructure::enterprise::agent',
          ].freeze,

          ############
          # Split
          'pe_role::split::primary_master' => [
            'puppet_enterprise',
            'pe_install',
            'puppet_enterprise::profile::primary_master',
            'puppet_enterprise::profile::certificate_authority',
            'puppet_enterprise::profile::orchestrator',
            'puppet_enterprise::profile::amq::broker',
            'puppet_enterprise::profile::mcollective::peadmin',
            'pe_infrastructure::agent::mcollective',
            'pe_infrastructure::enterprise::agent',
          ].freeze,
          'pe_role::split::puppetdb' => [
            'puppet_enterprise',
            'pe_install',
            'puppet_enterprise::profile::database',
            'puppet_enterprise::profile::puppetdb',
            'pe_infrastructure::agent::mcollective',
            'pe_infrastructure::enterprise::agent',
          ].freeze,
          'pe_role::split::console' => [
            'puppet_enterprise',
            'pe_install',
            'puppet_enterprise::profile::console',
            'pe_infrastructure::agent::mcollective',
            'pe_infrastructure::enterprise::agent',
          ].freeze,
          'pe_role::split::compile_master' => [
            'puppet_enterprise',
            'pe_install',
            'puppet_enterprise::profile::compile_master',
            'puppet_enterprise::profile::mcollective::peadmin',
            'pe_infrastructure::agent::mcollective',
            'pe_infrastructure::enterprise::agent',
          ].freeze,
          'pe_role::split::mco_hub' => [
            'puppet_enterprise',
            'pe_install',
            'puppet_enterprise::profile::amq::hub',
            'pe_infrastructure::agent::mcollective',
            'pe_infrastructure::enterprise::agent',
          ].freeze,
          'pe_role::split::mco_broker' => [
            'puppet_enterprise',
            'pe_install',
            'puppet_enterprise::profile::amq::broker',
            'pe_infrastructure::agent::mcollective',
            'pe_infrastructure::enterprise::agent',
          ].freeze,
        }.freeze

        # Preferred accessor for the default role profile definitions returns
        # a deep clone so our constant can't be manipulated by any other code.
        # (Mostly being paranoid about a module fiddling with it in a data()
        # method...)
        def self.role_definitions
          deep_clone(ROLE_DEFINITIONS)
        end

        # Preferred accessor for component services defaults. Returns a deep
        # clone so our constant can't be manipulated by any other code.
        def self.component_services
          deep_clone(COMPONENT_SERVICES)
        end

        def self.parameters
          # no internal array/hashes to deep clone
          PE_INFRASTRUCTURE.dup
        end

        # Utility method for producing a deep clone of an
        # arbitrarily nested Hash/Array structure.
        def self.deep_clone(obj)
          case obj
          when Hash
            obj.inject({}) do |hash,pair|
              hash[pair[0]] = deep_clone(pair[1])
              hash
            end
          when Array
            obj.map { |e| deep_clone(e) }
          when Numeric
            obj
          else
            obj.dup
          end
        end
      end
    end
  end
end
