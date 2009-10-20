#!/usr/bin/env ruby

$: << File.join(File.dirname(__FILE__), "..")

require 'lib/net/clients/agent'
require 'logger'
require 'optparse'

$progname = $0.split(File::SEPARATOR).last
$version = "0.3"
$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO
$logger.progname = $progname
$logger.datetime_format = "%Y-%m-%d %H:%M:%S"

def main(args)
  Thread::abort_on_exception = true

  options = parse_options(args)

  if options[:logfile]
    logfd = File.open(options[:logfile], "a")
    $stdout.reopen(logfd)
    $stderr.reopen(logfd)
  else
    # Require a logfile for daemonization
    if options[:daemonize]
      $stderr.puts "Daemonizing requires you specify a logfile (--logfile), " \
                   "none was given"
      return 1
    end
  end

  if options[:daemonize]
    fork and exit(0)

    # Copied mostly from  Daemons.daemonize, but since the ruby 1.8 'daemons'
    # and gem 'daemons' have api variances, let's do it ourselves since nobody
    # agrees.

    trap("SIGHUP", "IGNORE")
    ObjectSpace.each_object(IO) do |io|
      # closing STDIN is ok, but keep STDOUT and STDERR
      # close everything else
      next if [STDOUT, STDERR].include?(io)
      begin
        unless io.closed?
          io.close
        end
      rescue ::Exception
      end
    end
  end

  if options[:pidfile]
    File.open(options[:pidfile], "w+") { |f| f.puts $$ }
  end

  agent = LogStash::Net::Clients::Agent.new(options[:config], $logger)
  agent.run
end

def parse_options(args)
  options = {:daemonize => true,
             :logfile => nil,
             :pidfile => nil,
             :config => nil,
            }

  opts = OptionParser.new do |opts|
    opts.banner = "Usage: agent.rb [options] configfile"
    opts.version = $version

    opts.on("-d", "--debug", "Enable debug output") do |x|
      $logger.level = Logger::DEBUG
    end

    opts.on("--pidfile FILE", "Path to pidfile") do |x|
      options[:pidfile] = x
    end

    opts.on("-f", "--foreground", "Do not daemonize") do |x|
      options[:daemonize] = false
    end

    opts.on("-l FILE", "--logfile FILE", "File path to put logs") do |x|
      options[:logfile] = x
    end
  end

  begin
    opts.order!(args)
  rescue
    $stderr.puts "#{$progname}: #{$!}"
    $stderr.puts opts
    exit(1)
  end

  if args.length != 1
    $stderr.puts "#{$progname}: must specify exactly one config file"
    $stderr.puts opts
    exit(1)
  end
  options[:config] = args.shift

  return options  
end

exit main(ARGV)
