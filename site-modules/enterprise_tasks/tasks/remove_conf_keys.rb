#!/opt/puppetlabs/puppet/bin/ruby

require 'hocon/parser/config_document_factory'
require 'hocon/config_value_factory'
require 'json'

require_relative '../../ruby_task_helper/files/task_helper.rb'

class RemoveConfKeys < TaskHelper
  def task(file:, keys:, **_kwargs)
    result = {}
    if file.nil? || file.empty? || keys.nil? || keys.empty?
      raise TaskHelper::Error.new('file and keys arguments must have values', 'puppetlabs.remove_conf_keys/invalid_value', nil)
    end
    if keys.is_a?(String)
      keys = [keys]
    end
    if !File.exist?(file)
      raise TaskHelper::Error.new("File not found: #{file}", 'puppetlabs.remove_conf_keys/file_not_found', file)
    end
    conf = Hocon::Parser::ConfigDocumentFactory.parse_file(file)
    keys.each { |k| conf = conf.remove_value("\"#{k}\"") }
    File.open(file, 'w') { |f| f << conf.render }
    result[:status] = :success
    result.to_json
  end
end

RemoveConfKeys.run if __FILE__ == $PROGRAM_NAME
