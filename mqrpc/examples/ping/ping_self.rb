#!/usr/bin/env ruby

dir = File.dirname(__FILE__)
$:.unshift("#{dir}/../../lib") if File.directory?("#{dir}/.svn")

require 'rubygems'
require 'mqrpc'
require 'mqrpc/messages/ping'


class PingServer < MQRPC::Agent
  #include MQRPC::Functions::Ping
  handle MQRPC::Messages::PingRequest, :PingRequestHandler

  def PingRequestHandler(request)
    MQRPC::logger.debug "received PingRequest (#{request.pingdata})"
    response = MQRPC::Messages::PingResponse.new(request)
    response.id = request.id
    response.pingdata = request.pingdata
    yield response

  end

  def run
    subscribe("pingme")
    @count = 0
    @time = Time.now
    Thread.new { pingself }
    super
  end

  def pingself
    loop do
      ping = MQRPC::Messages::PingRequest.new
      ping.delayable = true
      sendmsg("pingme", ping) do |msg| 
        #puts "Got: #{msg.inspect}"
        @count += 1
        duration = Time.now - @time
        if duration > 5
          puts "Rate; #{@count / duration.to_f}"
          @time = Time.now
          @count = 0
        end
      end
    end
  end
end

MQRPC::logger.level = Logger::DEBUG
config = MQRPC::Config.new({ "mqhost" => "localhost" })
server = PingServer.new(config)
server.run

