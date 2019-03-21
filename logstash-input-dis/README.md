# Logstash Input DIS

This is a plugin for [Logstash](https://github.com/elastic/logstash).

## Requirements

To get started using this plugin, you will need three things:

1. JDK 1.8 +
2. JRuby with the Bundler gem installed, 9.0.0.0 +
3. Maven
4. Logstash, 6.0.0 to 6.1.0

## Installation
当前插件未发布到`RubyGems.org`，无法直接从`RubyGems.org`安装插件，只能从本地安装。
### 0. 修改 RubyGems 镜像地址
    gem sources --add https://gems.ruby-china.org/ --remove https://rubygems.org/

### 0. 安装 dis-kafka-adapter

### 1. 安装 JRuby
### 2. 安装 Bundler gem
    gem install bundler

### 3. 安装依赖
    bundle install
    rake install_jars
    gem build logstash-input-dis.gemspec

### 4. 编辑 Logstash 的`Gemfile`，并添加本地插件路径
    gem "logstash-input-dis", :path => "/your/local/logstash-input-dis"

### 5. 安装插件到 Logstash
    bin/logstash-plugin install --no-verify

## Usage

```properties
input
{
   dis {
        streams => ["YOU_DIS_STREAM_NAME"]
        endpoint => "https://dis.cn-north-1.myhuaweicloud.com:20004"
        ak => "YOU_ACCESS_KEY_ID"
        sk => "YOU_SECRET_KEY_ID"
        region => "cn-north-1"
        project_id => "YOU_PROJECT_ID"
        group_id => "YOU_GROUP_ID"
        decorate_events => true
        auto_offset_reset => "earliest"
    }
}
```

## Configuration

### Parameters

| Name                     | Description                              | Default                                  |
| :----------------------- | :--------------------------------------- | :--------------------------------------- |
| streams                  | A list of DIS streams to subscribe to    | -                                        |
| ak                       | The Access Key ID for hwclouds, it can be obtained from **My Credential** Page | -                                        |
| sk                       | The Secret Key ID for hwclouds, it can be obtained from **My Credential** Page | -                                        |
| region                   | Specifies use which region of DIS, now DIS only support `cn-north-1` | cn-north-1                               |
| project_id               | The ProjectId of the specified region, it can be obtained from **My Credential** Page | -                                        |
| endpoint                 | DIS endpoint                       | https://dis.cn-north-1.myhuaweicloud.com:20004 |
| group_id                 | Application id that is created on DIS service  | -                                        |

## License
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0.html)