dir = File.dirname(__FILE__)
$:.unshift("#{dir}/../../lib") if File.directory?("#{dir}/.svn")

require 'mqrpc'

class HelloRequest < MQRPC::RequestMessage
end

class HelloResponse < MQRPC::ResponseMessage
end
