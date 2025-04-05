import 'dart:io';
import 'core.dart';
import 'global.dart';
import 'user_config.dart';

///部署Bot时的相关操作
class DeployBot {
  ///写入requirements.txt
  static writeReq(String path, String name, drivers, adapters) {
    String driverList = drivers
        .map((d) => 'nonebot2[${d.toString().toLowerCase()}]')
        .join('\n');
    String adapterList = adapters.join('\n');

    File('$path/$name/requirements.txt').writeAsStringSync(
        '$driverList\n${adapterList.replaceAll('.v11', '').replaceAll('.v12', '')}');
    return 'echo 写入依赖...';
  }

  ///安装依赖
  static String install(String path, String name, bool venv, bool installDep) {
    if (!venv) return 'echo 虚拟环境已关闭，跳过...';

    String requirementsPath = '$path/$name/requirements.txt';
    if (!installDep) {
      return 'echo 跳过依赖安装...';
    }

    String pipInstallCmd;
    if (Platform.isLinux || Platform.isMacOS) {
      pipInstallCmd = '$path/$name/.venv/bin/pip install -r $requirementsPath';
    } else if (Platform.isWindows) {
      pipInstallCmd =
          '$path\\$name\\.venv\\Scripts\\pip.exe install -r $requirementsPath';
    } else {
      pipInstallCmd =
          '${UserConfig.pythonPath()} -m pip install -r $requirementsPath';
    }
    return pipInstallCmd;
  }

  ///创建虚拟环境
  static String createVENV(String path, String name, bool venv) {
    if (!venv) return 'echo 虚拟环境已关闭，跳过...';

    String createVenvCmd =
        '${UserConfig.pythonPath()} -m venv $path/$name/.venv --prompt $name';
    if (Platform.isWindows) {
      createVenvCmd =
          '${UserConfig.pythonPath()} -m venv $path\\$name\\.venv --prompt $name';
    }
    return createVenvCmd;
  }

  static createVENVEcho(String path, String name) {
    String formattedPath =
        Platform.isWindows ? '$path\\$name\\.venv\\' : '$path/$name/.venv/';
    return 'echo 在$formattedPath中创建虚拟环境';
  }

  ///创建目录
  static createFolder(
      String path, String name, String template, String pluginDir) {
    Directory('$path/$name').createSync(recursive: true);
    Directory('bots/').createSync(recursive: true);

    if (template == 'simple(插件开发者)') {
      String pluginsPath = pluginDir == '在[bot名称]/[bot名称]下'
          ? '$path/$name/$name/plugins'
          : '$path/$name/src/plugins';
      Directory(pluginsPath).createSync(recursive: true);
    }
    return 'echo 创建目录';
  }

  ///写入.env文件
  static writeENV(
      String path, String name, String port, String template, List drivers) {
    String driverlist = drivers
        .map((driver) => '~${driver.toString().toLowerCase()}')
        .join('+');
    String envContent;
    if (template == 'bootstrap(初学者或用户)') {
      envContent = port.isEmpty
          ? 'DRIVER=$driverlist'
          : 'DRIVER=$driverlist\nPORT=$port';
      File('$path/$name/.env.prod').writeAsStringSync(envContent);
    } else if (template == 'simple(插件开发者)') {
      envContent = 'ENVIRONMENT=dev\nDRIVER=$driverlist';
      File('$path/$name/.env').writeAsStringSync(envContent);
      File('$path/$name/.env.dev').writeAsStringSync(
          port.isNotEmpty ? 'LOG_LEVEL=DEBUG' : 'LOG_LEVEL=DEBUG\nPORT=$port');
      File('$path/$name/.env.prod').createSync();
    }
    return 'echo 写入.env文件';
  }

  ///写入pyproject.toml
  static writePyProject(
      path, name, adapters, String template, String pluginDir) {
    String adapterList = adapters
        .map((adapter) =>
            '{ name = "${adapter.replaceAll('nonebot-adapter-', '').replaceAll('.', ' ')}", module_name = "${adapter.replaceAll('-', '.').replaceAll('adapter', 'adapters')}" }')
        .join(',');

    String pyproject = '''
    [project]
    name = "$name"
    version = "0.1.0"
    description = "$name"
    readme = "README.md"
    requires-python = ">=3.9, <4.0"

    [tool.nonebot]
    adapters = [
        $adapterList
    ]
    plugins = []
    plugin_dirs = ${template == 'simple(插件开发者)' ? (pluginDir == '在[bot名称]/[bot名称]下' ? '["$name/plugins"]' : '["src/plugins"]') : '[]'}
    builtin_plugins = ["echo"]
    ''';

    File('$path/$name/pyproject.toml').writeAsStringSync(pyproject);
    return "echo 写入pyproject.toml";
  }

  ///写入Bot的json文件
  static writeBot(
      String name, String path, String type, String protocolPath, String cmd) {
    DateTime now = DateTime.now();
    String time =
        "${now.year}年${now.month}月${now.day}日${now.hour}时${now.minute}分${now.second}秒";
    String id = generateUUID();

    String botInfo = '''
{
  "name": "$name",
  "path": "${path.replaceAll('\\', "\\\\")}${Platform.isWindows ? '\\\\' : '/'}$name",
  "time": "$time",
  "id": "$id",
  "isRunning": false,
  "pid": "Null",
  "type": "$type",
  "protocolPath": "$protocolPath",
  "cmd": "$cmd",
  "protocolPid": "Null",
  "protocolIsRunning": false
}
''';

    File('bots/$id.json').writeAsStringSync(botInfo);
    return "echo 写入json";
  }
}

///协议端部署相关操作
class DeployProtocol {
  ///设置协议端的cmd
  static setCmd(jsonMap) {
    if (Platform.isWindows) {
      FastDeploy.cmd = jsonMap['cmdWin'];
      if (FastDeploy.needQQ) {
        FastDeploy.cmd =
            FastDeploy.cmd.replaceAll('NBGUI.QQNUM', FastDeploy.botQQ);
      }
    } else if (Platform.isLinux || Platform.isMacOS) {
      FastDeploy.cmd = jsonMap['cmd'];
      if (FastDeploy.needQQ) {
        FastDeploy.cmd =
            FastDeploy.cmd.replaceAll('NBGUI.QQNUM', FastDeploy.botQQ);
      }
    }
  }

  ///写入协议端配置文件
  static Future<void> writeConfig() async {
    if (FastDeploy.extDir.isEmpty) {
      print('extDir is null');
      return;
    }

    // 配置文件绝对路径
    String path = '${FastDeploy.extDir}/${FastDeploy.configPath}';
    File pcfg = File(FastDeploy.needQQ
        ? path.replaceAll('NBGUI.QQNUM', FastDeploy.botQQ)
        : path);

    // 将wsPort转为int类型
    String content = FastDeploy.botConfig
        .toString()
        .replaceAll('NBGUI.HOST:NBGUI.PORT',
            "${FastDeploy.wsHost}:${FastDeploy.wsPort}")
        .replaceAll('"NBGUI.PORT"', FastDeploy.wsPort)
        .replaceAll('NBGUI.HOST', FastDeploy.wsHost);

    await pcfg.writeAsString(content);

    if (Platform.isLinux || Platform.isMacOS) {
      // 给予执行权限
      await Process.run('chmod', ['+x', FastDeploy.cmd],
          workingDirectory: FastDeploy.extDir, runInShell: true);
    }
  }

  ///写入requirements.txt和pyproject.toml
  static writeReq(name, adapter, drivers) {
    drivers = drivers.toLowerCase();
    String driverlist =
        drivers.split(',').map((driver) => 'nonebot2[$driver]').join(',');
    driverlist = driverlist.replaceAll(',', '\n');
    String reqs = "$driverlist\n$adapter";
    File('${FastDeploy.path}/requirements.txt').writeAsStringSync(reqs);
    if (FastDeploy.template == 'bootstrap(初学者或用户)') {
      String pyproject = '''
    [project]
    name = "$name"
    version = "0.1.0"
    description = "$name"
    readme = "README.md"
    requires-python = ">=3.8, <4.0"

    [tool.nonebot]
    adapters = [
        { name = "onebot v11", module_name = "nonebot.adapters.onebot.v11" }
    ]
    plugins = []
    plugin_dirs = []
    builtin_plugins = ["echo"]
  ''';
      File('${FastDeploy.path}/pyproject.toml').writeAsStringSync(pyproject);
    } else if (FastDeploy.template == 'simple(插件开发者)') {
      if (FastDeploy.pluginDir == '在src文件夹下') {
        String pyproject = '''
    [project]
    name = "$name"
    version = "0.1.0"
    description = "$name"
    readme = "README.md"
    requires-python = ">=3.8, <4.0"

    [tool.nonebot]
    adapters = [
        { name = "$adapter", module_name = "nonebot.adapters.onebot.v11" }
    ]
    plugins = []
    plugin_dirs = ["src/plugins"]
    builtin_plugins = ["echo"]
  ''';
        File('${FastDeploy.path}/pyproject.toml').writeAsStringSync(pyproject);
      } else {
        String pyproject = '''
    [project]
    name = "$name"
    version = "0.1.0"
    description = "$name"
    readme = "README.md"
    requires-python = ">=3.8, <4.0"

    [tool.nonebot]
    adapters = [
        { name = "onebot v11", module_name = "nonebot.adapters.onebot.v11" }
    ]
    plugins = []
    plugin_dirs = ["$name/plugins"]
    builtin_plugins = ["echo"]
    ''';
        File('${FastDeploy.path}/pyproject.toml').writeAsStringSync(pyproject);
      }
    }
    return 'echo 写入依赖...';
  }
}
