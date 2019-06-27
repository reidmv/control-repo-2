require_relative '../../../enterprise_tasks/pe_conf/generator'

# Given a few parameters describing the installation, return a pe.conf file
# in JSON format.
#
# @param roles [Hash<String,String>] of role => certname settings for PE
# @option [String] roles['master'] The fqdn/certname for the primary master. Required.
# @option [String] roles['puppetdb'] Optionally a different puppetdb host.
# @option [String] roles['database'] Optionally a different database host.
# @option [String] roles['console']  Optionally a different console host.
# @param password [Optional[String]] Optionally the console_admin_password.
# @param other_parameters [Hash] Optionally other PE module parameters to be
#   included in the pe.conf. (These must be keyed by the fully namespaced
#   parameter name ('puppet_enterprise::postgres_version_override' for
#   example)).
# @return [String] JSON string of the constructed pe.conf.
Puppet::Functions.create_function('enterprise_tasks::generate_pe_conf') do

  dispatch :generate_pe_conf do
    param 'Hash', :roles
    optional_param 'Optional[String]', :password
    optional_param 'Hash', :other_parameters
    return_type 'String'
  end

  def generate_pe_conf(roles, password = nil, other_parameters = {})
    args = {}
    args[:roles] = roles
    args[:password] = password if !password.nil?
    args[:other_parameters] = other_parameters if !other_parameters.nil?
    pe_conf = EnterpriseTasks::PeConf::Generator.new(**args)
    pe_conf.to_json
  end
end
