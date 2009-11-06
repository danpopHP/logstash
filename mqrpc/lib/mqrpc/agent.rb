require 'rubygems'
require 'amqp'
require 'mq'
require 'mqrpc/logger'
require 'mqrpc/operation'
require 'mqrpc/sizedhash'
require 'thread'
require 'uuid'

# http://github.com/tmm1/amqp/issues/#issue/3
# This is our (lame) hack to at least notify the user that something is
# wrong.
module AMQP
  module Client
    alias :original_reconnect :reconnect 
    def reconnect(*args)
      $logger.warn "reconnecting to broker (bad MQ settings?)"

      # some rate limiting
      sleep(5)

      original_reconnect(*args)
    end
  end
end

module MQRPC
  # TODO: document this class
  class Agent
    MAXBUF = 20
    MAXMESSAGEWAIT = 5 * MAXBUF

    def initialize(config)
      Thread::abort_on_exception = true
      @config = config
      @handler = self
      @id = UUID::generate
      @outbuffer = Hash.new { |h,k| h[k] = [] }
      @queues = []
      @topics = []
      @receive_queue = Queue.new
      @want_subscriptions = Queue.new
      @slidingwindow = Hash.new do |h,k| 
        MQRPC::logger.info "New sliding window for #{k}"
        h[k] = SizedThreadSafeHash.new(MAXMESSAGEWAIT) 
      end

      @mq = nil
      @message_operations = Hash.new

      @startup_mutex = Mutex.new
      @startup_condvar = ConditionVariable.new
      @amqp_ready = false

      start_amqp

      # Wait for our AMQP thread to get going. Mainly, it needs to set
      # @mq, so we'll block until it's available.
      @startup_mutex.synchronize do
        MQRPC::logger.debug "Waiting for @mq ..."
        @startup_condvar.wait(@startup_mutex) if !@amqp_ready
        MQRPC::logger.debug "Got it, continuing with #{self.class} init..."
      end

      start_receiver
    end # def initialize

    def start_amqp
      @amqpthread = Thread.new do 
        # Create connection to AMQP, and in turn, the main EventMachine loop.
        amqp_config = {:host => @config.mqhost,
                       :port => @config.mqport,
                       :user => @config.mquser,
                       :pass => @config.mqpass,
                       :vhost => @config.mqvhost,
                      }
        AMQP.start(amqp_config) do
          @startup_mutex.synchronize do
            @mq = MQ.new
            # Notify the main calling thread (MessageSocket#initialize) that
            # we can continue
            @amqp_ready = true
            @startup_condvar.signal
          end

          MQRPC::logger.info "Subscribing to main queue #{@id}"
          mq_q = @mq.queue(@id, :auto_delete => true)
          mq_q.subscribe(:ack =>true) { |hdr, msg| @receive_queue << [hdr, msg] }
          #handle_new_subscriptions
          
          # TODO(sissel): make this a deferred thread that reads from a Queue
          #EM.add_periodic_timer(5) { handle_new_subscriptions }
          EM.defer { handle_subscriptions }

          EM.add_periodic_timer(1) do
            # TODO(sissel): add locking
            @outbuffer.each_key { |dest| flushout(dest) }
            @outbuffer.clear
          end
        end # AMQP.start
      end
    end # def start_amqp

    def start_receiver
      Thread.new do 
        while true
          header, message = @receive_queue.pop
          handle_message(header, message)
        end
      end
    end # def start_receiver

    def subscribe(name)
      @want_subscriptions << [:queue, name]
    end # def subscribe

    def subscribe_topic(name)
      @want_subscriptions << [:topic, name]
    end # def subscribe_topic

    def handle_message(hdr, msg_body)
      obj = JSON::load(msg_body)
      if !obj.is_a?(Array)
        obj = [obj]
      end

      queue = hdr.routing_key
      obj.each do |item|
        message = Message.new_from_data(item)
        slidingwindow = @slidingwindow[queue]
        if message.respond_to?(:from_queue)
          slidingwindow = @slidingwindow[message.from_queue]
        end
        MQRPC::logger.debug "Got message #{message.class}##{message.id} on queue #{queue}"
        MQRPC::logger.debug "Received message: #{message.inspect}"
        if (message.respond_to?(:in_reply_to) and 
            slidingwindow.include?(message.in_reply_to))
          MQRPC::logger.info "Got response to #{message.in_reply_to}"
          slidingwindow.delete(message.in_reply_to)
        end
        name = message.class.name.split(":")[-1]
        func = "#{name}Handler"

        # Check if we have a specific operation looking for this
        # message.
        if (message.respond_to?(:in_reply_to) and
            @message_operations.has_key?(message.in_reply_to))
          operation = @message_operations[message.in_reply_to]
          operation.call(message)
        elsif @handler.respond_to?(func) 
          @handler.send(func, message) do |response|
            reply_destination = message.reply_to
            response.from_queue = queue
            sendmsg(reply_destination, response)
          end

          # We should allow the message handler to defer acking if they want
          # For instance, if we want to index things, but only want to ack
          # things once we actually flush to disk.
        else
          $stderr.puts "#{@handler.class.name} does not support #{func}"
        end # if @handler.respond_to?(func)
      end
      hdr.ack
    end # def handle_message

    def run
      @amqpthread.join
    end # run

    def handle_subscriptions
      while true do
        type, name = @want_subscriptions.pop
        case type
        when :queue
          next if @queues.include?(name)
          MQRPC::logger.info "Subscribing to queue #{name}"
          mq_q = @mq.queue(name, :durable => true)
          mq_q.subscribe(:ack => true) { |hdr, msg| @receive_queue << [hdr, msg] }
          @queues << name
        when :topic
          MQRPC::logger.info "Subscribing to topic #{name}"
          exchange = @mq.topic(@config.mqexchange)
          mq_q = @mq.queue("#{@id}-#{name}",
                           :exclusive => true,
                           :auto_delete => true).bind(exchange, :key => name)
          mq_q.subscribe { |hdr, msg| @receive_queue << [hdr, msg] }
          @topics << name
        end
      end
    end

    def handle_new_subscriptions
      todo = @want_queues - @queues
      todo.each do |queue|
        MQRPC::logger.info "Subscribing to queue #{queue}"
        mq_q = @mq.queue(queue, :durable => true)
        mq_q.subscribe(:ack => true) { |hdr, msg| @receive_queue << [hdr, msg] }
        @queues << queue
      end # todo.each

      todo = @want_topics - @topics
      todo.each do |topic|
        MQRPC::logger.info "Subscribing to topic #{topic}"
        exchange = @mq.topic(@config.mqexchange)
        mq_q = @mq.queue("#{@id}-#{topic}",
                         :exclusive => true,
                         :auto_delete => true).bind(exchange, :key => topic)
        mq_q.subscribe { |hdr, msg| @receive_queue << [hdr, msg] }
        @topics << topic
      end # todo.each
    end # handle_new_subscriptions

    def flushout(destination)
      msgs = @outbuffer[destination]
      return if msgs.length == 0
      data = msgs.to_json
      @mq.queue(destination, :durable => true).publish(data, :persistent => true)
      msgs.clear
    end

    def sendmsg_topic(key, msg)
      if (msg.is_a?(RequestMessage) and msg.id == nil)
        msg.generate_id!
      end
      msg.timestamp = Time.now.to_f

      data = msg.to_json
      @mq.topic(@config.mqexchange).publish(data, :key => key)
    end

    def sendmsg(destination, msg, &callback)
      if (msg.is_a?(RequestMessage) and msg.id == nil)
        msg.generate_id!
      end
      msg.timestamp = Time.now.to_f
      msg.reply_to = @id

      if msg.is_a?(RequestMessage)
        MQRPC::logger.debug "Tracking #{msg.class.name}##{msg.id} to #{destination}"
        @slidingwindow[destination][msg.id] = true
      end

      if msg.buffer?
        @outbuffer[destination] << msg
        if @outbuffer[destination].length > MAXBUF
          flushout(destination)
        end
      else
        @mq.queue(destination, :durable => true).publish([msg].to_json, :persistent => true)
      end

      if block_given?
        op = Operation.new(callback)
        @message_operations[msg.id] = op
        return op
      end
    end

    def handler=(handler)
      @handler = handler
    end

    def close
      EM.stop_event_loop
    end
  end # class Agent
end # module MQRPC
