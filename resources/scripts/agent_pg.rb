#!/usr/bin/env ruby


# This is the service postgres script to provide
# integration with consul and Master-MultiSlave

require 'yaml'
require 'pg'
require "#{ENV['RBLIB']}/agent_pg_lib.rb"

#TODO: get CONFFILE path from stdin
conf_file = "/etc/redborder/agent_pg.yml"

agent = AgentPG.new
begin
	agent.config_from_file(conf_file)
	agent.master_bootstrap
	agent.consul_connect
	agent.slave_bootstrap if !agent.master?
	agent.checks_registration


rescue

ensure

end
