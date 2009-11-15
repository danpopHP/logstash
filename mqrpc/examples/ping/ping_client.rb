#!/usr/bin/env ruby
#
require 'rubygems'
require 'mqrpc'
require 'mqrpc/functions/ping'

class Client < MQRPC::Agent
  def run 
    loop do
      ping = MQRPC::Messages::PingRequest.new
      op = sendmsg(ARGV[0], ping) do |response|
        duration = Time.now.to_f - response.pingdata
        puts "PING #{duration}"
      end
    end
  end
end

MQRPC::logger.level = Logger::DEBUG
config = MQRPC::Config.new({ "mqhost" => "localhost" })
client = Client.new(config)
client.run

