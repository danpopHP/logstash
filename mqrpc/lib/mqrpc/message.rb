require 'json'
require 'thread'

module BindToHash
  def hashbind(method, key)
    hashpath = BindToHash.genhashpath(key)
    self.class_eval %(
      def #{method}
        return #{hashpath}
      end
      def #{method}=(val)
        #{hashpath} = val
      end
    )
  end

  def self.genhashpath(key)
    # TODO(sissel): enforce 'key' needs to be a string or symbol?
    path = key.split("/").select { |x| x.length > 0 }\
               .map { |x| "[#{x.inspect}]" }
    return "@data#{path.join("")}"
  end
end # modules BindToHash

module MQRPC
  class Message
    extend BindToHash

    @@knowntypes = Hash.new
    attr_accessor :data

    # Message attributes
    hashbind :id, "id"
    hashbind :messageclass, "messageclass"
    hashbind :replyto, "reply-to"
    hashbind :timestamp, "timestamp"

    def age
      return Time.now.to_f - timestamp
    end

    def buffer?
      return @buffer
    end

    def want_buffer(want_buffer=true)
      @buffer = want_buffer
    end

    def self.inherited(subclass)
      puts "#{subclass.name} is a #{self.name}"
      @@knowntypes[subclass.name] = subclass

      # Call the class initializer if it has one.
      if subclass.respond_to?(:class_initialize)
        subclass.class_initialize
      end
    end # def self.inherited

    def initialize
      @data = Hash.new
      want_buffer(false)
      self.messageclass = self.class.name
    end

    def self.new_from_data(data)
      obj = nil
      name = data["messageclass"]
      if @@knowntypes.has_key?(name)
        obj = @@knowntypes[name].new
      else
        $stderr.puts "No known message class: #{name}, #{data.inspect}"
        obj = Message.new
      end
      obj.data = data
      return obj
    end

    def to_json(*args)
      return @data.to_json(*args)
    end

    protected
    attr :data
  end # class Message

  class RequestMessage < Message
    @@idseq = 0
    @@idlock = Mutex.new

    def initialize
      super
      self.args = Hash.new
      generate_id!
    end

    def generate_id!
      @@idlock.synchronize do
        self.id = @@idseq
        @@idseq += 1
      end
    end

    hashbind :args, "args"
  end # class RequestMessage

  class ResponseMessage < Message
    def initialize
      super
      self.args = Hash.new
    end

    hashbind :args, "args"

    # Report the success of the request this response is for.
    # Should be implemented by subclasses.
    def success?
      raise NotImplementedError
    end
  end # class ResponseMessage
end # module MQRPC
