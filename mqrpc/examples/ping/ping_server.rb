
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
    Thread.new { subber }
    super
  end

  def subber
    sleep 5
    loop do
      unsubscribe("pingme")
      sleep 1
      subscribe("pingme")
      sleep 1
    end
  end
end

MQRPC::logger.level = Logger::DEBUG
config = MQRPC::Config.new({ "mqhost" => "localhost" })
server = PingServer.new(config)
server.run

