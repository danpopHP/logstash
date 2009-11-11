require 'rubygems'
require 'mqrpc'
require 'thread'
require 'hello_message'

MQRPC::logger.level = Logger::DEBUG

class HelloPiper < MQRPC::Agent
  handle HelloRequest, :HelloRequestHandler
  handle HelloResponse, :noop
  pipeline "hello", "hello-two"

  def initialize(*args)
    super
    @outqueue = Queue.new
  end

  def noop(request)
    # nothing
  end
  
  def HelloRequestHandler(request)
    #puts "piper: got #{request.class.name}"

    @outqueue << ["hello-two", HelloRequest.new]

    response = HelloResponse.new(request)
    yield response

  end # def AddRequestHandler

  def run
    # listen for messages on the 'adder' queue
    subscribe("hello")
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
