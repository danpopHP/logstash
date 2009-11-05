require 'mqrpc'
require 'add_message'

class AdderClient < MQRPC::Agent
  def run
    Thread.new { myrunner }
    super
  end # def

  def myrunner
    operations = []
    0.upto(20) do |i|
      request = AddRequest.new
      request.numbers = [rand, rand, rand, rand]
      op = sendmsg("adder", request) do |msg|
        puts "Got result: #{msg.sum}"
      end
      operations << op
    end

    # Now that we've fired all the operations, wait for them all
    # to finish.
    puts "Waiting on all operations..."
    operations.each do |op|
      op.wait_until_finished
    end

    # Close up.
    close
  end
end # class AdderClient < MQRPC::Agent

config = MQRPC::Config.new({ "mqhost" => "dev.rabbitmq.com" })
adder = AdderClient.new(config)
adder.run
