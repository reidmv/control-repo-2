#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'puppet'
require 'open3'

class SignCert < TaskHelper
  def task(host:, **kwargs)
    signed = false
    signing_options = {}
    signing_options[:allow_authorization_extensions] = kwargs[:allow_authorization_extensions] || true
    signing_options[:allow_dns_alt_names] = kwargs[:allow_dns_alt_names] || true
    ca_cmd = '/opt/puppetlabs/server/bin/puppetserver ca'

    Puppet.initialize_settings
    Puppet::SSL::Oids.register_puppet_oids
    Puppet::SSL::Oids.load_custom_oid_file(Puppet[:trusted_oid_mapping_file])
    certname = Open3.capture2e('puppet config print certname')[0].strip

    signing_timeout = 2
    cert_req_exists = false
    cert_autosigned = false
    5.times do
      requests, = Open3.capture2e("#{ca_cmd} list")
      all, = Open3.capture2e("#{ca_cmd} list --all")

      requested = requests.split("\n").any? { |request| request =~ %r{#{host}} }
      in_all = all.split("\n").any? { |item| item =~ %r{#{host}} }
      cert_autosigned = !requested && in_all
      break if cert_autosigned

      if requests =~ %r{No certificates to list}
        sleep signing_timeout
        signing_timeout *= 2
      else
        cert_req_exists = true
      end
      break if cert_req_exists
    end

    output, status = Open3.capture2e("#{ca_cmd} sign --certname=#{host}") if !cert_autosigned
    signed = true if cert_autosigned || (status && status.exitstatus.zero?)
    raise TaskHelper::Error.new("Could not sign request for host with certname #{host} using caserver #{certname}", 'puppetlabs.certregen/sign-cert-failed', output) if !signed

    result = { signed: signed }
    result.to_json
  end
end

SignCert.run if __FILE__ == $PROGRAM_NAME
