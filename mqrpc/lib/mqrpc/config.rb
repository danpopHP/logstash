module MQRPC
  class Config
    attr_reader :mqhost
    attr_reader :mqport
    attr_reader :mquser
    attr_reader :mqpass
    attr_reader :mqvhost
    attr_reader :mqexchange
    attr_reader :mqexchange_topic
    attr_reader :mqexchange_direct

    def initialize(options = {})
      @mqhost = options["mqhost"] || "localhost"
      @mqport = options["mqport"] || 5672
      @mquser = options["mquser"] || "guest"
      @mqpass = options["mqpass"] || "guest"
      @mqvhost = options["mqvhost"] || "/"
      @mqexchange = options["mqexchange"] || "mqrpc"
      @mqexchange_topic = "#{@mqexchange}.topic"
      @mqexchange_direct = "#{@mqexchange}.direct"
    end # def initialize
  end # class Config
end # module MQRPC
