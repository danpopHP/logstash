require 'rubygems'
require 'thread'
require 'mqrpc/logger'

module MQRPC
  # A single message operation
  # * Takes a callback to call when a message is received
  # * Allows you to wait for the operation to complete.
  # * An operation is 'complete' when the callback returns :finished
  class Operation
    def initialize(callback)
      @mutex = Mutex.new
      @callback = callback
      @cv = ConditionVariable.new
      @finished = false
    end # def initialize

    def call(*args)
      # TODO(sissel): Come up with a better way for the callback to declare
      # that it is not done than simply returning ':continue'
      @mutex.synchronize do
        ret = @callback.call(*args)
        if ret != :continue
          #MQRPC::logger.debug "operation #{self} finished"
          @finished = true
          @cv.signal
        end
        return ret
      end
    end # def call

    # Block until the operation has finished.
    # If the operation has already finished, this method will return
    # immediately.
    def wait_until_finished
      @mutex.synchronize do
        if !finished?
          @cv.wait(@mutex)
        end
      end
    end # def wait_until_finished

    protected
    def finished?
      return @finished
    end # def finished?
  end # class Operation
end # module MQRPC
