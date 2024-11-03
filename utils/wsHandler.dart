import 'dart:convert';

import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf.dart';

import 'core.dart';
import 'global.dart';
import 'logger.dart';


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
              case 'bots':
                JsonEncoder encoder = JsonEncoder.withIndent('  ');
                String prettyJson = encoder.convert(MainApp.botList);
                webSocket.sink.add(prettyJson);
                break;
              case 'system':
                webSocket.sink.add(await System.status());
                break;
              case 'platform':
                webSocket.sink.add(System.platform());
                break;
              case 'botList':
                webSocket.sink.add(MainApp.botList.toString());
                break;
              case var botInfo when botInfo.startsWith('botInfo/'):
                var id = botInfo.split('/')[1];
                var bot = MainApp.botList.firstWhere(
                  (bot) => bot['id'] == id,
                  orElse: () => {'error': 'Bot Not Found!'},
                );
                webSocket.sink.add(bot.toString());
                break;
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