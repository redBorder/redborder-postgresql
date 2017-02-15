#!/usr/bin/env ruby


# This is the service postgres script to provide
# integration with consul and Master-MultiSlave

require 'yaml'
require 'pg'
require "#{ENV['RBLIB']}/agent_pg_lib.rb"

CONFFILE = "/etc/redborder/agent_pg.yml"

agent = AgentPG.new

if File.file?(CONFFILE)
	agent.conf = YAML.load:file(CONFFILE)
else
	# default values
	agent.conf = {
		"pgdata" => "/var/lib/pgsql/9.6/data",
		"unitfile" => "postgresql-9.6",
		"database" => "postgres",
		"user" => "postgres",
		"password" => "",
		"bootstrap" => false
	}
end



if conf["bootstrap"]
	# bootstrap process
	bootstrap(conf)
end

# Now it is time to wait for consul

wait_consul












exit 0

# Starting directly when the DB is configured
# no initdb is necessary by now

# first check if postgres has been started out-of-the-box
# If it has been started, check if I am master via select, else via conf

if system("systemctl status #{conf["unitfile"]}")
	# Note: exit code 0 (true) means service is up, other values means fialed, inactive, or other status
	# Service postgres is up and running? -> connect and request
	begin
		con = PG.connect :dbname => conf["database"], :user => conf["user"], :host => "127.0.0.1"
	rescue PG::Error => e
		puts "Error connecting to PostgreSQL via localhost, user #{conf["user"]}"
		exit(1)
	end
	res = con.exec("SELECT pg_current_xlog_location();")
else
	if File.file?("#{conf["pgdata"]}/recovery.conf")
		# file recovery.conf exist, slave configuration
		conf["mode"]="slave"
	else
		conf["mode"]="master"
	end
	# start service?
end