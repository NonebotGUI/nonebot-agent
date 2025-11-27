import 'dart:convert';
import 'dart:math';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'core.dart';
import 'global.dart';
import 'logger.dart';
import 'manage.dart';
import 'run_cmd.dart';
import 'file.dart';

// WebSocket 服务
var wsHandler = webSocketHandler((webSocket) async {
  // 监听客户端消息，并处理错误
  wsChannels.add(webSocket);
  Logger.success(
      'Websocket connection established. ${wsChannels.length} connection(s) now.');
  webSocket.stream.listen(
    (message) async {
      message = message.toString().trim();
      try {
        var body = message.split('&token=');
        String msg = body[0];
        String token = body[1];
        try {
          if (body.length != 2) {
            webSocket.sink.add('{ "error": "400 Bad Request!" }');
            return;
          }
          if (token != AgentMain.token().toString()) {
            webSocket.sink.add('{ "error": "401 Unauthorized!" }');
            return;
          }
          if (body.length == 2 && token == AgentMain.token().toString()) {
            switch (msg) {
              case 'ping':
                String res = '{"type": "pong", "data": "pong!"}';
                webSocket.sink.add(res);
                break;

              // 版本信息
              case 'version':
                Map<String, String> version = {
                  'version': AgentMain.version(),
                  'nbcli':
                      MainApp.nbcli.replaceAll('nb: ', '').replaceAll('\n', ''),
                  'python': MainApp.python,
                };
                Map response = {
                  "type": "version",
                  "data": version,
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);

              // Bot列表
              case 'botList':
                Map<String, dynamic> response = {
                  "type": "botList",
                  "data": MainApp.botList
                };
                String prettyJson = jsonEncode(response);
                webSocket.sink.add(prettyJson);

                break;

              // 系统占用
              case 'system':
                String res =
                    '{"type": "systemStatus", "data": ${await System.status()}}';
                webSocket.sink.add(res);
                break;
              // 平台信息
              case 'platform':
                String res =
                    '{"type": "platformInfo", "data": ${await System.platform()}}';
                webSocket.sink.add(res);
                break;

              // Bot信息
              case var botInfo when botInfo.startsWith('botInfo/'):
                var id = botInfo.split('/')[1];
                var bot = MainApp.botList.firstWhere(
                  (bot) => bot['id'] == id,
                  orElse: () => {"error": "Bot Not Found!"},
                );
                JsonEncoder encoder = JsonEncoder.withIndent('  ');
                String prettyJson = encoder.convert(bot);
                String res = '{"type": "botInfo", "data": $prettyJson}';
                webSocket.sink.add(res);
                //Logger.debug(res);
                break;

              // Bot日志
              case var botLog when botLog.startsWith('bot/log/'):
                var id = botLog.split('/')[2];
                var log = await Bot.log(id);
                //
                Map response = {"type": "botLog", "data": log};
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 获取 stderr 日志
              case var botStderr when botStderr.startsWith('bot/stderr/'):
                var id = botStderr.split('/')[2];
                var log = Bot.stderr(id);
                if (log.isEmpty) {
                  Map response = {
                    "type": "botStderr",
                    "hasLog": false,
                    "data": {"error": "No stderr log found!"}
                  };
                  String res = jsonEncode(response);
                  webSocket.sink.add(res);
                } else {
                  Map response = {
                    "type": "botStderr",
                    "hasLog": true,
                    "data": log
                  };
                  String res = jsonEncode(response);
                  webSocket.sink.add(res);
                }
                break;

              // 清空 stderr 日志
              case var clearStderr
                  when clearStderr.startsWith('bot/clearStderr/'):
                var id = clearStderr.split('/')[2];
                Bot.clearStderr(id);
                Map response = {
                  "type": "clearStderr",
                  "data": {"status": "Stderr log cleared!"}
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 启动Bot
              case var botStart when botStart.startsWith('bot/run/'):
                var id = botStart.split('/')[2];
                if (!Bot.status(id)) {
                  Bot.run(id);
                  Logger.success('Bot $id started!');
                  String res =
                      '{"type": "startBot", "data": "{\\"status\\": \\"Bot $id started!\\"}"}';
                  webSocket.sink.add(res);
                } else {
                  Logger.error('Bot $id is already running!');
                  String res =
                      '{"type": "startBot", "data": "{\\"code\\": 1002, \\"error\\": \\"Bot $id is already running!\\"}"}';
                  webSocket.sink.add(res);
                }
                break;

              // 停止Bot
              case var botStop when botStop.startsWith('bot/stop/'):
                var id = botStop.split('/')[2];
                if (Bot.status(id)) {
                  Bot.stop(id);
                  Logger.success('Bot $id stopped!');
                  String res =
                      '{"type": "stopBot", "data": "{\\"status\\": \\"Bot $id stopped!\\"}"}';
                  webSocket.sink.add(res);
                } else {
                  Logger.error('Bot $id is not running!');
                  String res =
                      '{"type": "stopBot", "data": "{\\"code\\": 1001, \\"error\\": \\"Bot $id is not running!\\"}"}';
                  webSocket.sink.add(res);
                }
                break;

              // 重启Bot
              case var botRestart when botRestart.startsWith('bot/restart/'):
                var id = botRestart.split('/')[2];
                gOnOpen = id;
                if (Bot.status(id)) {
                  Bot.stop(id);
                  await Future.delayed(const Duration(seconds: 1), () {
                    Bot.run(id);
                  });
                  Logger.success('Bot $id restarted!');
                  String res =
                      '{"type": "restartBot", "data": "{\\"status\\": \\"Bot $id restarted!\\"}"}';
                  webSocket.sink.add(res);
                } else {
                  Logger.error('Bot $id is not running!');
                  String res =
                      '{"type": "restartBot", "data": "{\\"code\\": 1001, \\"error\\": \\"Bot $id is not running!\\"}"}';
                  webSocket.sink.add(res);
                }
                break;

              // 导入Bot
              case var importBot when importBot.startsWith('bot/import'):
                var bot = importBot.split('?data=')[1];
                var botJson = jsonDecode(bot);
                String name = botJson['name'];
                String path = botJson['path'];
                String protocolPath = botJson['protocolPath'];
                bool withProtocol = botJson['withProtocol'];
                String cmd = botJson['cmd'];
                Bot.import(name, path, withProtocol, protocolPath, cmd);
                Logger.success('Bot $name imported!');
                Map response = {
                  "type": "importBot",
                  "data": {"status": "Bot $name imported!"}
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);

              // 创建Bot
              case var createBot when createBot.startsWith('bot/create'):
                var bot = createBot.split('?data=')[1];
                var botJson = jsonDecode(bot);
                String name = botJson['name'];
                String path = botJson['path'];
                List drivers = botJson['drivers'];
                List adapters = botJson['adapters'];
                String template = botJson['template'];
                String pluginDir = botJson['pluginDir'];
                bool venv = botJson['venv'];
                bool installDep = botJson['installDep'];
                runInstall(path, name, drivers, adapters, template, pluginDir,
                    venv, installDep);
                Logger.info('Bot $name start creating...');
                Map response = {
                  "type": "createBot",
                  "data": {"status": "Bot $name start creating..."}
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);

              // 删除Bot
              case var deleteBot when deleteBot.startsWith('bot/remove/'):
                var id = deleteBot.split('/')[2];
                gOnOpen = id;
                Bot.delete(id);
                Logger.success('Bot $id removed!');
                Map response = {
                  "type": "deleteBot",
                  "data": {"status": "Bot $id removed!"}
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 彻底删除Bot
              case var deleteBot when deleteBot.startsWith('bot/delete/'):
                var id = deleteBot.split('/')[2];
                gOnOpen = id;
                Bot.deleteForever(id);
                Logger.success('Bot $id deleted!');
                Map response = {
                  "type": "deleteBot",
                  "data": {"status": "Bot $id deleted!"}
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 重命名Bot
              case var renameBot when renameBot.startsWith('bot/rename'):
                var data = renameBot.split('?data=')[1];
                var botJson = jsonDecode(data);
                String id = botJson['id'];
                String name = botJson['name'];
                gOnOpen = id;
                Bot.rename(name, id);
                Logger.success('Bot $id renamed to $name!');
                Map response = {
                  "type": "renameBot",
                  "data": {"status": "Bot $id renamed to $name!"}
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 切换 Bot 自动启动状态
              case var toggleAutoStart
                  when toggleAutoStart.startsWith('bot/toggleAutoStart'):
                var id = toggleAutoStart.split('/')[2];
                Bot.toggleAutoStart(id);
                Map response = {
                  "type": "toggleAutoStart",
                  "data": {"status": "Bot $id autoStart toggled!"}
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 安装插件
              case var installPlugin
                  when installPlugin.startsWith('plugin/install'):
                var plugin = installPlugin.split('?data=')[1];
                var pluginJson = jsonDecode(plugin);
                String name = pluginJson['name'];
                String id = pluginJson['id'];
                Plugin.install(name, id);
                Logger.success('Plugin $name installed!');
                Map response = {
                  "type": "installPlugin",
                  "data": {"status": "Plugin $name start installing..."}
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 卸载插件
              case var uninstallPlugin
                  when uninstallPlugin.startsWith('plugin/uninstall'):
                var plugin = uninstallPlugin.split('?data=')[1];
                var pluginJson = jsonDecode(plugin);
                String id = pluginJson['id'];
                String name = pluginJson['name'];
                Plugin.uninstall(name, id);
                Logger.success('Plugin $name uninstalled!');
                Map response = {
                  "type": "uninstallPlugin",
                  "data": {"status": "Plugin $name start uninstalling..."}
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 禁用插件
              case var disablePlugin
                  when disablePlugin.startsWith('plugin/disable?data='):
                var plugin = disablePlugin.split('?data=')[1];
                var pluginJson = jsonDecode(plugin);
                String id = pluginJson['id'];
                String name = pluginJson['name'];
                Plugin.disable(name, id);
                Logger.success('Plugin $name disabled!');
                Map response = {
                  "type": "disablePlugin",
                  "data": {"status": "Plugin $name disabled!"}
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 启用插件
              case var enablePlugin
                  when enablePlugin.startsWith('plugin/enable?data='):
                var plugin = enablePlugin.split('?data=')[1];
                var pluginJson = jsonDecode(plugin);
                String id = pluginJson['id'];
                String name = pluginJson['name'];
                Plugin.enable(name, id);
                Logger.success('Plugin $name enabled!');
                Map response = {
                  "type": "enablePlugin",
                  "data": {"status": "Plugin $name enabled!"}
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 获取插件列表
              case var pluginList when pluginList.startsWith('plugin/list/'):
                var id = pluginList.split('/')[2];
                var plugins = Plugin.list(id);
                Map response = {"type": "pluginList", "data": plugins};
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 获取被禁用的插件列表
              case var pluginList
                  when pluginList.startsWith('plugin/disabledList/'):
                var id = pluginList.split('/')[2];
                var plugins = Plugin.disabledList(id);
                Map response = {"type": "disabledPluginList", "data": plugins};
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 安装适配器
              case var installAdapter
                  when installAdapter.startsWith('adapter/install'):
                var adapter = installAdapter.split('?data=')[1];
                var adapterJson = jsonDecode(adapter);
                String name = adapterJson['name'];
                String id = adapterJson['id'];
                Adapter.install(name, id);
                Logger.success('Adapter $name installed!');
                Map response = {
                  "type": "installAdapter",
                  "data": {"status": "Adapter $name start installing..."}
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 获取env文件内容
              case var getEnv when getEnv.startsWith('env/load/'):
                var id = getEnv.split('/')[2];
                var filename = getEnv.split('/')[3];
                if (['.env', '.env.prod', '.env.dev'].contains(filename)) {
                  var env = Env.load(id, filename);
                  Map response = {"type": "envContent", "data": env};
                  String res = jsonEncode(response);
                  webSocket.sink.add(res);
                } else {
                  Map response = {
                    "type": "envContent",
                    "data": {"error": "Not allowed operation!"}
                  };
                  String res = jsonEncode(response);
                  webSocket.sink.add(res);
                }
                break;

              // 编辑env文件内容
              case var editEnv when editEnv.startsWith('env/edit'):
                var data = editEnv.split('?data=')[1];
                var id = jsonDecode(data)['id'];
                var filename = jsonDecode(data)['filename'];
                var content = jsonDecode(data)['content'];
                if (['.env', '.env.prod', '.env.dev'].contains(filename)) {
                  Env.modify(id, filename, content);
                  Map response = {
                    "type": "editEnv",
                    "data": {"status": "Env file $filename edited!"}
                  };
                  String res = jsonEncode(response);
                  webSocket.sink.add(res);
                } else {
                  Map response = {
                    "type": "editEnv",
                    "data": {"error": "Not allowed operation!"}
                  };
                  String res = jsonEncode(response);
                  webSocket.sink.add(res);
                }
                break;

              // 新增env配置项
              case var addEnv when addEnv.startsWith('env/add'):
                var data = addEnv.split('?data=')[1];
                var id = jsonDecode(data)['id'];
                var filename = jsonDecode(data)['filename'];
                var key = jsonDecode(data)['varName'];
                var value = jsonDecode(data)['varValue'];
                if (['.env', '.env.prod', '.env.dev'].contains(filename)) {
                  Env.add(id, filename, key, value);
                  Map response = {
                    "type": "addEnv",
                    "data": {"status": "Env file $filename added!"}
                  };
                  String res = jsonEncode(response);
                  webSocket.sink.add(res);
                } else {
                  Map response = {
                    "type": "addEnv",
                    "data": {"error": "Not allowed operation!"}
                  };
                  String res = jsonEncode(response);
                  webSocket.sink.add(res);
                }
                break;

              // 删除env配置项
              case var deleteEnv when deleteEnv.startsWith('env/delete'):
                var data = deleteEnv.split('?data=')[1];
                var id = jsonDecode(data)['id'];
                var filename = jsonDecode(data)['filename'];
                var key = jsonDecode(data)['varName'];
                if (['.env', '.env.prod', '.env.dev'].contains(filename)) {
                  Env.delete(id, filename, key);
                  Map response = {
                    "type": "deleteEnv",
                    "data": {"status": "Env file $filename deleted!"}
                  };
                  String res = jsonEncode(response);
                  webSocket.sink.add(res);
                } else {
                  Map response = {
                    "type": "deleteEnv",
                    "data": {"error": "Not allowed operation!"}
                  };
                  String res = jsonEncode(response);
                  webSocket.sink.add(res);
                }
                break;

              // 列出文件和目录
              case var listDir when listDir.startsWith('file/list/'):
                var uri = Uri.parse(listDir);
                var parts = uri.path.split('/');
                var id = parts[2];
                var subPath =
                    parts.length > 3 ? parts.sublist(3).join('/') : '';
                var dirContent = FileUtils.readDir(id, subPath);
                Map response = {"type": "fileList", "data": dirContent};
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 创建目录
              case var createDir when createDir.startsWith('file/mkdir/'):
                var uri = Uri.parse(createDir);
                var dirName = uri.queryParameters['name'] ?? '';
                var parts = uri.path.split('/');
                var id = parts[2];
                var subPath =
                    parts.length > 3 ? parts.sublist(3).join('/') : '';
                var result = FileUtils.createDir(id, subPath, dirName);
                Map response = {"type": "createDir", "data": result};
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 删除文件或目录
              case var deletePath when deletePath.startsWith('file/delete/'):
                var uri = Uri.parse(deletePath);
                var name = uri.queryParameters['name'] ?? '';
                var parts = uri.path.split('/');
                var id = parts[2];
                var subPath =
                    parts.length > 3 ? parts.sublist(3).join('/') : '';
                var result = FileUtils.deletePath(id, subPath, name);
                Map response = {"type": "deletePath", "data": result};
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 重命名文件或目录
              case var renamePath when renamePath.startsWith('file/rename/'):
                var uri = Uri.parse(renamePath);
                var data = uri.queryParameters['data'] ?? '{}';
                var parts = uri.path.split('/');
                var id = parts[2];
                var subPath =
                    parts.length > 3 ? parts.sublist(3).join('/') : '';
                var dataJson = jsonDecode(data);
                var oldName = dataJson['oldName'];
                var newName = dataJson['newName'];
                var result =
                    FileUtils.renamePath(id, subPath, oldName, newName);
                Map response = {"type": "renamePath", "data": result};
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 读取文件内容
              case var readFile when readFile.startsWith('file/read/'):
                var uri = Uri.parse(readFile);
                var fileName = uri.queryParameters['name'] ?? '';
                var parts = uri.path.split('/');
                var id = parts[2];
                var subPath =
                    parts.length > 3 ? parts.sublist(3).join('/') : '';
                var content = FileUtils.readFile(id, subPath, fileName);
                Map response = {"type": "fileContent", "data": content};
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 写入文件内容
              case var writeFile when writeFile.startsWith('file/write/'):
                var uri = Uri.parse(writeFile);
                var data = uri.queryParameters['data'] ?? '{}';
                var parts = uri.path.split('/');
                var id = parts[2];
                var subPath =
                    parts.length > 3 ? parts.sublist(3).join('/') : '';
                var dataJson = jsonDecode(data);
                var fileName = dataJson['filename'];
                var content = dataJson['content'];
                var result =
                    FileUtils.writeFile(id, subPath, fileName, content);
                Map response = {"type": "writeFile", "data": result};
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 移动文件或目录
              case var movePath when movePath.startsWith('file/move/'):
                var uri = Uri.parse(movePath);
                var data = uri.queryParameters['data'] ?? '{}';
                var parts = uri.path.split('/');
                var id = parts[2];
                var subPath =
                    parts.length > 3 ? parts.sublist(3).join('/') : '';
                var dataJson = jsonDecode(data);
                var name = dataJson['name'];
                var targetSubPath = dataJson['target'];
                if (targetSubPath.startsWith('/')) {
                  targetSubPath = targetSubPath.substring(1);
                }
                var result =
                    FileUtils.movePath(id, subPath, name, targetSubPath);
                Map response = {"type": "movePath", "data": result};
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 复制文件或目录
              case var copyPath when copyPath.startsWith('file/copy/'):
                var uri = Uri.parse(copyPath);
                var data = uri.queryParameters['data'] ?? '{}';
                var parts = uri.path.split('/');
                var id = parts[2];
                var subPath =
                    parts.length > 3 ? parts.sublist(3).join('/') : '';
                var dataJson = jsonDecode(data);
                var name = dataJson['name'];
                var targetName = dataJson['target'];
                if (targetName.startsWith('/')) {
                  targetName = targetName.substring(1);
                }
                var result = FileUtils.copyPath(id, subPath, name, targetName);
                Map response = {"type": "copyPath", "data": result};
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 创建空文件
              case var createFile when createFile.startsWith('file/touch/'):
                var uri = Uri.parse(createFile);
                var fileName = uri.queryParameters['name'] ?? '';
                var parts = uri.path.split('/');
                var id = parts[2];
                var subPath =
                    parts.length > 3 ? parts.sublist(3).join('/') : '';
                var result = FileUtils.createFile(id, subPath, fileName);
                Map response = {"type": "createFile", "data": result};
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 未知命令
              default:
                Map response = {
                  "type": "unknownCommand",
                  "data": "Unknown Command!"
                };
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;
            }
          }
        } catch (e, stackTrace) {
          Logger.error('Error handling message: $e\nStack Trace:\n$stackTrace');
          webSocket.sink.add('Error processing your request.$e');
        }
      } catch (e) {
        String res = '{"type": "Unauthorized", "data": "401 Unauthorized!"}';
        webSocket.sink.add(res);
      }
    },
    onError: (error, stackTrace) {
      Logger.error('$error\nStack Trace:\n$stackTrace');
      webSocket.sink.add('Error processing your request.$error');
    },
    cancelOnError: true,
    onDone: () {
      wsChannels.remove(webSocket);
      Logger.info(
          'Websocket connection closed. ${wsChannels.length} connections now.');
    },
  );
});
