import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'global.dart';
import 'logger.dart';
import 'user_config.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class AgentMain {
  /// 软件版本
  static String version() {
    return '0.1.8+1';
  }

  /// 初始化用户配置文件
  static Map<String, dynamic> _config() {
    File file = File('config.json');
    String content = file.readAsStringSync();
    return jsonDecode(content);
  }

  ///初始化应用程序
  static void init() async {
    Logger.rainbow('logo',
        '  _   _                  ____        _        _                    _   ');
    Logger.rainbow('logo',
        ' | \\ | | ___  _ __   ___| __ )  ___ | |_     / \\   __ _  ___ _ __ | |_ ');
    Logger.rainbow('logo',
        ' |  \\| |/ _ \\| \'_ \\ / _ |  _ \\ / _ \\| __|   / _ \\ / _` |/ _ | \'_ \\| __|');
    Logger.rainbow('logo',
        ' | |\\  | (_) | | | |  __| |_) | (_) | |_   / ___ | (_| |  __| | | | |_ ');
    Logger.rainbow('logo',
        ' |_| \\_|\\___/|_| |_|\\___|____/ \\___/ \\__| /_/   \\_\\__, |\\___|_| |_|\\__|');
    Logger.rainbow('logo',
        '                                                |___/                 ');
    var uuid = Uuid();
    String token = uuid.v4().replaceAll('-', '').substring(0, 8);
    File file = File('config.json');
    if (!file.existsSync()) {
      Logger.warn("Config file not found, creating a new one...");
      file.createSync();
      final String content = '''
{
  "host": "127.0.0.1",
  "port": 2519,
  "token": "$token",
  "logMaxLines": 75,
  "python":"default",
  "nbcli":"default",
  "color":"light",
  "checkUpdate": true,
  "wss": {
    "enabled": false,
    "certpath": "",
    "keypath": ""
    }
}
''';
      file.writeAsStringSync(content);
      Logger.success("Config file created successfully.");
    }
    Directory botDir = Directory('bots/');
    Directory instanceDir = Directory('instance/');
    Directory cacheDir = Directory('cache/');
    if (!botDir.existsSync()) {
      botDir.createSync();
    }
    if (!instanceDir.existsSync()) {
      instanceDir.createSync();
    }
    if (!cacheDir.existsSync()) {
      cacheDir.createSync();
    }
    MainApp.botList = AgentMain.loadBots();
    await getPyVer();
    await getnbcliver();
    if (MainApp.python == '你似乎还没有安装python？') {
      Logger.warn('It seems that you have not installed python?');
    }
    if (MainApp.nbcli == '你似乎还没有安装nb-cli？') {
      Logger.warn('It seems that you have not installed nb-cli?');
    }
    if (UserConfig.checkUpdate()) {
      await check();
    }
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
  static int port() {
    Map<String, dynamic> jsonMap = _config();
    if (jsonMap.containsKey("httpPort")) {
      int port = jsonMap['httpPort'];
      return port;
    } else {
      return 2519;
    }
  }

  /// wss是否启用(beta)
  static Map wss() {
    Map<String, dynamic> jsonMap = _config();
    if (jsonMap.containsKey("wss")) {
      Map wss = jsonMap['wss'];
      return wss;
    } else {
      return {"enabled": false, "certpath": "", "keypath": ""};
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
    // Linux
    if (Platform.isLinux) {
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
        ['-c', "LC_ALL='c' free | grep Mem | awk '{print \$3/\$2 * 100.0}'"],
      );
      String memUsage = getMemStatus.stdout.toString().trim().substring(0, 4);

      return '{"cpu_usage": "$cpuUsage%", "ram_usage": "$memUsage%"}';
    }

    // Windows
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

      return '{"cpu_usage": "$cpuUsage%", "ram_usage": "$memUsage%"}';
    }

    if (Platform.isMacOS) {
      // 获取内存使用率
      const script = '''
      pages_info=\$(vm_stat | grep "Pages" | awk '{print \$NF}' | sed 's/[^0-9]//g')
      active_pages=\$(echo "\$pages_info" | sed -n '2p')
      inactive_pages=\$(echo "\$pages_info" | sed -n '3p')
      wired_pages=\$(echo "\$pages_info" | sed -n '6p')
      active_pages=\${active_pages:-0}
      inactive_pages=\${inactive_pages:-0}
      wired_pages=\${wired_pages:-0}
      used_pages=\$((active_pages + inactive_pages + wired_pages))
      total_mem=\$(sysctl hw.memsize | awk '{print \$2}')
      page_size=4096
      total_pages=\$((total_mem / page_size))
      if [ \$total_pages -gt 0 ]; then
        echo "scale=2; \$used_pages * 100 / \$total_pages" | bc
      else
        echo "0"
      fi
    ''';

      // 获取 CPU 使用率
      var getCpuStatus = await Process.run(
        'bash',
        ['-c', 'top -l 1 | grep "CPU usage" | awk \'{print \$3}\''],
      );
      String cpuUsage = getCpuStatus.stdout.toString().trim();

      // 获取内存使用率
      var getMemStatus = await Process.run(
        'bash',
        ['-c', script],
      );
      String memUsage = getMemStatus.stdout.toString().trim();

      return '{"cpu_usage": "$cpuUsage%", "ram_usage": "$memUsage%"}';
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

// 生成uuid
String generateUUID() {
  var uuid = Uuid();
  String v4 = uuid.v4();
  String id = v4.replaceAll('-', '');
  return id;
}

// 向客户端发送WebSocket消息
void sendMessageToClients(String message) {
  for (var client in wsChannels) {
    client.sink.add(message);
  }
}

///检查py
Future<String> getPyVer() async {
  try {
    ProcessResult results =
        await Process.run('${UserConfig.pythonPath()}', ['--version']);
    MainApp.python = results.stdout.trim();
    return MainApp.python;
  } catch (e) {
    MainApp.python = '你似乎还没有安装python？';
    return MainApp.python;
  }
}

///检查nbcli
Future<String> getnbcliver() async {
  try {
    final ProcessResult results =
        await Process.run('${UserConfig.nbcliPath()}', ['-V']);
    MainApp.nbcli = results.stdout;
    return MainApp.nbcli;
  } catch (error) {
    MainApp.nbcli = '你似乎还没有安装nb-cli？';
    return MainApp.nbcli;
  }
}

Future<void> check() async {
  try {
    final response = await http.get(Uri.parse(
        'https://api.github.com/repos/NonebotGUI/nonebot-agent/releases/latest'));
    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final tagName = jsonData['tag_name'];
      final url = jsonData['html_url'];
      if (tagName.toString().replaceAll('v', '') != AgentMain.version()) {
        Logger.rainbow('New version',
            '################################################################');
        Logger.rainbow('New version',
            '##                                                            ##');
        Logger.rainbow('New version',
            '##       A new version of Nonebot Agent is available!         ##');
        Logger.rainbow('New version',
            '##                                                            ##');
        Logger.rainbow('New version',
            '################################################################');
        Logger.info('New version found: $tagName');
        Logger.info('To download the latest version, please visit: $url');
      }
    } else {
      Logger.error('Failed to check for updates');
    }
  } catch (e) {
    Logger.error('Failed to check for updates: $e');
  }
}
