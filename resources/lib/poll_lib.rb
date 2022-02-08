#!/usr/bin/env ruby

class Poll
        require 'logger'
	require 'redborder-consul-connector'

	def initialize(master_key = "postgresql/master", master_ttl = "60s",
			service_name = "postgresql", master_service_name = "postgresql-master",
			check_script_path = "/usr/lib/redborder/bin/pg_health_check.sh", master_check_script_path = "/usr/lib/redborder/bin/pg_master_health_check.sh")
		@consul = RedborderConsulConnector.new
		@master_key = master_key
		@master_ttl = master_ttl
		@service_name = service_name
		@master_service_name = master_service_name
		@node_name = @consul.get_self()["Config"]["NodeName"]
		@current_master = ""
                @check_script_path = check_script_path
                @master_checK_script_path = master_check_script_path
                @logger = Logger.new(STDOUT)
                @logger.level = Logger::DEBUG
	end

	################
	# MAIN METHODS
	################

	def polling_process(interval)
		#@current_master = get_current_master
		checks_registration
                @logger.debug("Current master is #{@current_master}...")
		while true
                        @logger.debug("Looping..")
			psql_checks
			kv_checks
			sleep interval
		end
	end	

	def psql_checks()
                @logger.debug("Calling psql_checks..")
		stop = false
		if @consul.leader? @master_key
                        @logger.debug("Im the leader..")
	  		if psql_check_status and psql_master_check_status
                                @logger.debug("Updating session ttl because the check is ok and the master check also..")
				update_session_ttl
			else
                        @logger.debug("Deleting master kv..")
				delete_master_kv
				stop = true
			end
		elsif !psql_check_status
			stop = true
		end
		#stop_services if stop
	end

        def master?
          return @consul.leader?(@master_key)
        end

	def kv_checks()
        @logger.debug("Calling kv_checks..")
		if (get_current_master != @current_master) or get_current_master.nil?
			master_election	
			@current_master = get_current_master
			if master?
			  master_promotion
			else
			  resync_with_master
			end
			checks_registration
		end		
	end

	####################################################################
	# UTIL METHODS
	####################################################################
	
	def checks_registration       
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
		result = false
		check = @consul.get_agent_checks[get_pg_check_id()]
                @logger.debug("psql_check_status is #{check}")
		result = true if !check.nil? and check["Status"] == "passing"
		return result
	end

	def psql_master_check_status()
                @logger.debug("Calling @consul.get_agent_checks with #{get_pg_master_check_id()}")
		result = false
		check = @consul.get_agent_checks[get_pg_master_check_id()]
                @logger.debug("psql_master_check_status is #{check}")
		result = true if !check.nil? and check["Status"] == "passing"
		return result
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
		return "#{@master_service_name}-#{@node_name}-check"
	end

	def delete_master_service()
		
	end

	def master_promotion()
		#TODO
		#Delete master service (catalog)
		#Register new master service (agent)
		#Register check for master service
		#promotion psql		

		system("touch /tmp/postgresql.trigger")
	end

	def resync_with_master()
		#TODO
		#Wait master to be ok
		while !psql_master_check_status
			sleep 10
		end
		#Resync with new master
		system("/usr/lib/redborder/bin/rb_sync_from_master.sh #{@current_master}")
		
	end

end
