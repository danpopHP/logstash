require 'rubygems'
require 'lib/mqrpc'

module  MQRPC::Messages
  class PingRequest < RequestMessage
    hashbind :pingdata, "/args/pingdata"

    def initailize
      super
      self.pingdata = Time.now.to_f
    end
  end # class PingRequest < RequestMessage

  class PingResponse < ResponseMessage
    hashbind :pingdata, "/args/pingdata"
  end
end
