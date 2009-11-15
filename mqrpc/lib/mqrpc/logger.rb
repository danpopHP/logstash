require 'rubygems'
require 'logger'

module MQRPC
  @logger = Logger.new(STDOUT)
  @logger.level = Logger::WARN

  def self.logger
    return @logger
  end

  def self.logger=(logger)
    @logger = logger
  end
end

# Make logger include the thread id.
class FormatterWithThread < Logger::Formatter
  Format = "%s, [%s#%d/%s] %5s -- %s: %s\n"

  def call(severity, time, progname, msg)
    Format % [severity[0..0], format_datetime(time), $$, Thread.current,
              severity, progname, msg2str(msg)]
  end
end

MQRPC::logger.formatter = FormatterWithThread.new
