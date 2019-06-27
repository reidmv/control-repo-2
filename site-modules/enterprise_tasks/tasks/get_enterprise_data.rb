#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'

class GetEnterpriseData < TaskHelper
  def task(_)
    enterprise_conf_dir = '/etc/puppetlabs/enterprise/conf.d'
    files = ["#{enterprise_conf_dir}/user_data.conf", Dir.glob("#{enterprise_conf_dir}/nodes/*")].flatten
    contents = files.each_with_object({}) do |path, hash|
      hash[path] = File.read(path)
    end
    result = { enterprise_data: contents }
    result.to_json
  end
end

GetEnterpriseData.run if __FILE__ == $PROGRAM_NAME
