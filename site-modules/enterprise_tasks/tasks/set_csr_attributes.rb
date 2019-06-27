#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'yaml'

class SetCsrAttributes < TaskHelper
  CSR_ATTRIBUTES_FILE = '/etc/puppetlabs/puppet/csr_attributes.yaml'

  def stringify_keys(hash)
    hash.map { |k, v| [k.to_s, v] }.to_h
  end

  def task(extension_requests: nil, custom_attributes: nil, **_kwargs)
    data = {}
    if File.exist?(CSR_ATTRIBUTES_FILE)
      data = YAML.safe_load(File.read(CSR_ATTRIBUTES_FILE))
    end
    if extension_requests
      extension_requests = stringify_keys(extension_requests)
      data['extension_requests'] = {} if !data.keys.include?('extension_requests')
      data['extension_requests'].merge!(extension_requests)
    end
    if custom_attributes
      custom_attributes = stringify_keys(custom_attributes)
      data['custom_attributes'] = {} if !data.keys.include?('custom_attributes')
      data['custom_attributes'].merge!(custom_attributes)
    end

    File.write(CSR_ATTRIBUTES_FILE, data.to_yaml)

    result = { data: data }
    result.to_json
  end
end

SetCsrAttributes.run if __FILE__ == $PROGRAM_NAME
