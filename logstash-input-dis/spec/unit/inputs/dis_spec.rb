# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "logstash/inputs/dis"
require "concurrent"

class MockConsumer
  def initialize
    @wake = Concurrent::AtomicBoolean.new(false)
  end

  def subscribe(topics)
  end
  
  def poll(ms)
    if @wake.value
      raise org.apache.kafka.common.errors.WakeupException.new
    else
      10.times.map do
        com.huaweicloud.dis.adapter.kafka.clients.consumer.ConsumerRecord.new("logstash", 0, 0, "key", "value")
      end
    end
  end

  def close
  end

  def wakeup
    @wake.make_true
  end
end

describe LogStash::Inputs::Dis do
  let(:config) { { 'streams' => ['logstash'], 'project_id' => 'test_project_id', 'ak' => 'test_ak', 'sk' => 'test_sk' } }
  subject { LogStash::Inputs::Dis.new(config) }

  it "should register" do
    expect {subject.register}.to_not raise_error
  end
end
