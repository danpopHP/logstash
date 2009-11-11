require 'rubygems'
require 'mqrpc'
require 'hello_message'

MQRPC::logger.level = Logger::DEBUG

class HelloServer < MQRPC::Agent
  handle HelloRequest, :HelloRequestHandler
  
  def HelloRequestHandler(request)
    puts "server: got #{request.class.name}"

    # Be slow, so the pipeline gets stuck.
    #sleep(0.5)

    response = HelloResponse.new(request)
    yield response
  end # def AddRequestHandler

  def run
    # listen for messages on the 'adder' queue
    subscribe("hello-two")
    super
  end
end # class HelloServer < MQRPC::Agent

config = MQRPC::Config.new({ "mqhost" => "localhost" })
server = HelloServer.new(config)
server.run
