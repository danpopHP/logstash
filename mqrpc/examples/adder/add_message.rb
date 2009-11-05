require 'mqrpc'

class AddRequest < MQRPC::RequestMessage
  argument :numbers
end

class AddResponse < MQRPC::ResponseMessage
  argument :sum
end
