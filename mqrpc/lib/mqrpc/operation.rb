require 'rubygems'
require 'thread'
require 'mqrpc/logger'

module MQRPC
  # A single message operation
  # * Takes a callback to call when a message is received
  # * Allows you to wait for the operation to complete.
  # * An operation is 'complete' when the callback returns.
  #
  # If your callback returns :continue, then we will not call finished.
  # This allows you to have an operation that is invoked multiple times,
  # such as for streaming blocks of data, and only finish when you know
  # you are done.
  class Operation
    def initialize(&callback)
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
          _withlock_finished
        end
        return ret
      end
    end # def call

    # Block until the operation has finished.
    # If the operation has already finished, this method will return
    # immediately.
    def wait_until_finished
      @mutex.synchronize do
        if !_withlock_finished?
          @cv.wait(@mutex)
        end
      end
    end # def wait_until_finished

    # Is the operation finished yet?
    def finished?
      @mutex.synchronize do
        return _withlock_finished?
      end
    end # def finished?

    # Declare that the operation is finished.
    def finished
      @mutex.synchronize do
        return _withlock_finished
      end
    end # def finished

    protected
    def _withlock_finished?
      return @finished
    end # def finished?

    def _withlock_finished
      @finished = true
      @cv.signal
    end

  end # class Operation
end # module MQRPC
