#!/usr/bin/env ruby

class Poll
  require 'logger'
  require 'redborder-consul-connector'

  def initialize(master_key = "postgresql/master", 
                 master_ttl = "60s",
                 service_name = "postgresql", 
                 master_service_name = "postgresql-master",
                 check_script_path = "/usr/lib/redborder/bin/pg_health_check.sh", 
                 master_check_script_path = "/usr/lib/redborder/bin/pg_master_health_check.sh")
      @consul = RedborderConsulConnector.new
      @master_key = master_key
      @master_ttl = master_ttl
      @service_name = service_name
      @master_service_name = master_service_name
      @node_name = @consul.get_self()["Config"]["NodeName"]
      @current_master = ""
      @check_script_path = check_script_path
      @master_check_script_path = master_check_script_path
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::DEBUG
  end

  ################
  # MAIN METHODS
  ################

  def polling_process(interval)
    wait_for_service_registration
    checks_registration
    while true
      @logger.debug("Looping..")
      kv_checks if psql_checks
      sleep interval
    end
  end 

  def psql_checks()
    @logger.debug("Calling psql_checks..")
    stop = false
    if @consul.leader? @master_key
      @logger.debug("Im the leader..")
      @current_master=get_current_master
      if psql_check_status and psql_master_check_status
        @logger.debug("Updating session ttl because the check is ok and the master check also..")
        update_session_ttl
      else
        @logger.debug("Deleting master kv..")
        delete_master_kv
		delete_master_tag
        checks_registration
        stop = true
      end
    elsif !psql_check_status
      stop = true
    end
    return !stop
    #stop_services if stop
  end

  def kv_checks()
    @logger.debug("Calling kv_checks..")
    if (get_current_master != @current_master) or get_current_master.nil?
      master_election if get_current_master.nil?
      if master?
        @current_master = get_current_master
        master_promotion
      elsif !get_current_master.nil?
        @current_master = get_current_master
        resync_with_master
      end
      checks_registration
    end   
  end

  ####################################################################
  # UTIL METHODS
  ####################################################################

  def master?
    return @consul.leader?(@master_key)
  end
  
  def update_session_ttl()
    return @consul.renew_session(@consul.get_kv_session_id(@master_key))
  end

  def master_election()
    @consul.leader_election(@master_key, @master_ttl)
  end

  def delete_master_kv()
    return destroy_master_session
  end

  def destroy_master_session()
    return @consul.destroy_session(@consul.get_kv_session_id(@master_key))
  end

  def stop_services()
    system("systemctl stop postgresql")
  end

  def get_current_master()
    return @consul.get_current_leader(@master_key)
  end

  def get_pg_service_id()
    return "#{@service_name}-#{@node_name}"
  end

  def get_pg_master_service_id()
    return "#{@master_service_name}-#{@node_name}"
  end

  def get_pg_check_id()
    return "#{@service_name}-#{@node_name}-check"
  end

  def get_pg_master_check_id()
    return "#{@master_service_name}-#{@current_master}-check"
  end

  def delete_master_service()
    
  end

  def wait_for_service_registration(sleep_time = 10)
    while !check_service_registered
      sleep sleep_time
    end
  end

  def check_service_registered
    register = true
		begin
			register = !@consul.get_service(get_pg_service_id).empty?
		rescue
			register = false
		end
		return register
  end

  def checks_registration    
    return unless check_service_registered
    @logger.debug("Calling checks_registration, node_name is #{@node_name}")
    #Master check registration
    if master?
      @logger.debug("Calling @consul.register_check_script (master)")
      # params: id,name, service_id, script_path, interval, deregister_ttl
      @consul.register_check_script(
          "#{@master_service_name}-#{@node_name}-check", 
          "#{@master_service_name}",
          "#{@service_name}-#{@node_name}", 
          @master_check_script_path, 
          "30s", 
          "60s"
      )
    else
      @consul.deregister_check_script("#{@master_service_name}-#{@node_name}-check")
    end

    @logger.debug("Calling @consul.register_check_script (common)")
    #Common check registration
    @consul.register_check_script(
      "#{@service_name}-#{@node_name}-check", 
      "#{@service_name}",
      "#{@service_name}-#{@node_name}", 
      @check_script_path, 
      "30s", 
      "60s"
    )
    sleep 30
  end

  def psql_check_status()
    @logger.debug("Calling @consul.get_agent_checks with #{get_pg_check_id()}")
    check = @consul.get_agent_checks[get_pg_check_id()]

    @logger.debug("psql_check_status is #{check}")
    return (!check.nil? and check["Status"] == "passing") ? true : false
  end

  def psql_master_check_status()
    @logger.debug("Calling @consul.get_node_check_health with #{get_current_master()} and #{get_pg_master_check_id()}")
    check = @consul.get_node_check_health(get_current_master(), get_pg_master_check_id())

    @logger.debug("psql_master_check_status is #{check}")
    return (!check.nil? and check.first and check.first["Status"] == "passing") ? true : false
  end

  # Deletes "master" tag for all
  def delete_master_tag()
	service = @consul.get_service(get_pg_service_id)
    return if service.empty?
    @consul.register_agent_service(service["Service"], service["ID"], service["Address"], service["Port"])
  end

  # Add master tag by re-registering with "master" tag
  def add_master_tag()
    service = @consul.get_service(get_pg_service_id)
    return if service.empty?
    @consul.register_agent_service(service["Service"],service["ID"], service["Address"], service["Port"], ["master"])
  end


  def master_promotion()
    #TODO
    #Delete master service (catalog)
    #Register new master service (agent)
	  add_master_tag
    #Register check for master service
    #promotion psql   
    system("touch /tmp/postgresql.trigger")
    system("sed -i '/^primary_conninfo/d' /var/lib/pgsql/data/postgresql.conf")
    system("sed -i '/^promote_trigger_file/d' /var/lib/pgsql/data/postgresql.conf")
  end

  def resync_with_master()
	delete_master_tag
	#Wait master to be ok
    while !psql_master_check_status
      sleep 10
    end
    #Resync with new master
    result=system("/usr/lib/redborder/bin/rb_sync_from_master.sh #{@current_master}")
    @current_master=nil if !result
  end

end
