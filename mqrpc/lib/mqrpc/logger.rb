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
