require 'rubygems'
require 'thread'

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
      # TODO(sissel): allow the callback to simply invoke 'finished' on this operation
      # rather than requiring it to emit ':finished'
      @mutex.synchronize do
        ret = @callback.call(*args)
        if ret == :finished
          $logger.info "Operation #{self} finished"
          @finished = true
          @cv.signal
        else
          return ret
        end
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
