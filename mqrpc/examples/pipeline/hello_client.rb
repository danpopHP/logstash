require 'rubygems'
require 'mqrpc'
require 'hello_message'

class Client < MQRPC::Agent
  def run
    loop do
      request = HelloRequest.new
      sendmsg("hello", request)
    end
  end # def run

  handle HelloResponse, :HelloResponseHandler
  def HelloResponseHandler(message)
    puts "client got hello response: #{message}"
  end # def HelloResponseHandler
end # class Client< MQRPC::Agent

MQRPC::logger.level = Logger::DEBUG
config = MQRPC::Config.new({ "mqhost" => "localhost" })
client = Client.new(config)
client.run
