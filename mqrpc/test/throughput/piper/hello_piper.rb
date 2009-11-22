dir = File.dirname(__FILE__)
$:.unshift("#{dir}/../../../lib") if File.directory?("#{dir}/.svn")

require 'rubygems'
require 'mqrpc'
require 'mqrpc/functions/ping'
require 'thread'
require 'hello_message'

class HelloPiper < MQRPC::Agent
  handle HelloRequest, :HelloRequestHandler
  handle HelloResponse, :noop
  pipeline "hello", "hello2"

  handle MQRPC::Messages::PingRequest, :PingRequestHandler

  def PingRequestHandler(request)
    MQRPC::logger.debug "received PingRequest (#{request.pingdata})"
    response = MQRPC::Messages::PingResponse.new(request)
    response.id = request.id
    response.pingdata = request.pingdata
    yield response
  end


  def initialize(*args)
    super
    @outqueue = Queue.new
  end

  def noop(request)
    # nothing
  end
  
  def HelloRequestHandler(request)
    #puts "piper: got #{request.class.name}"

    newreq = HelloRequest.new
    newreq.delayable = request.delayable
    @outqueue << ["hello2", newreq]

    response = HelloResponse.new(request)
    yield response

  end # def HelloRequest

  def run
    # listen for messages on the 'adder' queue
    subscribe("hello")
    subscribe("pingme")
    start_sender
    super
  end

  def start_sender
    Thread.new do
      loop do
        destination, request = @outqueue.pop
        sendmsg(destination, request)
      end
    end
  end
end # class HelloPiper < MQRPC::Agent

#MQRPC::logger.level = Logger::DEBUG
config = MQRPC::Config.new({ "mqhost" => "localhost" })
piper = HelloPiper.new(config)
piper.run
