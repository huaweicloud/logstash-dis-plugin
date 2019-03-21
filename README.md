# Huawei Cloud DIS Plugins for Logstash

DIS Logstash Plugin是数据接入服务（DIS）为Logstash开发的插件，包含DIS Input与DIS Output。DIS Input用于从DIS服务下载数据到Logstash，DIS Output用于将Logstash中的数据上传到DIS服务。

## 一、安装插件
### 1.1 下载编译好的DIS Logstash Plugin安装包，[地址](https://dis-publish.obs-website.cn-north-1.myhwclouds.com/dis-logstash-plugins-1.0.0.zip)
### 1.2. 使用PuTTY工具(或其他终端工具)远程登录Logstash服务器
### 1.3. 进入到Logstash的安装目录
```console
cd ${LOGSTASH_HOME}
```
### 1.4. 上传“dis-logstash-plugins-X.X.X.zip”安装包到此目录下
### 1.5. 解压安装包
```console
unzip dis-logstash-plugins-X.X.X.zip
```
### 1.6. 进入安装包解压后的目录
```console
cd logstash-plugins
```
### 1.7. 运行安装程序，需要指定Logstash的安装目录
```console
bash install.sh –p ${LOGSTASH_HOME}
```
安装完成后，显示类似如下内容，表示安装成功。
```
Install dis-logstash-plugins successfully.
```

## 二、参数配置
### 2.1 logstash-input-dis参数配置
| Name                     | Description                              | Default                                  |
| :----------------------- | :--------------------------------------- | :--------------------------------------- |
| stream                   | 指定在DIS服务上创建的通道名称。             | -                                        |
| ak                       | 用户的Access Key，可从华为云控制台“我的凭证”页获取。 | -                                        |
| sk                       | 用户的Secret Key，可从华为云控制台“我的凭证”页获取。 | -                                        |
| region                   | 将数据上传到指定Region的DIS服务。           | cn-north-1                               |
| project_id               | 用户所属区域的项目ID，可从华为云控制台“我的凭证”页获取。                    | -                                        |
| endpoint                 | DIS对应Region的数据接口地址。               | https://dis.cn-north-1.myhuaweicloud.com |
| group_id                 | DIS App名称，用于标识一个消费组，值可以为任意字符串。| -                                        |

### 2.2 logstash-output-dis参数配置
| Name                     | Description                              | Default                                  |
| :----------------------- | :--------------------------------------- | :--------------------------------------- |
| stream                   | 指定在DIS服务上创建的通道名称。             | -                                        |
| ak                       | 用户的Access Key，可从华为云控制台“我的凭证”页获取。 | -                                        |
| sk                       | 用户的Secret Key，可从华为云控制台“我的凭证”页获取。 | -                                        |
| region                   | 将数据上传到指定Region的DIS服务。           | cn-north-1                               |
| project_id               | 用户所属区域的项目ID，可从华为云控制台“我的凭证”页获取。                    | -                                        |
| endpoint                 | DIS对应Region的数据接口地址。               | https://dis.cn-north-1.myhuaweicloud.com |

## 三、源码编译
### 3.1 [logstash-input-dis源码编译](https://github.com/huaweicloud/logstash-dis-plugin/blob/master/logstash-input-dis/README.md)

### 3.2 [logstash-output-dis源码编译](https://github.com/huaweicloud/logstash-dis-plugin/blob/master/logstash-output-dis/README.md)

## License
[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0.html)