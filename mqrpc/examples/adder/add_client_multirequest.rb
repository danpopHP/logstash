dir = File.dirname(__FILE__)
$:.unshift("#{dir}/../../lib") if File.directory?("#{dir}/.svn")

require 'mqrpc'
require 'add_message'

MQRPC::logger.level = Logger::DEBUG


class AdderClient < MQRPC::Agent
  def run
    Thread.new { myrunner }
    super
  end # def

  def myrunner
    operations = []
    0.upto(80) do |i|
      request = AddRequest.new
      request.numbers = [rand, rand, rand, rand]
      op = sendmsg("adder", request) do |msg|
        MQRPC::logger.info "Got result #{request.id}: #{msg.sum}"
      end
      operations << op
      MQRPC::logger.info "Operation sent: #{operations.length}"
    end

    # Now that we've fired all the operations, wait for them all
    # to finish.
    MQRPC::logger.info "Waiting on all operations..."
    donecount = 0 
    operations.each do |op|
      MQRPC::logger.info "Waiting on #{operations.length - donecount} ops...>"
      op.wait_until_finished
      donecount +=1
    end

    # Close up.
    close
  end
end # class AdderClient < MQRPC::Agent

config = MQRPC::Config.new({ "mqhost" => "localhost" })
adder = AdderClient.new(config)
adder.run
