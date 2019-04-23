require 'logstash/namespace'
require 'logstash/inputs/base'
require 'stud/interval'
require 'java'
require 'logstash-input-dis_jars.rb'

# This input will read events from a DIS stream, using DIS Kafka Adapter.
class LogStash::Inputs::Dis < LogStash::Inputs::Base
  config_name 'dis'

  default :codec, 'plain'

  config :default_trusted_jks_enabled, :validate => :boolean, :default => false
  config :security_token, :validate => :string
  config :exception_retries, :validate => :number, :default => 8
  config :records_retries, :validate => :number, :default => 20
  config :proxy_host, :validate => :string
  config :proxy_port, :validate => :number, :default => 80
  config :proxy_protocol, :validate => ["http", "https"], :default => "http"
  config :proxy_username, :validate => :string
  config :proxy_password, :validate => :string
  config :proxy_workstation, :validate => :string
  config :proxy_domain, :validate => :string
  config :proxy_non_proxy_hosts, :validate => :string

  # The frequency in milliseconds that the consumer offsets are committed to Kafka.
  config :auto_commit_interval_ms, :validate => :string, :default => "5000"
  # What to do when there is no initial offset in Kafka or if an offset is out of range:
  #
  # * earliest: automatically reset the offset to the earliest offset
  # * latest: automatically reset the offset to the latest offset
  # * none: throw exception to the consumer if no previous offset is found for the consumer's group
  # * anything else: throw exception to the consumer.
  config :auto_offset_reset, :validate => :string
  # The id string to pass to the server when making requests. The purpose of this
  # is to be able to track the source of requests beyond just ip/port by allowing
  # a logical application name to be included.
  config :client_id, :validate => :string, :default => "logstash"
  # Ideally you should have as many threads as the number of partitions for a perfect
  # balance — more threads than partitions means that some threads will be idle
  config :consumer_threads, :validate => :number, :default => 1
  # If true, periodically commit to Kafka the offsets of messages already returned by the consumer. 
  # This committed offset will be used when the process fails as the position from
  # which the consumption will begin.
  config :enable_auto_commit, :validate => :string, :default => "true"
  # The identifier of the group this consumer belongs to. Consumer group is a single logical subscriber
  # that happens to be made up of multiple processors. Messages in a topic will be distributed to all
  # Logstash instances with the same `group_id`
  config :group_id, :validate => :string, :default => "logstash"
  # Java Class used to deserialize the record's key
  config :key_deserializer_class, :validate => :string, :default => "com.huaweicloud.dis.adapter.kafka.common.serialization.StringDeserializer"
  # Java Class used to deserialize the record's value
  config :value_deserializer_class, :validate => :string, :default => "com.huaweicloud.dis.adapter.kafka.common.serialization.StringDeserializer"
  # A list of streams to subscribe to, defaults to ["logstash"].
  config :streams, :validate => :array, :default => ["logstash"]
  # DIS Gateway endpoint
  config :endpoint, :validate => :string, :default => "https://dis.cn-north-1.myhuaweicloud.com"
  # The ProjectId of the specified region, it can be obtained from My Credential Page
  config :project_id, :validate => :string
  # Specifies use which region of DIS, now DIS only support cn-north-1
  config :region, :validate => :string, :default => "cn-north-1"
  # The Access Key ID for hwclouds, it can be obtained from My Credential Page
  config :ak, :validate => :string, :required => true
  # The Secret key ID is encrypted or not
  config :is_sk_encrypted, :default => false
  # The encrypt key used to encypt the Secret Key Id
  config :encrypt_key, :validate => :string
  # The Secret Key ID for hwclouds, it can be obtained from My Credential Page
  config :sk, :validate => :string, :required => true
  # A topic regex pattern to subscribe to. 
  # The topics configuration will be ignored when using this configuration.
  config :topics_pattern, :validate => :string
  # Time kafka consumer will wait to receive new messages from topics
  config :poll_timeout_ms, :validate => :number, :default => 100
  # Option to add DIS metadata like stream, message size to the event.
  # This will add a field named `dis` to the logstash event containing the following attributes:
  #   `stream`: The stream this message is associated with
  #   `consumer_group`: The consumer group used to read in this event
  #   `partition`: The partition this message is associated with
  #   `offset`: The offset from the partition this message is associated with
  #   `key`: A ByteBuffer containing the message key
  #   `timestamp`: The timestamp of this message
  config :decorate_events, :validate => :boolean, :default => false


  public
  def register
    @runner_threads = []
  end # def register

  public
  def run(logstash_queue)
    @runner_consumers = consumer_threads.times.map { |i| create_consumer("#{client_id}-#{i}") }
    @runner_threads = @runner_consumers.map { |consumer| thread_runner(logstash_queue, consumer) }
    @runner_threads.each { |t| t.join }
  end # def run

  public
  def stop
    @runner_consumers.each { |c| c.wakeup }
  end

  public
  def kafka_consumers
    @runner_consumers
  end

  private
  def thread_runner(logstash_queue, consumer)
    Thread.new do
      begin
        unless @topics_pattern.nil?
          nooplistener = com.huaweicloud.dis.adapter.kafka.clients.consumer.internals.NoOpConsumerRebalanceListener.new
          pattern = java.util.regex.Pattern.compile(@topics_pattern)
          consumer.subscribe(pattern, nooplistener)
        else
          consumer.subscribe(streams);
        end
        codec_instance = @codec.clone
        while !stop?
          records = consumer.poll(poll_timeout_ms)
          for record in records do
            codec_instance.decode(record.value.to_s) do |event|
              decorate(event)
              if @decorate_events
                event.set("[@metadata][dis][topic]", record.topic)
                event.set("[@metadata][dis][consumer_group]", @group_id)
                event.set("[@metadata][dis][partition]", record.partition)
                event.set("[@metadata][dis][offset]", record.offset)
                event.set("[@metadata][dis][key]", record.key)
                event.set("[@metadata][dis][timestamp]", record.timestamp)
              end
              logstash_queue << event
            end
          end
          # Manual offset commit
          if @enable_auto_commit == "false"
            consumer.commitSync
          end
        end
      rescue org.apache.kafka.common.errors.WakeupException => e
        raise e if !stop?
      ensure
        consumer.close
      end
    end
  end

  private
  def create_consumer(client_id)
    begin
      props = java.util.Properties.new
      kafka = com.huaweicloud.dis.adapter.kafka.clients.consumer.ConsumerConfig

      props.put("IS_DEFAULT_TRUSTED_JKS_ENABLED", default_trusted_jks_enabled.to_s)
      props.put("security.token", security_token) unless security_token.nil?
      props.put("exception.retries", exception_retries.to_s)
      props.put("records.retries", records_retries.to_s)
      props.put("PROXY_HOST", proxy_host) unless proxy_host.nil?
      props.put("PROXY_PORT", proxy_port.to_s)
      props.put("PROXY_PROTOCOL", proxy_protocol)
      props.put("PROXY_USERNAME", proxy_username) unless proxy_username.nil?
      props.put("PROXY_PASSWORD", proxy_password) unless proxy_password.nil?
      props.put("PROXY_WORKSTATION", proxy_workstation) unless proxy_workstation.nil?
      props.put("PROXY_DOMAIN", proxy_domain) unless proxy_domain.nil?
      props.put("NON_PROXY_HOSTS", proxy_non_proxy_hosts) unless proxy_non_proxy_hosts.nil?
      
      props.put("auto.commit.interval.ms", auto_commit_interval_ms)
      props.put("auto.offset.reset", auto_offset_reset) unless auto_offset_reset.nil?
      props.put("client.id", client_id)
      props.put("enable.auto.commit", enable_auto_commit)
      props.put("group.id", group_id)
      props.put("key.deserializer", "com.huaweicloud.dis.adapter.kafka.common.serialization.StringDeserializer")
      props.put("value.deserializer", "com.huaweicloud.dis.adapter.kafka.common.serialization.StringDeserializer")

      # endpoint, project_id, region, ak, sk
      props.put("endpoint", endpoint)
      props.put("projectId", project_id)
      props.put("region", region)
      props.put("ak", ak)
      if is_sk_encrypted
        decrypted_sk = decrypt(@sk)
        props.put("sk", decrypted_sk)
      else
        props.put("sk", sk)
      end

      com.huaweicloud.dis.adapter.kafka.clients.consumer.DISKafkaConsumer.new(props)
    rescue => e
      logger.error("Unable to create DIS Kafka consumer from given configuration",
                   :kafka_error_message => e,
                   :cause => e.respond_to?(:getCause) ? e.getCause() : nil)
      throw e
    end
  end

  private
  def decrypt(encrypted_sk)
    com.huaweicloud.dis.util.encrypt.EncryptUtils.dec([@encrypt_key].to_java(java.lang.String), encrypted_sk)
  rescue => e
    logger.error("Unable to decrypt sk from given configuration",
                  :decrypt_error_message => e,
                  :cause => e.respond_to?(:getCause) ? e.getCause() : nil)
  end
end #class LogStash::Inputs::Dis
