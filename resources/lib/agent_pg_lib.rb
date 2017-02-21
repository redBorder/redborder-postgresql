#!/usr/bin/env ruby

class AgentPGExeption < StandardError

end

class AgentPG
	require 'yaml'
	require 'logger'
	require 'redborder-consul-connector'
	#require 'pg'

    attr_accessor :conf

    def initialize()
        @conf = {}
        @default_conf = {
        	"pgdata" 	=> "/var/lib/psql/data",
        	"unitfile" 	=> "postgresql",
        	"database" 	=> "postgres",
        	"user" 		=> "postgres",
        	"master_kv" => "postgresql/master"
        	"master_ttl" => "60s" 
        	"password"	=> "",
        	"bootstrap" => false,
        	"log_level" => Logger::WARN
        }

        @logger = Logger.new(STDOUT)
        @consul = Consul_connector.new
        config_from_hash(@default_conf)

    end

	###########################################
	# CONFIGURATION MANAGEMENT METHODS
	###########################################
	
	def config_from_yaml(path = "")
		config_hash = {}
		config_hash = YAML.load_file(path) if File.file?(path)
		config_from_hash(config_hash)		
	end

	def config_from_hash(hash)
		@default_conf.each_key { |key|
			config_set(key, hash)
		}
		@logger.level = @conf["log_level"]
	end

	def config_set(key, hash)
		hash.has_key?(key) ? (@conf[key] = hash[key]) : (@conf[key] = @default_conf[key])
	end

	###########################################
	# BOOTSTRAP MANAGEMENT METHODS
	###########################################

	def master_bootstrap
		@logger.debug("Execute master_bootstrap")
		if @conf["bootstrap"]
			#TODO!!!
			System("systemctl postgresql start")
		end
	end

	def slave_bootstrap
		#TODO!!!
		@logger.debug("Execute slave_bootstrap")
		System("systemctl postgresql start")
	end

	###########################################
	# CONSUL WAITING METHODS
	###########################################

	def consul_connect
		@logger.debug("Execute consul_connect")
		@consul.wait_for_connectivity

		EXIT = false
		until EXIT
			if @consul.get_kv_value(@config["master_kv"]).nil?
				if @config["bootstrap"]
					@consul.leader_election(@config["master_kv"], @config["master_ttl"])
					EXIT = true
				else
					sleep 10
				end
			else
				EXIT = true
			end
		end
	end

	def master?
		return @consul.leader?(@config["master_kv"])
	end

	def wait_consul

	end

	def checks

	end

	def poolchecks



	end

end

# Connection example to database, and executin select that only works if it is master
#begin
#    con = PG.connect :dbname => conf["database"], :user => conf["user"], :host => "127.0.0.1"
#rescue PG::Error => e
#    puts "Error connecting to PostgreSQL via localhost, user #{conf["user"]}"
#    exit(1)
#end
#res = con.exec("SELECT pg_current_xlog_location();")

# Check if it is slave or master with database stopped
#if File.file?("#{conf["pgdata"]}/recovery.conf")
#        # file recovery.conf exist, slave configuration
#        conf["mode"]="slave"
#else
#        conf["mode"]="master"
#end

