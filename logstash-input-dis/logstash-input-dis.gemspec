Gem::Specification.new do |s|
  s.name            = 'logstash-input-dis'
  s.version         = '1.1.4'
  s.licenses        = ['Apache License (2.0)']
  s.summary         = "Reads events from a DIS Stream"
  s.description     = "This gem is a Logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/logstash-plugin install gemname. This gem is not a stand-alone program"
  s.authors         = ['Data Ingestion Service']
  s.email           = 'dis@huaweicloud.com'
  s.homepage        = "https://www.huaweicloud.com/product/dis.html"
  s.require_paths = ['lib']

  # Files
  s.files = Dir["lib/**/*","spec/**/*","*.gemspec","*.md","CONTRIBUTORS","Gemfile","LICENSE","NOTICE.TXT", "vendor/jar-dependencies/**/*.jar", "vendor/jar-dependencies/**/*.rb", "VERSION", "docs/**/*"]

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { 'logstash_plugin' => 'true', 'logstash_group' => 'input'}

  s.requirements << "jar 'com.huaweicloud.dis:huaweicloud-dis-kafka-adapter', '1.2.9'"
  s.requirements << "jar 'org.apache.logging.log4j:log4j-slf4j-impl', '2.8.2'"

  s.add_development_dependency 'jar-dependencies', '~> 0.3.2'

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", ">= 1.60", "<= 2.99"
  s.add_runtime_dependency 'logstash-codec-json'
  s.add_runtime_dependency 'logstash-codec-plain'
  s.add_runtime_dependency 'stud', '>= 0.0.22', '< 0.1.0'

  s.add_development_dependency 'logstash-devutils'
  s.add_development_dependency 'rspec-wait'
end

