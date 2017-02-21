#!/usr/bin/env ruby

class AgentPGExeption < StandardError

end

class AgentPG

    attr_accessor :conf

    def initialize
        @conf = {}
    end

	def bootstrap

	end

	def slave_bootstrap

	end

	def master?

	end

	def wait_consul

	end

	def checks

	end

	def poolchecks

	end

end
