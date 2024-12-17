import 'dart:convert';
import 'dart:io';
import 'core.dart';
import 'deployBot.dart';
import 'global.dart';

// 执行创建Bot命令
void runInstall(
    path, name, driver, adapters, template, pluginDir, venv, installDep) async {
  List<String> commands = [
    'echo 开始创建Bot：$name',
    'echo 读取配置...',
    DeployBot.createVENVEcho(path, name),
    DeployBot.createVENV(path, name, venv),
    'echo 开始安装依赖...',
    DeployBot.install(path, name, venv, installDep),
    DeployBot.writePyProject(path, name, adapters, template, pluginDir),
    DeployBot.writeENV(path, name, "8080", template, driver),
    DeployBot.writeBot(name, path, "default", "none", "none"),
    'echo 安装完成，可退出'
  ];

  for (String command in commands) {
    List<String> args = command.split(' ');
    String executable = args.removeAt(0);
    Process process = await Process.start(executable, args, runInShell: true);
    process.stdout.transform(systemEncoding.decoder).listen((data) {
      Map msg = {
        "type": "installBotLog",
        "data": data,
      };
      String res = jsonEncode(msg);
      sendMessageToClients(res);
    });
    process.stderr.transform(systemEncoding.decoder).listen((data) {
      Map msg = {
        "type": "installBotLog",
        "data": data,
      };
      String res = jsonEncode(msg);
      sendMessageToClients(res);
    });
    await process.exitCode;
  }
}
