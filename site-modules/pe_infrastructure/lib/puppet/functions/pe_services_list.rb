require 'puppet_x/puppetlabs/meep/config'

# Returns a hash of components mapped to arrays of server, port pairs. This
# list is useful for making api calls to any of the configured PE
# infrastructure nodes.
#
# @example From a simple monolithic install on master.node
#
# ```puppet
# $pe_services = pe_services_list()
# # (assuming pe.conf configured with default ports)
# #
#   {
#     "primary" => {
#       "puppetserver" => [{
#         "display_name"  => "Puppet Server",
#         "node_certname" => "master.node",
#         "port"          => 8140,
#         "prefix"        => "",
#         "server"        => "master.node",
#         "status_key"    => "pe-master",
#         "status_prefix" => "status",
#         "status_url"    => "https://master.node:8140/status",
#         "type"          => "master",
#         "url"           => "https://master.node:8140/"
#       }],
#       "code-manager" => [{
#         "display_name"  => "Code Manager",
#         "node_certname" => "master.node",
#         "port"          => 8170,
#         "prefix"        => "",
#         "server"        => "master.node",
#         "status_key"    => "code-manager-service",
#         "status_prefix" => "status",
#         "status_url"    => "https://master.node:8140/status",
#         "type"          => "master",
#         "url"           => "https://master.node:8170/"
#       }],
#       etc.
#     },
#     "secondary" => {
#       "puppetserver" => [],
#       etc.
#     },
#     "replica" => {
#       "puppetserver" => [],
#       etc.
#     }
#   }
# ```
Puppet::Functions.create_function(:pe_services_list) do
  # @return [Hash<String,Hash<String,Array[Hash<String,String>]>>]
  def pe_services_list
    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)
    config.services_list
  end
end
