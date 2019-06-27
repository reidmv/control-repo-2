#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'fileutils'
require 'yaml'
require 'open3'

# Class for regenerating agent certs
class Regen
  # Error class
  class Error < RuntimeError
    def initialize(kind, msg, details = nil)
      @kind = kind
      @details = details || {}
      super(msg)
    end

    def result
      { _error: {
        kind: @kind,
        msg: message,
        details: @details,
      } }
    end
  end

  def initialize(params)
    @params = JSON.parse(params)
  end

  def make_request
    setup

    unless @params['fetch_only']
      reset_ssl
      create_attrs
    end

    request_certificate
  end

  def setup
    Puppet.initialize_settings
    Puppet::SSL::Oids.register_puppet_oids
    Puppet.settings.use(:main, :agent, :ssl)
  end

  def reset_ssl
    @cacert = @params['cacert']
    certpath = Puppet[:localcacert]
    unless @params['trust_ca'] || @cacert
      # TODO: this should just use a fingerprint
      if File.readable?(certpath)
        @cacert = File.open(certpath) { |f| f.read }
      else
        raise Regen::Error.new('puppet_cert/missing_ca',
                               "No ca certificate present at #{certpath} or provided in params")
      end
    end

    FileUtils.rm_rf(Puppet[:ssldir])
    # Let Puppet recreate directories
    Puppet.settings.clear
    Puppet.settings.use(:main, :agent, :ssl)

    File.open(certpath, 'w') { |f| f.write(@cacert) } if @cacert
    # TODO: why does this cause a TypeError
    # Puppet::FileSystem.exclusive_create(certpath, 'w') { |f| f.write(cert) }
  end

  def create_attrs
    if attrs = @params['attrs']
      File.open(Puppet[:csr_attributes], 'w') do |f|
        f.write(YAML.dump(attrs))
      end
    end
  end

  def request_certificate(_wait = 0)
    host = Puppet::SSL::Host.new
    begin
      host.certificate
    rescue Puppet::Error => e
      raise Error.new('puppet_cert/request-failed',
                      "Certificate request failed: #{e.message}")
    end
    # TODO: handle waiting
    # host.generate
    host
  end
end

class RenewCert < TaskHelper
  def task(**kwargs)
    regen = Regen.new(kwargs)
    host = regen.make_request

    output, status = Open3.capture2e('puppet ssl submit_request') if host.certificate.nil?
    raise TaskHelper::Error.new("Failed to generate certificate request on host #{host}", 'puppetlabs.certregen/regen-cert-failed', output) if status && status.exitstatus == 1
    result = { signed: !host.certificate.nil? }
    result.to_json
  end
end

if __FILE__ == $PROGRAM_NAME
  begin
    CertRegen.run
  rescue Regen::Error => e
    puts e.result.to_json
    exit 1
  end
end
