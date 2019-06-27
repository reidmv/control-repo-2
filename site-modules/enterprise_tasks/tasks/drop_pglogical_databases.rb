#!/opt/puppetlabs/puppet/bin/ruby

require_relative '../../ruby_task_helper/files/task_helper.rb'
require 'json'
require 'open3'
require 'erb'

def get_databases
  ['pe-activity', 'pe-classifier', 'pe-orchestrator', 'pe-rbac']
end

def get_template
  %{
su -s /bin/bash - pe-postgres -c "/opt/puppetlabs/server/bin/psql" <<EOF
SELECT pg_drop_replication_slot(slot_name) FROM pg_replication_slots;
UPDATE pg_database SET datallowconn = 'false'
  WHERE datname IN <%= '(' + @databases.map{ |database| "'" + database + "'" }.join(', ') + ');' %>
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
  WHERE datname IN <%= '(' + @databases.map{ |database| "'" + database + "'" }.join(', ') + ');' %>
<% for @database in @databases %><%='DROP DATABASE IF EXISTS ' + '"' + @database + '";' %>
<% end %>EOF
   }
end

class PostgresDropDatabaseCommand
  include ERB::Util
  attr_accessor :databases, :template

  def initialize(databases, template)
    @databases = databases
    @template = template
  end

  def render
    ERB.new(@template).result(binding)
  end
end

class DropPGLogicalDatabases < TaskHelper
  def task(host: nil, **_kwargs)
    host, = Open3.capture2e('hostname -f') if !host

    output, status = Open3.capture2e('/opt/puppetlabs/bin/puppet resource service pe-postgresql ensure=running')
    raise TaskHelper::Error.new("Failed to start pe-postgresql service on host #{host}", 'puppetlabs.hafailover/restart-postgres-failed', output) if !status.exitstatus.zero?

    postgres_command = PostgresDropDatabaseCommand.new(get_databases, get_template).render
    output, status = Open3.capture2e(postgres_command)
    raise TaskHelper::Error.new("Failed to drop pglogical datbases on host #{host}", 'puppetlabs.hafailover/drop-pglogical-databases-failed', output) if !status.exitstatus.zero?

    output, status = Open3.capture2e('/opt/puppetlabs/bin/puppet resource service pe-postgresql ensure=stopped')
    raise TaskHelper::Error.new("Failed to stop pe-postgresql service on host #{host}", 'puppetlabs.hafailover/restart-postgres-failed', output) if !status.exitstatus.zero?

    result = { _output: output }
    result.to_json
  end
end

DropPGLogicalDatabases.run if __FILE__ == $PROGRAM_NAME
