require 'spec_helper'

describe 'enterprise_tasks::generate_pe_conf' do
  let(:roles) do
    {
      'master' => 'primary.net',
    }
  end

  it do
    is_expected.to run.with_params(roles).and_return(
      <<~PECONF
        {
          "puppet_enterprise::puppet_master_host": "primary.net"
        }
      PECONF
    )
  end

  it 'ignores duplicate database' do
    roles = {
      'master' => 'primary.net',
      'database' => 'primary.net',
    }
    is_expected.to run.with_params(roles).and_return(
      <<~PECONF
        {
          "puppet_enterprise::puppet_master_host": "primary.net"
        }
      PECONF
    )
  end

  it 'splits database' do
    roles = {
      'master'   => 'primary.net',
      'database' => 'database.net',
    }
    is_expected.to run.with_params(roles).and_return(
      <<~PECONF
        {
          "puppet_enterprise::puppet_master_host": "primary.net",
          "puppet_enterprise::database_host": "database.net"
        }
      PECONF
    )
  end

  it 'adds password' do
    is_expected.to run.with_params({ 'master' => 'primary.net' }, 'password').and_return(
      <<~PECONF
        {
          "puppet_enterprise::puppet_master_host": "primary.net",
          "console_admin_password": "password"
        }
      PECONF
    )
  end

  it 'adds parameters' do
    is_expected.to run.with_params({ 'master' => 'primary.net' }, nil, { 'foo' => 'bar' }).and_return(
      <<~PECONF
        {
          "puppet_enterprise::puppet_master_host": "primary.net",
          "foo": "bar"
        }
      PECONF
    )
  end
end
