Gem::Specification.new do |spec|
  files = []
  dirs = %w{lib}
  dirs.each do |dir|
    files += Dir["#{dir}/**/*"]
  end

  spec.name = "mqrpc"
  spec.version = "0.0.2"
  spec.summary = "mqrpc - RPC over Message Queue (AMQP)"
  spec.description = "RPC mechanism using AMQP as the transport"
  spec.add_dependency("amqp", ">= 0.6.0")
  spec.add_dependency("json", ">= 1.1.7")
  spec.add_dependency("uuid", ">= 2.0.2")
  spec.files = files
  spec.require_paths << "lib"
  spec.author = "Jordan Sissel, Pete Fritchman"
  spec.email = "logstash-dev@googlegroups.com"
  spec.homepage = "http://code.google.com/p/logstash/wiki/MQRPC"
end


