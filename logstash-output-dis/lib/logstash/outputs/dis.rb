require 'logstash/namespace'
require 'logstash/outputs/base'
require 'java'
require 'logstash-output-dis_jars.rb'

java_import com.huaweicloud.dis.adapter.kafka.clients.producer.ProducerRecord

# Write events to a DIS stream, using DIS Kafka Adapter.
class LogStash::Outputs::Dis < LogStash::Outputs::Base
  declare_threadsafe!

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

  # The producer will attempt to batch records together into fewer requests whenever multiple
  # records are being sent to the same partition. This helps performance on both the client
  # and the server. This configuration controls the default batch size in bytes.
  config :batch_size, :validate => :number, :default => 16384
  config :batch_count, :validate => :number, :default => 5000

  # The total bytes of memory the producer can use to buffer records waiting to be sent to the server.
  config :buffer_memory, :validate => :number, :default => 33554432
  config :buffer_count, :validate => :number, :default => 5000
  # The producer groups together any records that arrive in between request
  # transmissions into a single batched request. Normally this occurs only under
  # load when records arrive faster than they can be sent out. However in some circumstances
  # the client may want to reduce the number of requests even under moderate load.
  # This setting accomplishes this by adding a small amount of artificial delay—that is,
  # rather than immediately sending out a record the producer will wait for up to the given delay
  # to allow other records to be sent so that the sends can be batched together.
  config :linger_ms, :validate => :number, :default => 50
  config :block_on_buffer_full, :validate => :boolean, :default => false
  # block time when buffer is full
  config :max_block_ms, :validate => :number, :default => 60000
  # max wait time in single backoff
  config :backoff_max_interval_ms, :validate => :number, :default => 30000
  config :max_in_flight_requests_per_connection, :validate => :number, :default => 50
  config :records_retriable_error_code, :validate => :string, :default => "DIS.4303,DIS.5"
  config :order_by_partition, :validate => :boolean, :default => false
  config :metadata_timeout_ms, :validate => :number, :default => 600000
  # The key for the message
  config :message_key, :validate => :string
  config :partition_id, :validate => :string
  # the timeout setting for initial metadata request to fetch topic metadata.
  config :metadata_fetch_timeout_ms, :validate => :number, :default => 60000
  # the max time in milliseconds before a metadata refresh is forced.
  config :metadata_max_age_ms, :validate => :number, :default => 300000
  # The size of the TCP receive buffer to use when reading data
  config :receive_buffer_bytes, :validate => :number, :default => 32768
  # The configuration controls the maximum amount of time the client will wait
  # for the response of a request. If the response is not received before the timeout
  # elapses the client will resend the request if necessary or fail the request if
  # retries are exhausted.
  config :request_timeout_ms, :validate => :string
  # The default retry behavior is to retry until successful. To prevent data loss,
  # the use of this setting is discouraged.
  #
  # If you choose to set `retries`, a value greater than zero will cause the
  # client to only retry a fixed number of times. This will result in data loss
  # if a transient error outlasts your retry count.
  #
  # A value less than zero is a configuration error.
  config :retries, :validate => :number
  # The amount of time to wait before attempting to retry a failed produce request to a given topic partition.
  config :retry_backoff_ms, :validate => :number, :default => 100


  # The DIS stream to produce messages to
  config :stream, :validate => :string, :required => true
  # DIS Gateway endpoint
  config :endpoint, :validate => :string, :default => "https://dis.cn-north-1.myhuaweicloud.com"
  # The ProjectId of the specified region, it can be obtained from My Credential Page
  config :project_id, :validate => :string
  # Specifies use which region of DIS, now DIS only support cn-north-1
  config :region, :validate => :string, :default => "cn-north-1"
  # The Access Key ID for hwclouds, it can be obtained from My Credential Page
  config :ak, :validate => :string
  # The Secret key ID is encrypted or not
  config :is_sk_encrypted, :default => false
  # The encrypt key used to encypt the Secret Key Id
  config :encrypt_key, :validate => :string
  # The Secret Key ID for hwclouds, it can be obtained from My Credential Page
  config :sk, :validate => :string
  # Serializer class for the key of the message
  config :key_serializer, :validate => :string, :default => 'com.huaweicloud.dis.adapter.kafka.common.serialization.StringSerializer'
  # Serializer class for the value of the message
  config :value_serializer, :validate => :string, :default => 'com.huaweicloud.dis.adapter.kafka.common.serialization.StringSerializer'

  public
  def register
    @thread_batch_map = Concurrent::Hash.new

    if !@retries.nil? 
      if @retries < 0
        raise ConfigurationError, "A negative retry count (#{@retries}) is not valid. Must be a value >= 0"
      end

      @logger.warn("Kafka output is configured with finite retry. This instructs Logstash to LOSE DATA after a set number of send attempts fails. If you do not want to lose data if Kafka is down, then you must remove the retry setting.", :retries => @retries)
    end


    @producer = create_producer
    if value_serializer == 'com.huaweicloud.dis.adapter.kafka.common.serialization.StringSerializer'
      @codec.on_event do |event, data|
        write_to_dis(event, data)
      end
    elsif value_serializer == 'com.huaweicloud.dis.adapter.kafka.common.serialization.ByteArraySerializer'
      @codec.on_event do |event, data|
        write_to_dis(event, data.to_java_bytes)
      end
    else
      raise ConfigurationError, "'value_serializer' only supports com.huaweicloud.dis.adapter.kafka.common.serialization.ByteArraySerializer and com.huaweicloud.dis.adapter.kafka.common.serialization.StringSerializer" 
    end
  end

  # def register

  def prepare(record)
    # This output is threadsafe, so we need to keep a batch per thread.
    @thread_batch_map[Thread.current].add(record)
  end

  def multi_receive(events)
    t = Thread.current
    if !@thread_batch_map.include?(t)
      @thread_batch_map[t] = java.util.ArrayList.new(events.size)
    end

    events.each do |event|
      break if event == LogStash::SHUTDOWN
      @codec.encode(event)
    end

    batch = @thread_batch_map[t]
    if batch.any?
      retrying_send(batch)
      batch.clear
    end
  end

  def retrying_send(batch)
    remaining = @retries;

    while batch.any?
      if !remaining.nil?
        if remaining < 0
          # TODO(sissel): Offer to DLQ? Then again, if it's a transient fault,
          # DLQing would make things worse (you dlq data that would be successful
          # after the fault is repaired)
          logger.info("Exhausted user-configured retry count when sending to Kafka. Dropping these events.",
                      :max_retries => @retries, :drop_count => batch.count)
          break
        end

        remaining -= 1
      end

      failures = []

      futures = batch.collect do |record| 
        begin
          # send() can throw an exception even before the future is created.
          @producer.send(record)
        rescue org.apache.kafka.common.errors.TimeoutException => e
          failures << record
          nil
        rescue org.apache.kafka.common.errors.InterruptException => e
          failures << record
          nil
        rescue com.huaweicloud.dis.adapter.kafka.common.errors.SerializationException => e
          # TODO(sissel): Retrying will fail because the data itself has a problem serializing.
          # TODO(sissel): Let's add DLQ here.
          failures << record
          nil
        end
      end.compact

      futures.each_with_index do |future, i|
        begin
          result = future.get()
        rescue => e
          # TODO(sissel): Add metric to count failures, possibly by exception type.
          logger.warn("KafkaProducer.send() failed: #{e}", :exception => e)
          failures << batch[i]
        end
      end

      # No failures? Cool. Let's move on.
      break if failures.empty?

      # Otherwise, retry with any failed transmissions
      batch = failures
      delay = @retry_backoff_ms / 1000.0
      logger.info("Sending batch to DIS failed. Will retry after a delay.", :batch_size => batch.size,
                  :failures => failures.size, :sleep => delay);
      sleep(delay)
    end

  end

  def close
    @producer.close
  end

  private

  def write_to_dis(event, serialized_data)
    stream = event.get("stream");
	if stream.nil?
	  stream = @stream;
	end

	message_key = event.get("partition_key");
	if message_key.nil?
	  message_key = @message_key;
	end

	partition_id = event.get("partition_id");

	if message_key.nil? && partition_id.nil?
	  # record = ProducerRecord.new(event.sprintf(@stream), serialized_data)
	  record = ProducerRecord.new(stream, serialized_data)
	elsif partition_id.nil?
	  # record = ProducerRecord.new(event.sprintf(@stream), event.sprintf(@message_key), serialized_data)
	  # record = ProducerRecord.new(stream, event.sprintf(@message_key), serialized_data)
	  record = ProducerRecord.new(stream, message_key, serialized_data)
	else
	  record = ProducerRecord.new(stream, partition_id.to_i, message_key, serialized_data)
	end
	prepare(record)
  rescue LogStash::ShutdownSignal
    @logger.debug('DIS Kafka producer got shutdown signal')
  rescue => e
    @logger.warn('DIS kafka producer threw exception, restarting',
                 :exception => e)
  end

  def create_producer
    begin
      props = java.util.Properties.new
      kafka = com.huaweicloud.dis.adapter.kafka.clients.producer.ProducerConfig

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
      
      props.put("batch.size", batch_size.to_s)
      props.put("batch.count", batch_count.to_s)
      props.put("buffer.memory", buffer_memory.to_s)
      props.put("buffer.count", buffer_count.to_s)
      props.put("linger.ms", linger_ms.to_s)
      props.put("block.on.buffer.full", block_on_buffer_full.to_s)
      props.put("max.block.ms", max_block_ms.to_s)
      props.put("backoff.max.interval.ms", backoff_max_interval_ms.to_s)
      props.put("max.in.flight.requests.per.connection", max_in_flight_requests_per_connection.to_s)
      props.put("records.retriable.error.code", records_retriable_error_code) unless records_retriable_error_code.nil?
      props.put("order.by.partition", order_by_partition.to_s)
      props.put("metadata.timeout.ms", metadata_timeout_ms.to_s)
      # props.put(kafka::RETRIES_CONFIG, retries.to_s) unless retries.nil?
      # props.put(kafka::RETRY_BACKOFF_MS_CONFIG, retry_backoff_ms.to_s)
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


      com.huaweicloud.dis.adapter.kafka.clients.producer.DISKafkaProducer.new(props)
    rescue => e
      logger.error("Unable to create DIS Kafka producer from given configuration",
                   :kafka_error_message => e,
                   :cause => e.respond_to?(:getCause) ? e.getCause() : nil)
      raise e
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

end #class LogStash::Outputs::Dis
