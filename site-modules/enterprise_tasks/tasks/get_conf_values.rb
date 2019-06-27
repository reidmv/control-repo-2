#!/opt/puppetlabs/puppet/bin/ruby

require 'hocon'
require 'json'

require_relative '../../ruby_task_helper/files/task_helper.rb'

class GetConfValues < TaskHelper
  def task(file:, keys:, **_kwargs)
    result = {}
    if keys.is_a?(String)
      keys = [keys]
    end
    if !File.exist?(file)
      raise TaskHelper::Error.new("File not found: #{file}", 'puppetlabs.get_conf_values/file_not_found', file)
    end

    conf = Hocon.load(file)
    keys.each do |k|
      result[k.to_sym] = if conf.keys.include?(k)
                           conf[k]
                         else
                           nil
                         end
    end
    result[:status] = :success
    result.to_json
  end
end

GetConfValues.run if __FILE__ == $PROGRAM_NAME
