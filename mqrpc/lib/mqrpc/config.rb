module MQRPC
  class Config
    attr_reader :mqhost
    attr_reader :mqport
    attr_reader :mquser
    attr_reader :mqpass
    attr_reader :mqvhost

    def initialize(options = {})
      @mqhost = options["mqhost"] || "localhost"
      @mqport = options["mqport"] || 5672
      @mquser = options["mquser"] || "guest"
      @mqpass = options["mqpass"] || "guest"
      @mqvhost = options["mqvhost"] || "/"
    end # def initialize
  end # class Config
end # module MQRPC
