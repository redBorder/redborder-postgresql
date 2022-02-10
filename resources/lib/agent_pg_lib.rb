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
  end

  def master?
    @logger.debug("Execute master?")
    return @consul.leader?(@conf["master_kv"])
  end

  def pollchecks
    poller = Poll.new(@conf["master_kv"], @conf["master_ttl"],
                      @conf["service_name"], @conf["master_service_name"],
                      @conf["check_script_path"], @conf["master_check_script_path"])
    poller.polling_process(60)
  end

end #class AgentPG

