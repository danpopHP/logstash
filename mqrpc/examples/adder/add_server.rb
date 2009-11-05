require 'mqrpc'
require 'add_message'

class Adder < MQRPC::Agent
  def AddRequestHandler(request)
    puts "Got #{request.class.name} for #{request.numbers.inspect}"
    sum = request.numbers.reduce { |a,b| a + b }

    # Make the response
    response = AddResponse.new(request)
    response.sum = sum
    yield response
  end # def AddRequestHandler

  def run
    # listen for messages on the 'adder' queue
    subscribe("adder")
    super
  end
end # class Adder < MQRPC::Agent

config = MQRPC::Config.new({ "mqhost" => "dev.rabbitmq.com" })
adder = Adder.new(config)
adder.run
