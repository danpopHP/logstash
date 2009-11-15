require 'rubygems'
require 'mqrpc'
require 'add_message'

class AdderClient < MQRPC::Agent
  def run
    request = AddRequest.new
    request.numbers = [10, 20, 30, 40]

    # send our request to the 'adder' queue
    # and run the given block for the response
    op = sendmsg("adder", request) do |msg|
      puts "Got result: #{msg.sum}"

      # Say we're done.
      close
    end
    super
  end # def
end # class AdderClient < MQRPC::Agent

MQRPC::logger.level = Logger::DEBUG
config = MQRPC::Config.new({ "mqhost" => "localhost" })
adder = AdderClient.new(config)
adder.run
