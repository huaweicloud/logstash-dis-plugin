# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require 'logstash/outputs/dis'
require 'json'

describe "outputs/dis" do
  let (:simple_dis_config) {{'stream' => 'test', 'project_id' => 'test_project_id', 'ak' => 'test_ak', 'sk' => 'test_sk'}}
  let (:event) { LogStash::Event.new({'message' => 'hello', 'stream_name' => 'my_stream', 'host' => '127.0.0.1',
                                      '@timestamp' => LogStash::Timestamp.now}) }

  context 'when initializing' do
    it "should register" do
      output = LogStash::Plugin.lookup("output", "dis").new(simple_dis_config)
      expect {output.register}.to_not raise_error
    end

    it 'should populate dis config with default values' do
      dis = LogStash::Outputs::Dis.new(simple_dis_config)
      insist {dis.endpoint} == 'https://dis.cn-north-1.myhuaweicloud.com'
      insist {dis.stream} == 'test'
      insist {dis.key_serializer} == 'com.huaweicloud.dis.adapter.kafka.common.serialization.StringSerializer'
    end
  end

  context 'when outputting messages' do
    #it 'should send logstash event to DIS' do
      #expect_any_instance_of(com.huaweicloud.dis.adapter.kafka.clients.producer.DISKafkaProducer).to receive(:send)
        #.with(an_instance_of(com.huaweicloud.dis.adapter.kafka.clients.producer.ProducerRecord)).and_call_original
      #dis = LogStash::Outputs::Dis.new(simple_dis_config)
      #dis.register
      #dis.multi_receive([event])
    #end

    #it 'should support field referenced message_keys' do
      #expect(com.huaweicloud.dis.adapter.kafka.clients.producer.ProducerRecord).to receive(:new)
        #.with("test", "127.0.0.1", event.to_s).and_call_original
      #expect_any_instance_of(com.huaweicloud.dis.adapter.kafka.clients.producer.DISKafkaProducer).to receive(:send).and_call_original
      #dis = LogStash::Outputs::Dis.new(simple_dis_config.merge({"message_key" => "%{host}"}))
      #dis.register
      #dis.multi_receive([event])
    #end
  end
  
  context "when DISKafkaProducer#send() raises an exception" do
    let(:failcount) { (rand * 10).to_i }
    let(:sendcount) { failcount + 1 }

    let(:exception_classes) { [
      com.huaweicloud.dis.adapter.kafka.common.errors.TimeoutException,
      com.huaweicloud.dis.adapter.kafka.common.errors.InterruptException,
      com.huaweicloud.dis.adapter.kafka.common.errors.SerializationException 
    ] }

    before do
      count = 0
      expect_any_instance_of(com.huaweicloud.dis.adapter.kafka.clients.producer.DISKafkaProducer).to receive(:send)
        .exactly(sendcount).times
        .and_wrap_original do |m, *args|
        if count < failcount # fail 'failcount' times in a row.
          count += 1
          # Pick an exception at random
          raise exception_classes.shuffle.first.new("injected exception for testing")
        else
          #m.call(*args) # call original
        end
      end
    end

    it "should retry until successful" do
      dis = LogStash::Outputs::Dis.new(simple_dis_config)
      dis.register
      dis.multi_receive([event])
    end
  end

  context "when a send fails" do
    context "and the default retries behavior is used" do
      # Fail this many times and then finally succeed.
      let(:failcount) { (rand * 10).to_i }

      # Expect DISKafkaProducer.send() to get called again after every failure, plus the successful one.
      let(:sendcount) { failcount + 1 }


      it "should retry until successful" do
        count = 0;

        expect_any_instance_of(com.huaweicloud.dis.adapter.kafka.clients.producer.DISKafkaProducer).to receive(:send)
              .exactly(sendcount).times
              .and_wrap_original do |m, *args|
          if count < failcount
            count += 1
            # inject some failures.

            # Return a custom Future that will raise an exception to simulate a DIS send() problem.
            future = java.util.concurrent.FutureTask.new { raise "Failed" }
            future.run
            future
          else
            #m.call(*args)
          end
        end
        dis = LogStash::Outputs::Dis.new(simple_dis_config)
        dis.register
        dis.multi_receive([event])
      end
    end

    context "and when retries is set by the user" do
      let(:retries) { (rand * 10).to_i }
      let(:max_sends) { retries + 1 }

      it "should give up after retries are exhausted" do
        expect_any_instance_of(com.huaweicloud.dis.adapter.kafka.clients.producer.DISKafkaProducer).to receive(:send)
              .at_most(max_sends).times
              .and_wrap_original do |m, *args|
          # Always fail.
          future = java.util.concurrent.FutureTask.new { raise "Failed" }
          future.run
          future
        end
        dis = LogStash::Outputs::Dis.new(simple_dis_config.merge("retries" => retries))
        dis.register
        dis.multi_receive([event])
      end
    end
  end
end
