import 'dart:convert';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'core.dart';
import 'global.dart';
import 'logger.dart';
import 'manage.dart';


// WebSocket 服务

  var wsHandler = webSocketHandler((webSocket) async {

    // 监听客户端消息，并处理错误
    webSocket.stream.listen(
      (message) async {
        message = message.toString().trim();
        try{
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
                webSocket.sink.add('pong!');
                break;

              // Bot列表
              case 'bots':
                JsonEncoder encoder = JsonEncoder.withIndent('  ');
                String prettyJson = encoder.convert(MainApp.botList);
                webSocket.sink.add(prettyJson);
                break;

              // 系统占用
              case 'system':
                webSocket.sink.add(await System.status());
                break;

              // 平台信息
              case 'platform':
                webSocket.sink.add(System.platform());
                break;

              // Bot信息
              case var botInfo when botInfo.startsWith('botInfo/'):
                var id = botInfo.split('/')[1];
                var bot = MainApp.botList.firstWhere(
                  (bot) => bot['id'] == id,
                  orElse: () => {'error': 'Bot Not Found!'},
                );
                JsonEncoder encoder = JsonEncoder.withIndent('  ');
                String prettyJson = encoder.convert(bot);
                webSocket.sink.add(prettyJson);
                break;

              // Bot日志
              case var botLog when botLog.startsWith('bot/log/'):
                var id = botLog.split('/')[2];
                gOnOpen = id;
                var log = await Bot.log();
                webSocket.sink.add(log);
                break;

              // 启动Bot
              case var botStart when botStart.startsWith('bot/run/'):
                var id = botStart.split('/')[2];
                gOnOpen = id;
                if (!Bot.status()) {
                  Bot.run();
                  Logger.success('Bot $id started!');
                  webSocket.sink.add('{"status": "Bot $id started!"}');
                } else {
                  Logger.error('Bot $id is already running!');
                  webSocket.sink.add('{"code": 1002, "error": "Bot $id is already running!"}');
                }
                break;

              // 停止Bot
              case var botStop when botStop.startsWith('bot/stop/'):
                var id = botStop.split('/')[2];
                gOnOpen = id;
                if (Bot.status()) {
                  Bot.stop();
                  Logger.success('Bot $id stopped!');
                  webSocket.sink.add('{"status": "Bot $id stopped!"}');
                }
                else {
                  Logger.error('Bot $id is not running!');
                  webSocket.sink.add('{"code": 1001, "error": "Bot $id is not running!"}');
                }
                break;

              // 重启Bot
              case var botRestart when botRestart.startsWith('bot/restart/'):
                var id = botRestart.split('/')[2];
                gOnOpen = id;
                if (Bot.status()) {
                  Bot.stop();
                  await Future.delayed(const Duration(seconds: 1), () {
                    Bot.run();
                  });
                  Logger.success('Bot $id restarted!');
                  webSocket.sink.add('{"status": "Bot $id restarted!"}');
                } else {
                  Logger.error('Bot $id is not running!');
                  webSocket.sink.add('{"code": 1001, "error": "Bot $id is not running!"}');
                }
                break;

              // 未知命令
              default:
                webSocket.sink.add('Unknown Command!');
                break;
            }
          }
        } catch (e) {
          Logger.error('Error handling message: $e');
          webSocket.sink.add('Error processing your request.$e');
        }
        }
        catch(e){
          webSocket.sink.add('{"error": "401 Unauthorized!"}');
        }
      },
      onError: (error, stackTrace) {
        Logger.error('$error\nStack Trace:\n$stackTrace');
        webSocket.sink.add('Error processing your request.$error');
      },
      cancelOnError: true,
    );
  });