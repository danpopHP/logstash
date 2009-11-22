dir = File.dirname(__FILE__)
$:.unshift("#{dir}/../../../lib") if File.directory?("#{dir}/.svn")

require 'rubygems'
require 'mqrpc'
require 'hello_message'


class HelloServer < MQRPC::Agent
  handle HelloRequest, :HelloRequestHandler
  
  def HelloRequestHandler(request)
    response = HelloResponse.new(request)
    yield response
  end # def AddRequestHandler

  def run
    subscribe("hello")
    super
  end
end # class HelloServer < MQRPC::Agent

#MQRPC::logger.level = Logger::DEBUG
config = MQRPC::Config.new({ "mqhost" => "localhost" })
server = HelloServer.new(config)
server.run
