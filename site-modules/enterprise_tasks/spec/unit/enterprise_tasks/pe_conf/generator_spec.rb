require 'spec_helper'
require 'enterprise_tasks/pe_conf/generator'

# rubocop:disable Style/HashSyntax
describe 'enterprise_tasks::pe_conf::generator' do
  G = EnterpriseTasks::PeConf::Generator

  it do
    expect { G.new(roles: nil) }.to raise_error(ArgumentError, /Expected a roles hash/)
  end

  it do
    expect { G.new(roles: { foo: 'bar' }) }.to raise_error(ArgumentError, /No master role given/)
  end

  context '#rule?' do
    it 'finds a string' do
      expect(G.new(roles: { 'master' => 'master.net' }).role?('master')).to eq(true)
      expect(G.new(roles: { :master  => 'master.net' }).role?('master')).to eq(true)
    end

    it 'finds a symbol' do
      expect(G.new(roles: { :master  => 'master.net' }).role?(:master)).to eq(true)
      expect(G.new(roles: { 'master' => 'master.net' }).role?(:master)).to eq(true)
    end

    it 'returns false if not found' do
      expect(G.new(roles: { :master  => 'master.net' }).role?('foo')).to eq(false)
    end
  end

  context '#unique_role?' do
    it do
      expect(G.new(roles: { :master  => 'master.net' }).unique_role?('master')).to eq(true)
    end

    it do
      expect(G.new(roles: { :master  => 'master.net', :database => 'database.net' }).unique_role?('database', 'master')).to eq(true)
    end

    it do
      expect(G.new(roles: { :master  => 'master.net', :database => 'database.net' }).unique_role?('database', 'master', 'puppetdb')).to eq(true)
    end

    it do
      expect(G.new(roles: {
        :master   => 'master.net',
        :puppetdb => 'puppetdb.net',
        :database => 'database.net',
      }).unique_role?('puppetdb', 'master')).to eq(true)
    end

    it 'has unique puppetdb but not database role' do
      g = G.new(roles: {
        :master   => 'master.net',
        :puppetdb => 'puppetdb.net',
        :database => 'puppetdb.net',
      })
      expect(g.unique_role?('database', 'master', 'puppetdb')).to eq(false)
      expect(g.unique_role?('puppetdb', 'master')).to eq(true)
    end

    it 'ignores duplicate roles' do
      g = G.new(roles: {
        :master   => 'master.net',
        :puppetdb => 'master.net',
        :database => 'master.net',
      })
      expect(g.unique_role?('puppetdb', 'master')).to eq(false)
      expect(g.unique_role?('database', 'master', 'puppetdb')).to eq(false)
    end
  end

  context '#to_json' do
    it do
      expect(G.new(roles: { master: 'master.net' }).to_json).to eq(
        <<~PECONF
          {
            "puppet_enterprise::puppet_master_host": "master.net"
          }
        PECONF
      )
    end

    it do
      expect(G.new(roles: { master: 'master.net' }, password: 'password').to_json).to eq(
        <<~PECONF
          {
            "puppet_enterprise::puppet_master_host": "master.net",
            "console_admin_password": "password"
          }
        PECONF
      )
    end

    it 'builds a mono-db split' do
      expect(G.new(roles: { master: 'master.net', database: 'database.net' }).to_json).to eq(
        <<~PECONF
          {
            "puppet_enterprise::puppet_master_host": "master.net",
            "puppet_enterprise::database_host": "database.net"
          }
        PECONF
      )
    end

    it 'builds a legacy split' do
      expect(G.new(roles: { master: 'master.net', puppetdb: 'puppetdb.net', console: 'console.net' }).to_json).to eq(
        <<~PECONF
          {
            "puppet_enterprise::puppet_master_host": "master.net",
            "puppet_enterprise::puppetdb_host": "puppetdb.net",
            "puppet_enterprise::console_host": "console.net"
          }
        PECONF
      )
    end

    it 'builds a legacy split with db' do
      expect(G.new(roles: { master: 'master.net', puppetdb: 'puppetdb.net', database: 'database.net', console: 'console.net' }).to_json).to eq(
        <<~PECONF
          {
            "puppet_enterprise::puppet_master_host": "master.net",
            "puppet_enterprise::database_host": "database.net",
            "puppet_enterprise::puppetdb_host": "puppetdb.net",
            "puppet_enterprise::console_host": "console.net"
          }
        PECONF
      )
    end

    it do
      additional_parameters = {
        'puppet_enterprise::postgres_version_override' => '11',
      }
      expect(G.new(roles: { master: 'master.net' }, other_parameters: additional_parameters).to_json).to eq(
        <<~PECONF
          {
            "puppet_enterprise::puppet_master_host": "master.net",
            "puppet_enterprise::postgres_version_override": "11"
          }
        PECONF
      )
    end
  end
end
