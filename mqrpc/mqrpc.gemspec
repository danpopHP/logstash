files = []
dirs = %w{lib}
dirs.each do |dir|
  files += Dir["#{dir}/**/*"]
end

Gem::Specification.new do |spec|
  spec.name = "mqrpc"
  spec.version = "0.0.1"
  spec.summary = "mqrpc - RPC over Message Queue (AMQP)"
  spec.description = "RPC mechanism using AMQP as the transport"
  spec.add_dependency("amqp", ">= 0.6.0")
  spec.require_path = "lib"
  spec.author = "Jordan Sissel, Pete Fritchman"
  spec.email = "logstash-dev@googlegroups.com"
  spec.homepage = "http://code.google.com/p/logstash/wiki/MQRPC"
end


