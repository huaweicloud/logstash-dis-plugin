# Logstash Input DIS

This is a plugin for [Logstash](https://github.com/elastic/logstash).

## Requirements

To get started using this plugin, you will need three things:

1. JDK 1.8 +
2. JRuby with the Bundler gem installed, 9.0.0.0 ~ 9.2.0.0
3. Maven
4. Logstash

## Installation
### 0. 修改 RubyGems 镜像地址
    gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/

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
        endpoint => "https://dis.cn-north-1.myhuaweicloud.com"
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
| streams                   | 指定在DIS服务上创建的通道名称。             | -                                        |
| ak                       | 用户的Access Key，可从华为云控制台“我的凭证”页获取。 | -                                        |
| sk                       | 用户的Secret Key，可从华为云控制台“我的凭证”页获取。 | -                                        |
| region                   | 将数据上传到指定Region的DIS服务。           | cn-north-1                               |
| project_id               | 用户所属区域的项目ID，可从华为云控制台“我的凭证”页获取。                    | -                                        |
| endpoint                 | DIS对应Region的数据接口地址。               | https://dis.cn-north-1.myhuaweicloud.com |
| group_id                 | DIS App名称，用于标识一个消费组，值可以为任意字符串。| -                                        |

## License
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0.html)