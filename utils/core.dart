import 'dart:convert';
import 'dart:io';

import 'global.dart';
import 'logger.dart';

class AgentMain {
  /// 软件版本
  static String version() {
    return '0.1.0';
  }

  /// 初始化用户配置文件
  static Map<String, dynamic> _config() {
    File file = File('agent.json');
    String content = file.readAsStringSync();
    return jsonDecode(content);
  }

  ///初始化应用程序
  static void init() {
    File file = File('agent.json');
    if (!file.existsSync()) {
      Logger.warn("Config file not found, creating a new one...");
      file.createSync();
      const String content = '''
{
  "host": "127.0.0.1",
  "httpPort": 2519,
  "wsPort": 2520,
  "token": "",
  "freeText": "Mem",
  "python":"default",
  "nbcli":"default",
  "color":"light",
  "checkUpdate": true,
  "encoding": "systemEncoding",
  "httpencoding": "utf8",
  "botEncoding": "systemEncoding",
  "protocolEncoding": "utf8",
  "deployEncoding": "systemEncoding",
  "mirror": "https://registry.nonebot.dev",
  "refreshMode": "auto"
}
''';
      file.writeAsStringSync(content);
      Logger.success("Config file created successfully.");
    }
  Directory botDir = Directory('bots/');
  Directory instanceDir = Directory('instance/');
  if (!botDir.existsSync()) {
    botDir.createSync();
  }
  if (!instanceDir.existsSync()) {
    instanceDir.createSync();
  }
  MainApp.botList = AgentMain.loadBots();
}

  /// 获取主机
  static String host() {
    Map<String, dynamic> jsonMap = _config();
    if (jsonMap.containsKey("host")) {
      String host = jsonMap['host'].toString();
      return host;
    } else {
      return 'localhost';
    }
  }

  /// 获取端口
  static int httpPort() {
    Map<String, dynamic> jsonMap = _config();
    if (jsonMap.containsKey("httpPort")) {
      int port = jsonMap['httpPort'];
      return port;
    } else {
      return 2519;
    }
  }

  // webSocket 端口
  static int wsPort() {
    Map<String, dynamic> jsonMap = _config();
    if (jsonMap.containsKey("wsPort")) {
      int port = jsonMap['wsPort'];
      return port;
    } else {
      return 2520;
    }
  }

  /// 获取token
  static String? token() {
    Map<String, dynamic> jsonMap = _config();
    if (jsonMap['token'].toString().isNotEmpty) {
      String token = jsonMap['token'].toString();
      return token;
    } else {
      Logger.error("Token is empty, please set it in agent.json.");
      exit(1);
    }
  }

  /// Linux 中执行 free 命令时显示的文字[Mem/内存]
  static String freeText() {
    Map<String, dynamic> jsonMap = _config();
    if (jsonMap.containsKey("freeText")) {
      String text = jsonMap['freeText'].toString();
      return text;
    } else {
      return 'Mem';
    }
  }

  /// 读取配置文件
  static List<dynamic> loadBots() {
    final jsonList = <dynamic>[];
    Directory dir = Directory('bots');
    List<FileSystemEntity> files = dir.listSync();
    for (FileSystemEntity file in files) {
      if (file is File && file.path.endsWith('.json')) {
        String contents = file.readAsStringSync();
        var jsonObject = jsonDecode(contents);
        jsonList.add(jsonObject);
      }
    }

    return jsonList;
  }
}

/// 主机系统监控
class System {
  /// 获取系统状态
  static status() async {
    if (Platform.isLinux || Platform.isMacOS) {
      // 获取 CPU 使用率
      var getCpuStatus = await Process.run(
        'bash',
        [
          '-c',
          'top -bn1 | grep "Cpu(s)" | sed "s/.*, *\\([0-9.]*\\)%* id.*/\\1/" | awk \'{print 100 - \$1}\''
        ],
      );
      String cpuUsage = getCpuStatus.stdout.toString().trim();

      // 获取内存使用率
      var getMemStatus = await Process.run(
        'bash',
        [
          '-c',
          "free | grep ${AgentMain.freeText()} | awk '{print \$3/\$2 * 100.0}'"
        ],
      );
      String memUsage = getMemStatus.stdout.toString().trim().substring(0, 4);

      return '{"cpu_usage": "$cpuUsage%", "memory_usage": "$memUsage%"}';
    }

    if (Platform.isWindows) {
      // 获取 CPU 使用率
      String cpuCommand =
          'Get-CimInstance Win32_Processor | Select-Object -ExpandProperty LoadPercentage';
      var getCpuStatus =
          await Process.run('powershell', ['-Command', cpuCommand]);
      String cpuUsage = getCpuStatus.stdout.toString().trim();

      // 获取内存使用率
      String memCommand = '''
      Get-CimInstance Win32_OperatingSystem |
      Select-Object @{Name="MemoryUsage";Expression={"{0:N2}" -f ((\$_.TotalVisibleMemorySize - \$_.FreePhysicalMemory) / \$_.TotalVisibleMemorySize * 100)}} |
      Select-Object -ExpandProperty MemoryUsage
      ''';
      var getMemStatus =
          await Process.run('powershell', ['-Command', memCommand]);
      String memUsage = getMemStatus.stdout.toString().trim().substring(0, 4);

      return '{"cpu_usage": "$cpuUsage%", "memory_usage": "$memUsage%"}';
    }

    return '{"error": "Unsupported platform"}';
  }

  /// 获取系统平台
  static platform() {
    if (Platform.isLinux) {
      return '{"platform": "Linux"}';
    }
    if (Platform.isMacOS) {
      return '{"platform": "macOS"}';
    }
    if (Platform.isWindows) {
      return '{"platform": "Windows"}';
    }
    return {"error": "Unsupported platform"};
  }
}


