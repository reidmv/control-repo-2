#!/opt/puppetlabs/puppet/bin/ruby

require 'hocon/parser/config_document_factory'
require 'hocon/config_value_factory'
require 'json'

require_relative '../../ruby_task_helper/files/task_helper.rb'

class AddModifyConfKeys < TaskHelper
  def task(file:, hash:, **_kwargs)
    result = {}
    if file.nil? || file.empty? || hash.nil? || hash.empty?
      raise TaskHelper::Error.new('file and hash arguments must have values', 'puppetlabs.add_modify_conf_keys/invalid_value', nil)
    end
    if !File.exist?(file)
      raise TaskHelper::Error.new("File not found: #{file}", 'puppetlabs.add_modify_conf_keys/file_not_found', file)
    end
    conf = Hocon::Parser::ConfigDocumentFactory.parse_file(file)
    hash.each do |k, v|
      key = "\"#{k}\""
      value = if v.is_a?(String)
                "\"#{v}\""
              else
                v.to_s
              end
      conf = conf.set_value(key, value)
    end
    File.open(file, 'w') { |f| f << conf.render }
    result[:status] = :success
    result.to_json
  end
end

AddModifyConfKeys.run if __FILE__ == $PROGRAM_NAME
