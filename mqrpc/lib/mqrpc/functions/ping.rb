require 'rubygems'
require 'mqrpc/messages/ping'

module MQRPC; module Functions; module Ping
  def PingRequestHandler(request)
    MQRPC::logger.debug "received PingRequest (#{request.pingdata})"
    response = MQRPC::Messages::PingResponse.new
    response.id = request.id
    response.pingdata = request.pingdata
    yield response
  end
end; end; end
