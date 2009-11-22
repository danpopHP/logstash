dir = File.dirname(__FILE__)
$:.unshift("#{dir}/../../../lib") if File.directory?("#{dir}/.svn")

require 'rubygems'
require 'mqrpc'
require 'hello_message'

class Client < MQRPC::Agent
  attr_accessor :count
  attr_accessor :start

  def run
    @start = Time.now
    @count = 0
    loop do
      request = HelloRequest.new
      request.delayable = true
      sendmsg("hello", request)
    end
  end # def run

  handle HelloResponse, :HelloResponseHandler

  def HelloResponseHandler(message)
    if @count % 1000 == 0
      puts "Count: #{@count}"
    end
    @count += 1
  end # def HelloResponseHandler
end # class Client< MQRPC::Agent

config = MQRPC::Config.new({ "mqhost" => "localhost" })
client = Client.new(config) 
begin
  Timeout.timeout((ARGV[0].to_i or 20), nil) { client.run }
rescue Timeout::Error
  # ignore
end

duration = Time.now - client.start
puts "Got #{client.count} responses in #{duration} seconds"
puts "Rate: #{client.count / duration}/sec"
