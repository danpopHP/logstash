
require 'rubygems'
require 'ferret'
require 'lib/config/indexer.rb'
require 'lib/log/text'
require 'lib/net/messages/indexevent'
require 'lib/net/messages/ping'
require 'lib/net/messages/search'
require 'lib/net/messages/searchhits'
require 'mqrpc'
require 'pp'

module LogStash; module Net; module Servers
  class Parser < MQRPC::Agent
    SYNCDELAY = 10

    def initialize(configfile, logger)
      @config = LogStash::Config::IndexerConfig.new(configfile)
      @logger = logger
      @logger.progname = "parser"
      MQRPC::logger = @logger
      super(@config)
      @lines = Hash.new { |h,k| h[k] = 0 }
      @indexcount = 0
      @starttime = Time.now
    end

    def IndexEventRequestHandler(request)
      @logger.debug "received IndexEventRequest (for type " \
                    "#{request.log_type}): #{request.log_data}"
      response = LogStash::Net::Messages::IndexEventResponse.new(request)
      @indexcount += 1

      if @indexcount % 100 == 0
        duration = (Time.now.to_f - @starttime.to_f)
        @logger.debug "rate: %.2f/sec" % (@indexcount / duration)
      end

      log_type = request.log_type
      entry = @config.logs[log_type].parse_entry(request.log_data)
      if !entry
        @logger.warn "Failed parsing line: #{request.log_data}"
        response.code = 1
        response.error = "Entry was #{entry.inspect} (log parsing failed)"
        entry = {
          "@NEEDSPARSING" => 1,
          "@LINE" => request.log_data
        }
      else
        response.code = 0
      end
      yield response
      entry["@LOG_TYPE"] = log_type

      # Now we have a hash for the log data, send it to the indexer
      request.log_data = entry
      sendmsg("logstash-index", request)
    end

    def IndexEventResponseHandler(response)
      # This message comes from the indexer, we don't need to really
      # do anything with it.
    end

    def PingRequestHandler(request)
      @logger.debug "received PingRequest (#{request.pingdata})"
      response = LogStash::Net::Messages::PingResponse.new(request)
      response.pingdata = request.pingdata
      yield response
    end

    # Special 'run' override because we want sync to disk once per minute.
    def run
      subscribe("logstash")
      super
    end # def run
  end # Parser
end; end; end # LogStash::Net::Server
