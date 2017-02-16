#!/usr/bin/env ruby

class Consul_connector
	
	require 'net/http'
	require 'uri'
	require 'json'
	require 'base64'

	def initialize(host = "localhost", port = "8500")
		@consul_host = host.to_s
		@consul_port = port.to_s		
	end

	####################################################################
	# High level operations
	####################################################################

	# SERVICE MANAGEMENT

	def get_services()
		path = "/v1/agent/services"
		response = JSON.parse(get_api(path).body)
	end

	def register_agent_service(name, id, address = "127.0.0.1", port = 8000, tags = [])
		result = false
		path = "/v1/agent/service/register"
		body = {
			"ID" => id,
			"Name" => name,
			"Address" => address,
			"Port" => port.to_i			
		}
		body["tags"] = tags if !tags.empty?
		if put_api(path, JSON.generate(body)).code == "200"
			result = true
		end
		return result
	end

	def deregister_agent_service(id)
		result = false
		path = "/v1/agent/service/deregister/#{id}"
		response = get_api(path)
		if response.code == "200"
			result = true
		end
	end

	def get_self()
		path = "/v1/agent/self"
		config = JSON.parse(get_api(path).body)
	end

	# SESSION MANAGEMENT

	def create_session(name = nil, ttl = "0s", behavior = "delete")
		session_id = nil
		path = "/v1/session/create"
		body = {}
		body["Behavior"] = behavior
		body["Name"] = name if !name.nil?
		body["TTL"] = ttl
		response = put_api(path, JSON.generate(body))
		if response.code == "200"
			session_id = JSON.parse(response.body)["ID"]
		end
		return session_id
	end

	def destroy_session(session_id)
		result = false
		path = "/v1/session/destroy/#{session_id}"
		response = put_api(path)
		if response.code == "200"
			result = true
		end
		return result
	end
	
	def renew_session(session_id)
		result = false
		path = "/v1/session/renew/#{session_id}"
		response = put_api(path)
		if response.code == "200"
			result = true
		end
		return result
	end

	# KEY/VALUE STORE MANAGEMENT

	def create_kv(key, value, options = "")
		status = false
		path = "/v1/kv/#{key}#{options}"
		response = put_api(path, value)
		if response.body.to_s == 'true'
			status = true
		end
		return status
	end

	def get_kv(key, options = "")
		result = nil
		path = "/v1/kv/#{key}"
		response = get_api(path)
		if response.code == "200"
			result = JSON.parse(response.body).at(0)
		end
		return result
	end

	def delete_kv(key)
		result = false
		path = "/v1/kv/#{key}"
		response = delete_api(path)
		if response.code == "200"
			result = true
		end
		return result
	end

	def get_kv_value(key)
		result = nil
		kv = get_kv(key)
		if !kv.nil?
			result = Base64.decode64(get_kv(key)["Value"])
		end
		return result
	end

	def get_kv_session_id(key)
		result = nil
		kv = get_kv(key)		
		if kv.has_key?("Session")
			result = kv["Session"]
		end
		return result
	end


	# LEADER ELECTION MANAGEMENT

	def leader_election(key, ttl = "0s")
		session_id = create_session(nil, ttl)
		node_name = get_self()["Config"]["NodeName"]
		status = create_kv(key, node_name,"?acquire=#{session_id}")
		if !status
			destroy_session(session_id)
		end
		return status
	end

	def get_current_leader(key)
		return get_kv_value(key)
	end

	def leader?(key)
		result = false
		self_node = get_self()["Config"]["NodeName"]
		leader_node = get_current_leader(key)
		if self_node.to_s == leader_node.to_s
			result = true
		end
		return result
	end

	# HEALTH CHECKS MANAGEMENT

	def register_check_script(id, name, service_id, script_path, interval = "30s", deregister_ttl = nil)
		result = false
		path = "/v1/agent/check/register"
		body = {
			"ID" => id,
			"Name" => name,
			"ServiceID" => service_id,			
			"Script" => script_path,
			"Interval" => interval,			
		}
		body["DeregisterCriticalServiceAfter"] = deregister_ttl if !deregister_ttl.nil?
		response = put_api(path, JSON.generate(body))
		if response.code == '200'
			result = true
		end
		return result
	end

	def deregister_check(check_id)
		result = false
		path = "/v1/agent/check/deregister/#{check_id}"
		if get_api(path).code == "200"
			result = true
		end
		return result
	end

	def get_agent_checks(check_id = nil)
		result = false
		path = "/v1/agent/checks"
		response = JSON.parse(get_api(path).body)
	end

	####################################################################
	# Api connector
	####################################################################

	def api_request(request, uri)
		response = Net::HTTP.start(uri.hostname, uri.port) do |http|
     		http.request(request)
   		end
   		return response
	end

	def get_api(path)
		uri = URI.parse("http://#{@consul_host}:#{@consul_port}#{path}")
		request = Net::HTTP::Get.new(uri)
		response = api_request(request, uri)
		return response
	end

	def post_api(path, body = "")
		uri = URI.parse("http://#{@consul_host}:#{@consul_port}#{path}")
		request = Net::HTTP::Post.new(uri)
		request.body = body
		response = api_request(request, uri)
		return response
	end

	def put_api(path, body = "")
		uri = URI.parse("http://#{@consul_host}:#{@consul_port}#{path}")
		request = Net::HTTP::Put.new(uri)
		request.body = body.to_s
		response = api_request(request, uri)
		return response
	end

	def delete_api(path)
		uri = URI.parse("http://#{@consul_host}:#{@consul_port}#{path}")
		request = Net::HTTP::Delete.new(uri)
		response = api_request(request, uri)
		return response
	end

end