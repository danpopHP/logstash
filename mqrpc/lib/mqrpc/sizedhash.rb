require 'thread'
require 'mqrpc'

# A mutex which logs every enter/exit on synchronize
class TrackingMutex < Mutex
  def synchronize(&blk)
    MQRPC::logger.debug "Enter synchronize #{self} @ #{caller[0]}"
    super { blk.call }
    MQRPC::logger.debug "Exit synchronize #{self} @ #{caller[0]}"
  end # def synchronize
end # clas TrackingMutex < Mutex

# Thread-safe sized hash similar to SizedQueue.
# The only time we will block execution is in setting new items.
# That is, SizedThreadSafeHash#[]=
class SizedThreadSafeHash
  attr_reader :callback
  attr_reader :size

  def initialize(size, &callback)
    @lock = Mutex.new
    @size = size
    @condvar = ConditionVariable.new
    @data = Hash.new
    @callback = callback
    @state = nil
  end # def initialize

  # set a key and value
  def []=(key, value)
    @lock.synchronize do
      # If adding a new item, wait if the hash is full
      if !@data.has_key?(key) and _withlock_full?
        MQRPC::logger.info "#{self}: Waiting to add key #{key.inspect}, hash is full (thread #{Thread.current})"
        if @state != :blocked
          @state = :blocked
          @callback.call(@state) if @callback
        else
          puts "State is already #{@state} (want :blocked), skipping event call"
        end

        @condvar.wait(@lock)

        if @state != :ready
          @state = :ready
          MQRPC::logger.info "#{self}: state => :ready"
          @callback.call(@state) if @callback
        else
          puts "State is already #{@state} (want :ready), skipping event call"
        end
      end
      @data[key] = value
    end
  end # def []=

  # get an value by key
  def [](key)
    @lock.synchronize do
      return @data[key]
    end
  end # def []

  # boolean, does the hash have a given key?
  def has_key?(key)
    @lock.synchronize do
      return @data.has_key?(key)
    end
  end # def has_key?

  alias :include? :has_key?

  # delete a key
  def delete(key)
    @lock.synchronize do
      was_full = _withlock_full?
      @data.delete(key)
      if was_full
        MQRPC::logger.info "#{self}: signalling non-fullness"
        @condvar.signal
      end
    end
  end # def delete

  # boolean, indicates true when the hash is full (has size == initialized size)
  def full?
    @lock.synchronize do
      return _withlock_full?
    end
  end # def full?

  # return the size (total number of entries) in this hash.
  def size
    @lock.synchronize do
      return @data.size
    end
  end

  # Return an array of keys for this hash.
  def keys
    @lock.synchronize do
      return @data.keys
    end
  end
  alias :length :size

  private
  def _withlock_full?
    return @data.size >= @size
  end
end # class SizedThreadSafeHash