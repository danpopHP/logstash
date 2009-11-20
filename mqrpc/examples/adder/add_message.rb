dir = File.dirname(__FILE__)
$:.unshift("#{dir}/../../lib") if File.directory?("#{dir}/.svn")

require 'mqrpc'

class AddRequest < MQRPC::RequestMessage
  argument :numbers
end

class AddResponse < MQRPC::ResponseMessage
  argument :sum
end
