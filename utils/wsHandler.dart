import 'dart:convert';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'core.dart';
import 'global.dart';
import 'logger.dart';
import 'manage.dart';
import 'runCmd.dart';

// WebSocket 服务
var wsHandler = webSocketHandler((webSocket) async {
  // 监听客户端消息，并处理错误
  wsChannels.add(webSocket);
  Logger.success(
      'Websocket connection established. ${wsChannels.length} connections now.');
  webSocket.stream.listen(
    (message) async {
      message = message.toString().trim();
      try {
        var body = message.split('?token=');
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
              case var botLog when botLog.startsWith('bots/log/'):
                var id = botLog.split('/')[2];
                gOnOpen = id;
                var log = await Bot.log();
                //
                Map response = {"type": "botLog", "data": log};
                String res = jsonEncode(response);
                webSocket.sink.add(res);
                break;

              // 启动Bot
              case var botStart when botStart.startsWith('bots/run/'):
                var id = botStart.split('/')[2];
                gOnOpen = id;
                if (!Bot.status()) {
                  Bot.run();
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
              case var botStop when botStop.startsWith('bots/stop/'):
                var id = botStop.split('/')[2];
                gOnOpen = id;
                if (Bot.status()) {
                  Bot.stop();
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
              case var botRestart when botRestart.startsWith('bots/restart/'):
                var id = botRestart.split('/')[2];
                gOnOpen = id;
                if (Bot.status()) {
                  Bot.stop();
                  await Future.delayed(const Duration(seconds: 1), () {
                    Bot.run();
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
              case var importBot when importBot.startsWith('bots/import'):
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
              case var createBot when createBot.startsWith('bots/create'):
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
              // 未知命令
              default:
                webSocket.sink.add('Unknown Command!');
                break;
            }
          }
        } catch (e, stackTrace) {
          Logger.error('Error handling message: $e\nStack Trace:\n$stackTrace');
          webSocket.sink.add('Error processing your request.$e');
        }
      } catch (e) {
        String res = '{"type": "Unauthorized", "data": "401 Unauthorized!"}';
        webSocket.sink.add('{"error": "401 Unauthorized!"}');
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
