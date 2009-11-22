dir = File.dirname(__FILE__)
$:.unshift("#{dir}/../../lib") if File.directory?("#{dir}/.svn")

require 'rubygems'
require 'mqrpc'
require 'mqrpc/functions/ping'
require 'thread'
require 'hello_message'

MQRPC::logger.level = Logger::DEBUG

class HelloPiper < MQRPC::Agent
  handle HelloRequest, :HelloRequestHandler
  handle HelloResponse, :noop
  pipeline "hello", "hello-two"

  #include MQRPC::Functions::Ping
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
    @outqueue << ["hello-two", newreq]

    response = HelloResponse.new(request)
    yield response

  end # def AddRequestHandler

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

config = MQRPC::Config.new({ "mqhost" => "localhost" })
piper = HelloPiper.new(config)
piper.run
