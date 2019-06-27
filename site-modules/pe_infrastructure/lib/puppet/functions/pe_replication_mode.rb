require 'puppet_x/puppetlabs/meep/config'

# Return the replication mode for the host: none, source or replica
#
# The data is obtained from the MEEP pe.conf configuration.
Puppet::Functions.create_function(:pe_replication_mode) do

  # @param certname The certname to determine replication mode for
  dispatch :pe_replication_mode do
    param 'String', :certname
  end

  def pe_replication_mode(certname)
    config = PuppetX::Puppetlabs::Meep::Config.new(closure_scope)

    replicas = config.list_nodes(:primary_master_replica)
    master = config.list_nodes(:primary_master).first

    replication_mode = 'none'

    if replicas.size > 0
      if certname.downcase == master.downcase
        replication_mode = 'source'
      elsif replicas.include?(certname)
        replication_mode =  'replica'
      end
    end

    replication_mode
  end
end
