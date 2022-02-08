#!/usr/bin/env ruby

class AgentPGExeption < StandardError

end

class AgentPG
    require 'yaml'
    require 'logger'
    require 'redborder-consul-connector'
    require '/usr/lib/redborder/lib/poll_lib.rb'
    #require 'pg'

    attr_accessor :conf

    def initialize()
        @conf = {}
        @default_conf = {
            "pgdata"    => "/var/lib/pgsql/data",
            "unitfile"  => "postgresql",
            "database"  => "postgres",
            "user"      => "postgres",
            "password"  => "redborder",
            "service_name" => "postgresql",
            "master_service_name" => "postgresql-master",
            "master_kv" => "postgresql/master",
            "master_ttl" => "60s",
            "master_check_script_path" => "/usr/lib/redborder/bin/pg_master_health_check.sh",
            "check_script_path" => "/usr/lib/redborder/bin/pg_health_check.sh",
            "bootstrap" => true,
            "log_level" => Logger::DEBUG
        }

        @logger = Logger.new(STDOUT)
        @consul = RedborderConsulConnector.new
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
            #system("systemctl postgresql start")

        end
    end

    def slave_bootstrap
        #TODO!!!
        @logger.debug("Execute slave_bootstrap")
        #system("systemctl postgresql start")
    end

    ###########################################
    # CONSUL WAITING METHODS
    ###########################################

    def consul_connect
        @logger.debug("Execute consul_connect")

        @logger.debug("Waiting for consul connectivity...")        
        @consul.wait_for_connectivity

        need_to_exit = false
        until need_to_exit
            if @consul.get_kv_value(@conf["master_kv"]).nil?
                @logger.debug("There is no master key...")        
                if @conf["bootstrap"]
                    @logger.debug("Bootstrap is true so lets leader election...")        
                    election_result = @consul.leader_election(@conf["master_kv"], @conf["master_ttl"])
                    @logger.debug("Election result: #{election_result} with master_kv: #{@conf['master_kv']} and master_ttl: #{@conf['master_ttl']}")        
                      
                    need_to_exit = true
                else
                    sleep 10
                end
            else
                @logger.debug("There is master key so I exit...")        
                need_to_exit = true
            end
        end
    end

    def master?
        @logger.debug("Execute master?")
        return @consul.leader?(@conf["master_kv"])
    end

    def checks_registration
        node_name = @consul.get_self()["Config"]["NodeName"]
        
        @logger.debug("Calling checks_registration, node_name is #{node_name}")
        #Master check registration
        if master?
            @logger.debug("Calling @consul.register_check_script (master)")
            # params: id,name, service_id, script_path, interval, deregister_ttl
            @consul.register_check_script(
                "#{@conf["master_service_name"]}-#{node_name}-check", 
                "#{@conf["master_service_name"]}",
                "#{@conf["service_name"]}-#{node_name}", 
                @conf["master_check_script_path"], 
                "30s", 
                "60s"
            )
        end

        @logger.debug("Calling @consul.register_check_script (common)")
        #Common check registration
        @consul.register_check_script(
            "#{@conf["service_name"]}-#{node_name}-check", 
            "#{@conf["service_name"]}",
            "#{@conf["service_name"]}-#{node_name}", 
            @conf["check_script_path"], 
            "30s", 
            "60s"
        )

    end

    def pollchecks
        poller = Poll.new(@conf["master_kv"], @conf["master_ttl"],
                          @conf["service_name"], @conf["master_service_name"],
                          @conf["check_script_path"], @conf["master_check_script_path"])
        poller.polling_process(60)
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

