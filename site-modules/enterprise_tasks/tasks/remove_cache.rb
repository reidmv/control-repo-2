#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'puppet'
require 'json'
require 'open3'

class RemoveCache < TaskHelper
  def task(_)
    certname = Open3.capture2e('puppet config print certname')[0].strip
    output, status = Open3.capture2e("rm -f /opt/puppetlabs/puppet/cache/client_data/catalog/#{certname}.json")
    raise TaskHelper::Error.new("Unable to remove cached catalog on host with certname #{certname}", 'puppetlabs.certregen/remove-cache-failed', output) if !status.exitstatus.zero?

    result = { _output: output }
    result.to_json
  end
end

RemoveCache.run if __FILE__ == $PROGRAM_NAME
