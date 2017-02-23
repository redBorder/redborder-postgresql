#!/usr/bin/env ruby

class Poll

	require 'consul-connector.rb'

	def initialize(master_key = "postgresql/master", master_ttl = "60s"
			service_name = "postgresql", master_service_name = "postgresql-master")
		@consul = Consul_connector.new
		@master_key = master_key
		@master_ttl = master_ttl
		@service_name = service_name
		@master_service_name = master_service_name
		@node_name = @consul.get_self()["Config"]["NodeName"]
		@current_master = ""
	end

	################
	# MAIN METHODS
	################

	def polling_process(interval)
		@current_master = @consul.get_current_master
		while true
			psql_checks
			kv_checks
			sleep interval
		end
	end	

	def psql_checks()
		stop = false
		if @consul.leader? @master_key
			if psql_check_status and psql_master_check_status
				update_session_ttl
			else
				delete_master_kv
				stop = true
			end
		elsif !psql_check_status
			stop = true
		end
		stop_services if stop
	end

	def kv_checks()
		if get_current_master != @current_master
			master_election
			if master?
				master_promotion
			else
				resync_with_master
			end
		end		
	end

	####################################################################
	# UTIL METHODS
	####################################################################
	
	def psql_check_status()
		result = false
		check = @consul.get_agent_checks[get_pg_check_id()]
		result = true if !check.nil? and check["Status"] == "passing"
		return result
	end

	def psql_master_check_status()
		result = false
		check = @consul.get_agent_checks[get_pg_master_check_id()]
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

	end

	def get_current_master()
		return @consul.get_current_leader(@master_key)
	end

	def get_pg_service_id()
		return "#{@node_name}-#{@service_name}"
	end

	def get_pg_master_service_id()
		return "#{@node_name}-#{@master_service_name}"
	end

	def get_pg_check_id()
		return "#{@node_name}-#{@service_name}-check"
	end

	def get_pg_master_check_id()
		return "#{@node_name}-#{@master_service_name}-check"
	end

	def delete_master_service()
		
	end

	def master_promotion()
		#TODO
		#Delete master service (catalog)
		#Register new master service (agent)
		#Register check for master service
		#promotion psql		
	end

	def resync_with_master()
		#TODO
		#Wait master to be ok
		#Resync with new master
	end

end