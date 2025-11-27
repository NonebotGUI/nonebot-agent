import 'package:web_socket_channel/web_socket_channel.dart';

//全局变量

String gOnOpen = "";
List<WebSocketChannel> wsChannels = [];
bool canAutoStart = true;

class MainApp {
  ///Bot列表
  static late List botList;

  ///用户python版本
  static late String python;

  ///用户nbcli版本
  static late String nbcli;
}

///快速部署相关
class FastDeploy {
  ///快速部署页面
  static late int page;

  ///编号
  static late int id;

  ///下载连接
  static late List<String> dlLink;

  ///部署时是否启用虚拟环境
  static late bool venv;

  ///部署路径
  static late String path;

  ///选择的路径
  static late String selectPath;

  ///部署名称
  static late String name;

  ///Websocket主机
  static late String wsHost;

  ///Websocket端口
  static late String wsPort;

  ///协议端本体解压后的目录
  static late String extDir;

  ///协议端配置文件
  static late String botConfig;

  ///协议端配置文件是否包含QQ号
  static late bool needQQ;

  ///如果需要QQ号，那么Bot的QQ号是？（诶诶真麻烦）
  static late String botQQ;

  ///协议端配置文件的相对路径
  static late String configPath;

  ///协议端配置文件的名称
  static late String configName;

  ///配套安装的驱动器
  static late String driver;

  ///配套安装的适配器
  static late String adapter;

  ///启动协议端的命令
  static late String cmd;

  ///模板
  static late String template;

  ///插件存放位置
  static late String pluginDir;

  ///协议端文件名
  static late String protocolFileName;
}

///创建Bot相关
class Create {
  ///Bot名称
  static late String name;

  ///Bot路径
  static late String? path;

  ///是否启用虚拟环境
  static late bool venv;

  ///是否立刻安装依赖
  static late bool installDep;

  ///适配器
  static late String adapter;

  ///驱动器
  static late String driver;

  ///模板
  static late String template;

  ///插件存放位置
  static late String pluginDir;
}
