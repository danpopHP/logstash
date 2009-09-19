#!/usr/bin/env ruby

require 'rubygems'
require 'lib/net/client'
require 'lib/net/messages/indexevent'
require 'lib/net/messages/quit'
require 'lib/file/tail/since'
require 'stomp'
require 'socket'


class Agent < LogStash::Net::MessageClient
  def initialize(host, port)
    super(username="", password="", host=host, port=port)
    @hostname = Socket.gethostname
    @msgs = []
  end # def initialize

  def start_log_watcher
    @threads = []
    @threads << Thread.new do
      File::Tail::Since.new("/var/log/messages").tail do |line|
        line.chomp!
        index("linux-syslog", line)
      end
    end
    @threads << Thread.new do
      File::Tail::Since.new("/var/log/httpd/access_log").tail do |line|
        line.chomp!
        index("httpd-access", line)
      end
    end
  end # def start_log_watcher

  def index(type, string)
    ier = LogStash::Net::Messages::IndexEventRequest.new
    ier.log_type = type
    ier.log_data = string
    ier.metadata["source_host"] = @hostname

    #puts "Sending: #{ier}"
    sendmsg("/queue/logstash", ier)
  end # def index

  def IndexEventResponseHandler(msg)
    if msg.code != 0
      puts msg.inspect
    end
  end # def IndexEventResponseHandler

  def run
    start_log_watcher
    super
  end
end


if $0 == __FILE__
  if ARGV.length == 0
    puts "Usage: #{$0} host:port"
    exit 1
  end
  Thread::abort_on_exception = true
  host, port = ARGV[0].split(":")
  agent = Agent.new(host, port)
  agent.run
end