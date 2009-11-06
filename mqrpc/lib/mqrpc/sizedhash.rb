require 'thread'
#require 'pp'

# Thread-safe sized hash similar to SizedQueue.
# The only time we will block execution is in setting new items.
# That is, SizedThreadSafeHash#[]=
class SizedThreadSafeHash
  def initialize(size)
    @lock = Mutex.new
    @size = size
    @condvar = ConditionVariable.new
    @data = Hash.new
  end # def initialize

  # set a key and value
  def []=(key, value)
    @lock.synchronize do
      # If adding a new item, wait if the hash is full
      if !@data.has_key?(key) and _withlock_full?
        puts "Waiting to add key #{key.inspect}, hash is full"
        #pp @data
        @condvar.wait(@lock)
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
      puts "Removing key #{key.inspect}"
      @data.delete(key)
      @condvar.signal
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
    return @data.size == @size
  end
end # class SizedThreadSafeHash

#sh = SizedThreadSafeHash.new(10)
#Thread.new do
  #0.upto(100) do |i|
    #sh[i] = true
  #end
#end

#0.upto(100) do |i|
  #puts sh[i]
  #sh.delete(i)
  #sleep 1
#end
