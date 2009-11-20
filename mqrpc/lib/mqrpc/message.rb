require 'json'
require 'thread'
require 'mqrpc/logger'

module BindToHash
  def header(method, key=nil)
    key = method.to_s if key == nil
    hashbind(method, "/#{key}")
  end

  def argument(method, key=nil)
    key = method.to_s if key == nil
    hashbind(method, "/args/#{key}")
  end

  private
  def hashbind(method, key)
    hashpath = __genhashpath(key)
    self.class_eval %(
      def #{method}
        return #{hashpath}
      end
      def #{method}=(val)
        #{hashpath} = val
      end
    )
  end

  private
  def __genhashpath(key)
    # TODO(sissel): enforce 'key' needs to be a string or symbol?
    path = key.split("/").select { |x| x.length > 0 }\
               .map { |x| "[#{x.inspect}]" }
    return "@data#{path.join("")}"
  end
end # modules BindToHash

module MQRPC
  class Message
    extend BindToHash
    @@idseq = 0
    @@idlock = Mutex.new
    @@knowntypes = Hash.new
    attr_accessor :data

    # Message attributes
    header :id
    header :message_class
    header :delayable
    header :reply_to
    header :timestamp
    header :args

    def self.inherited(subclass)
      MQRPC::logger.debug "Message '#{subclass.name}' subclasses #{self.name}"
      @@knowntypes[subclass.name] = subclass

      # Call the class initializer if it has one.
      if subclass.respond_to?(:class_initialize)
        subclass.class_initialize
      end
    end # def self.inherited

    def self.new_from_data(data)
      obj = nil
      name = data["message_class"]
      if @@knowntypes.has_key?(name)
        obj = @@knowntypes[name].new
      else
        $stderr.puts "No known message class: #{name}, #{data.inspect}"
        obj = Message.new
      end
      obj.data = data
      return obj
    end

    def initialize
      @data = Hash.new
      # Don't delay messages by defualt
      self.delayable = false

      generate_id!
      self.message_class = self.class.name
      self.args = Hash.new
    end

    def generate_id!
      @@idlock.synchronize do
        self.id = @@idseq
        #puts "Generating id. #{self.class}.id == #{self.id}"
        @@idseq += 1
      end
    end

    def age
      return Time.now.to_f - timestamp
    end

    def to_json(*args)
      return @data.to_json(*args)
    end

    protected
    attr :data
  end # class Message

  class RequestMessage < Message
    # Nothing.
  end # class RequestMessage

  class DummyMessage < Message
    # Nothing.
  end # class DummyMessage

  class ResponseMessage < Message
    header :in_reply_to
    header :from_queue

    def initialize(source_request=nil)
      super()

      # Copy the request id if we are given a source_request
      if source_request.is_a?(RequestMessage)
        self.in_reply_to = source_request.id
        self.delayable = source_request.delayable
      end
      self.args = Hash.new
    end

    # Report the success of the request this response is for.
    # Should be implemented by subclasses.
    def success?
      raise NotImplementedError
    end
  end # class ResponseMessage
end # module MQRPC
