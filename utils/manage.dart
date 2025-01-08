import 'dart:convert';
import 'dart:io';
import 'core.dart';
import 'global.dart';
import 'user_config.dart';
import 'package:toml/toml.dart';

class Bot {
  static Map<String, dynamic> _config(id) {
    File file = File('bots/$id.json');
    String content = file.readAsStringSync();
    return jsonDecode(content);
  }

  /// 获取Bot名称
  static String name(id) {
    Map<String, dynamic> jsonMap = _config(id);
    return jsonMap['name'].toString();
  }

  /// 获取Bot的创建时间
  static String time(id) {
    Map<String, dynamic> jsonMap = _config(id);
    return jsonMap['time'].toString();
  }

  /// 获取Bot的路径
  static String path(id) {
    Map<String, dynamic> jsonMap = _config(id);
    return jsonMap['path'].toString();
  }

  /// 获取Bot日志
  static Future<String> log(id) async {
    File file = File('${Bot.path(id)}/nbgui_stdout.log');
    if (file.existsSync()) {
      List<String> lines = file.readAsLinesSync(encoding: systemEncoding);
      int start = lines.length > UserConfig.logMaxLines()
          ? lines.length - UserConfig.logMaxLines()
          : 0;
      return lines.sublist(start).join('\n');
    } else {
      return '[INFO] Welcome to NoneBot WebUI!';
    }
  }

  /// 获取Bot运行状态
  static bool status(id) {
    Map<String, dynamic> jsonMap = _config(id);
    return jsonMap['isRunning'];
  }

  /// 获取Bot Pid
  static String pid(id) {
    Map<String, dynamic> jsonMap = _config(id);
    return jsonMap['pid'].toString();
  }

  /// 直接抓取Bot日志的的Python Pid
  static pypid(path) {
    File file = File('$path/nbgui_stdout.log');
    RegExp regex = RegExp(r'Started server process \[(\d+)\]');
    Match? match =
        regex.firstMatch(file.readAsStringSync(encoding: systemEncoding));
    if (match != null && match.groupCount >= 1) {
      String pid = match.group(1)!;
      return pid;
    }
  }

  /// 唤起Bot进程
  static Future run(id) async {
    File cfgFile = File('bots/$id.json');
    final stdout = File('${Bot.path(id)}/nbgui_stdout.log');
    final stderr = File('${Bot.path(id)}/nbgui_stderr.log');
    Process process = await Process.start('${UserConfig.nbcliPath()}', ['run'],
        workingDirectory: Bot.path(id));
    int pid = process.pid;

    /// 重写配置文件来更新状态
    Map<String, dynamic> jsonMap = jsonDecode(cfgFile.readAsStringSync());
    jsonMap['pid'] = pid;
    jsonMap['isRunning'] = true;
    cfgFile.writeAsStringSync(jsonEncode(jsonMap));

    final outputSink = stdout.openWrite();
    final errorSink = stderr.openWrite();

    // 直接监听原始字节输出
    process.stdout.listen((data) {
      outputSink.add(data);
    });

    process.stderr.listen((data) {
      errorSink.add(data);
    });
  }

  ///结束bot进程
  static stop(id) async {
    //读取配置文件
    File cfgFile = File('bots/$id.json');
    Map botInfo = json.decode(cfgFile.readAsStringSync());
    String pidString = botInfo['pid'].toString();
    int pid = int.parse(pidString);
    Process.killPid(pid);

    ///更新配置文件
    botInfo['isRunning'] = false;
    botInfo['pid'] = 'Null';
    cfgFile.writeAsStringSync(json.encode(botInfo));
    //如果平台为Windows则释放端口
    if (Platform.isWindows) {
      await Process.start(
          "taskkill.exe", ['/f', '/pid', Bot.pypid(Bot.path(id)).toString()],
          runInShell: true);
    }
  }

  ///重命名Bot
  static void rename(name, id) {
    // 重写配置文件
    File botcfg = File('bots/$id.json');
    Map<String, dynamic> jsonMap = jsonDecode(botcfg.readAsStringSync());
    jsonMap['name'] = name;
    botcfg.writeAsStringSync(jsonEncode(jsonMap));
  }

  ///获取stderr.log
  static String stderr(id) {
    File file = File('${Bot.path(id)}/nbgui_stderr.log');
    if (file.existsSync()) {
      return file.readAsStringSync();
    } else {
      return '';
    }
  }

  ///清空stderr.log
  static void deleteStderr(id) {
    File file = File('${Bot.path(id)}/nbgui_stderr.log');
    file.writeAsStringSync('');
  }

  ///删除Bot
  static void delete(id) async {
    File('bots/$id.json').delete();
    gOnOpen = '';
  }

  ///彻底删除Bot
  static void deleteForever(id) async {
    String path = Bot.path(id);
    Directory(path).delete(recursive: true);
    File('bots/$id.json').delete();
  }

  ///导入Bot
  static import(String name, String path, bool withProtocol,
      String protocolPath, String cmd) {
    DateTime now = DateTime.now();
    String id = generateUUID();
    String time =
        "${now.year}年${now.month}月${now.day}日${now.hour}时${now.minute}分${now.second}秒";
    File cfgFile = File('bots/$id.json');
    String type = withProtocol ? 'deployed' : 'imported';
    Map<String, dynamic> botInfo = {
      "name": name,
      "path": path,
      "time": time,
      "id": id,
      "isRunning": false,
      "pid": "Null",
      "type": type,
      "protocolPath": protocolPath,
      "cmd": cmd,
      "protocolPid": "Null",
      "protocolIsRunning": false
    };

    cfgFile.writeAsStringSync(jsonEncode(botInfo));
    return "echo 写入json";
  }
}

// 协议端相关操作
class Protocol {
  static final File _configFile = File('bots/${gOnOpen}.json');
  static Map<String, dynamic> _config() {
    File file = File('bots/${gOnOpen}.json');
    String content = file.readAsStringSync();
    return jsonDecode(content);
  }

  ///协议端路径
  static String path() {
    Map<String, dynamic> jsonMap = _config();
    return jsonMap['protocolPath'].toString().replaceAll('\\\\', '\\');
  }

  ///协议端运行状态
  static bool status() {
    Map<String, dynamic> jsonMap = _config();
    bool protocolStatus = jsonMap['protocolIsRunning'];
    return protocolStatus;
  }

  ///协议端pid
  static String pid() {
    Map<String, dynamic> jsonMap = _config();
    return jsonMap['protocolPid'].toString();
  }

  ///协议端启动命令
  static String cmd() {
    Map<String, dynamic> jsonMap = _config();
    return jsonMap['cmd'].toString();
  }

  ///启动协议端进程
  static Future run() async {
    Directory.current = Directory(Protocol.path());
    Map<String, dynamic> jsonMap = _config();
    String ucmd = Protocol.cmd();
    //分解cmd
    List<String> cmdList = ucmd.split(' ').toList();
    String pcmd = '';
    List<String> args = [];
    if (cmdList.length > 1) {
      pcmd = cmdList[0];
      args = cmdList.sublist(1);
    } else {
      pcmd = cmdList[0];
      args = [];
    }
    final stdout = File('${Protocol.path()}/nbgui_stdout.log');
    final stderr = File('${Protocol.path()}/nbgui_stderr.log');
    Process process =
        await Process.start(pcmd, args, workingDirectory: Protocol.path());
    int pid = process.pid;

    /// 重写配置文件来更新状态
    jsonMap['protocolPid'] = pid;
    jsonMap['protocolIsRunning'] = true;
    _configFile.writeAsStringSync(jsonEncode(jsonMap));

    final outputSink = stdout.openWrite();
    final errorSink = stderr.openWrite();

    // 直接监听原始字节输出
    process.stdout.listen((data) {
      outputSink.add(data);
    });

    process.stderr.listen((data) {
      errorSink.add(data);
    });
  }

  ///结束协议端进程
  static Future stop() async {
    Map botInfo = _config();
    String pidString = botInfo['protocolPid'].toString();
    int pid = int.parse(pidString);
    Process.killPid(pid, ProcessSignal.sigkill);
    //更新配置文件
    botInfo['protocolIsRunning'] = false;
    botInfo['protocolPid'] = 'Null';
    _configFile.writeAsStringSync(json.encode(botInfo));
  }

  ///更改协议端启动命令
  static void changeCmd(String cmd) {
    Map<String, dynamic> jsonMap = _config();
    jsonMap['cmd'] = cmd;
    _configFile.writeAsStringSync(jsonEncode(jsonMap));
  }
}

///Cli
class Cli {
  ///插件管理
  static plugin(mode, name) {
    if (mode == 'install') {
      String cmd = '${UserConfig.nbcliPath()} plugin install $name';
      return cmd;
    }
    if (mode == 'uninstall') {
      String cmd = '${UserConfig.nbcliPath()} plugin uninstall $name -y';
      return cmd;
    }
    return null;
  }

  ///适配器管理
  static adapter(mode, name) {
    if (mode == 'install') {
      String cmd = '${UserConfig.nbcliPath()} adapter install $name';
      return cmd;
    }
    if (mode == 'uninstall') {
      String cmd = '${UserConfig.nbcliPath()} adapter uninstall $name -y';
      return cmd;
    }
    return null;
  }

  ///驱动器管理
  static driver(mode, name) {
    if (mode == 'install') {
      String cmd = '${UserConfig.nbcliPath()} driver install $name';
      return cmd;
    }
    if (mode == 'uninstall') {
      String cmd = '${UserConfig.nbcliPath()} driver uninstall $name -y';
      return cmd;
    }
    return null;
  }

  ///CLI本体管理
  static self(mode, name) {
    if (mode == 'install') {
      String cmd = '${UserConfig.nbcliPath()} self install $name';
      return cmd;
    }
    if (mode == 'uninstall') {
      String cmd = '${UserConfig.nbcliPath()} self uninstall $name -y';
      return cmd;
    }
    if (mode == 'update') {
      String cmd = '${UserConfig.nbcliPath()} self update';
      return cmd;
    }
  }
}

///插件
class Plugin {
  ///禁用插件
  static disable(name, id) {
    File disable = File('${Bot.path(id)}/.disabled_plugins');
    File pyprojectFile = File('${Bot.path(id)}/pyproject.toml');
    String pyprojectContent = pyprojectFile.readAsStringSync();
    List<String> linesWithoutComments = pyprojectContent
        .split('\n')
        .map((line) {
          int commentIndex = line.indexOf('#');
          if (commentIndex != -1) {
            return line.substring(0, commentIndex).trim();
          }
          return line;
        })
        .where((line) => line.isNotEmpty)
        .toList();
    String pyprojectWithoutComments = linesWithoutComments.join('\n');
    var toml = TomlDocument.parse(pyprojectWithoutComments).toMap();
    var nonebot = toml['tool']['nonebot'];
    List pluginsList = nonebot['plugins'];

    // 移除指定的插件
    pluginsList.remove(name);
    nonebot['plugins'] = pluginsList;
    String updatedTomlContent = TomlDocument.fromMap(toml).toString();

    pyprojectFile.writeAsStringSync(updatedTomlContent);
    if (disable.readAsStringSync().isEmpty) {
      disable.writeAsStringSync(name);
    } else {
      disable.writeAsStringSync('${disable.readAsStringSync()}\n$name');
    }
  }

  ///启用插件
  static enable(name, id) {
    File disable = File('${Bot.path(id)}/.disabled_plugins');
    File pyprojectFile = File('${Bot.path(id)}/pyproject.toml');
    String pyprojectContent = pyprojectFile.readAsStringSync();
    var toml = TomlDocument.parse(pyprojectContent).toMap();
    var nonebot = toml['tool']['nonebot'];
    List pluginsList = nonebot['plugins'];

    if (!pluginsList.contains(name)) {
      pluginsList.add(name);
    }

    nonebot['plugins'] = pluginsList;
    String updatedTomlContent = TomlDocument.fromMap(toml).toString();
    pyprojectFile.writeAsStringSync(updatedTomlContent);
    String disabled = disable.readAsStringSync();
    List<String> disabledList = disabled.split('\n');
    disabledList.remove(name);
    disable.writeAsStringSync(disabledList.join('\n'));
  }

  ///获取插件列表
  static List list(id) {
    File pyprojectFile = File('${Bot.path(id)}/pyproject.toml');
    pyprojectFile.writeAsStringSync(pyprojectFile
        .readAsStringSync()
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n'));
    String pyprojectContent =
        pyprojectFile.readAsStringSync(encoding: systemEncoding);
    List<String> linesWithoutComments = pyprojectContent
        .split('\n')
        .map((line) {
          int commentIndex = line.indexOf('#');
          if (commentIndex != -1) {
            return line.substring(0, commentIndex).trim();
          }
          return line;
        })
        .where((line) => line.isNotEmpty)
        .toList();
    String pyprojectWithoutComments = linesWithoutComments.join('\n');
    // 解析 TOML 文件
    var toml = TomlDocument.parse(pyprojectWithoutComments).toMap();
    var nonebot = toml['tool']['nonebot'];
    List pluginsList = nonebot['plugins'];

    return pluginsList;
  }

  /// 获取禁用插件列表
  static List disabledList(id) {
    File disable = File('${Bot.path(id)}/.disabled_plugins');
    if (disable.existsSync()) {
      return disable.readAsStringSync().split('\n');
    } else {
      return [];
    }
  }

  /// 安装
  static install(name, id) async {
    List<String> commands = [Cli.plugin('install', name)];
    for (String command in commands) {
      List<String> args = command.split(' ');
      String executable = args.removeAt(0);
      Process process = await Process.start(
        executable,
        args,
        runInShell: true,
        workingDirectory: Bot.path(id),
      );
      process.stdout.transform(utf8.decoder).listen((data) {
        Map res = {
          'type': 'pluginInstallLog',
          'data': data,
        };
        sendMessageToClients(jsonEncode(res));
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        Map res = {
          'type': 'pluginInstallLog',
          'data': data,
        };
        sendMessageToClients(jsonEncode(res));
      });

      await process.exitCode;
      Map msg = {
        'type': 'installPluginStatus',
        'data': 'done',
      };
      sendMessageToClients(jsonEncode(msg));
    }
  }

  /// 卸载
  static uninstall(name, id) async {
    List<String> commands = [Cli.plugin('uninstall', name)];
    for (String command in commands) {
      List<String> args = command.split(' ');
      String executable = args.removeAt(0);
      Process process = await Process.start(
        executable,
        args,
        runInShell: true,
        workingDirectory: Bot.path(id),
      );
      process.stdout.transform(utf8.decoder).listen((data) {
        Map res = {
          'type': 'pluginUninstallLog',
          'data': data,
        };
        sendMessageToClients(jsonEncode(res));
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        Map res = {
          'type': 'pluginUninstallLog',
          'data': data,
        };
        sendMessageToClients(jsonEncode(res));
      });

      await process.exitCode;
    }
  }
}

// 适配器
class Adapter {
  /// 安装
  static install(name, id) async {
    List<String> commands = [Cli.adapter('install', name)];
    for (String command in commands) {
      List<String> args = command.split(' ');
      String executable = args.removeAt(0);
      Process process = await Process.start(
        executable,
        args,
        runInShell: true,
        workingDirectory: Bot.path(id),
      );
      process.stdout.transform(utf8.decoder).listen((data) {
        Map res = {
          'type': 'adapterInstallLog',
          'data': data,
        };
        sendMessageToClients(jsonEncode(res));
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        Map res = {
          'type': 'adapterInstallLog',
          'data': data,
        };
        sendMessageToClients(jsonEncode(res));
      });

      await process.exitCode;
      Map msg = {
        'type': 'installAdapterStatus',
        'data': 'done',
      };
      sendMessageToClients(jsonEncode(msg));
    }
  }
}
