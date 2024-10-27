import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import '../utils/core.dart';
import '../utils/global.dart';
import '../utils/logger.dart';
import '../utils/manage.dart';

void main() {
  runZonedGuarded(() async {
    // 初始启动日志
    Logger.info('Welcome to NoneBot Agent!');
    Logger.info('By 【夜风】NightWind(2125714976@qq.com)');
    Logger.info('Release under the GPL-3 License.');
    Logger.info('Version: ${AgentMain.version()}');

    // await Future.delayed(const Duration(seconds: 1), () {
    //   Logger.warn('NoneBot Agent will be started after 3s......');
    // });
    // await Future.delayed(const Duration(seconds: 3), () {
    //   Logger.info('NoneBot Agent is initializing......');
    // });

    // 初始化服务器配置
    AgentMain.init();
    final String host = AgentMain.host();
    final int httpPort = AgentMain.httpPort();
    final int wsPort = AgentMain.wsPort();
    Logger.info("HTTP server is starting...");
    Logger.info('Started server process [$pid]');

    // 检查token
    final String token = AgentMain.token().toString();

    // 设置SIGINT信号处理器
    ProcessSignal.sigint.watch().listen((signal) {
      Logger.info('Waiting for applications shutdown');
      Logger.info('Application shutdown completed');
      Logger.info('Finished server process [$pid]');
      exit(0);
    });

    ///监听 bots 文件夹
    Stream<FileSystemEvent> eventStream = Directory('bots/').watch();
    eventStream.listen((FileSystemEvent event) {
      MainApp.botList = AgentMain.loadBots();
    });

// 分割线----------------------------------------------------------------------------------------------|问就是不喜欢代码堆一块(逃

    // WebSocket 服务
  var wsHandler = webSocketHandler((webSocket) async {

    // 监听客户端消息，并处理错误
    webSocket.stream.listen(
      (message) async {
        message = message.toString().trim();
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
      },
      onError: (error, stackTrace) {
        Logger.error('$error\nStack Trace:\n$stackTrace');
        webSocket.sink.add('Error processing your request.$error');
      },
      cancelOnError: true,
    );
  });





// 分割线----------------------------------------------------------------------------------------------

    // 定义错误处理的中间件
    Middleware handleErrors() {
      return (Handler handler) {
        return (Request request) async {
          try {
            // 处理请求
            return await handler(request);
          } catch (e, stackTrace) {
            // 捕获错误并记录到 Logger
            Logger.error(
                'Internal Server Error: $e\nStack Trace:\n$stackTrace');
            // 返回 HTTP 500 错误
            return Response(
              500,
              body: '{"error": "500 Internal Server Error"}',
              headers: {'Content-Type': 'application/json'},
            );
          }
        };
      };
    }

    // 创建路由
    var router = Router();

    // 初始化鉴权中间件
    Middleware handleAuth({required String token}) {
      return (Handler handler) {
        return (Request request) async {
          final authHeader = request.headers['Authorization'];

          if (authHeader == null || authHeader != 'Bearer $token') {
            return Response(
              401,
              body: '{"error": "401 Unauthorized!"}',
              headers: {'Content-Type': 'application/json'},
            );
          }
          return handler(request);
        };
      };
    }

    // 统一 Log 输出
    Middleware customLogRequests() {
      return (Handler innerHandler) {
        return (Request request) async {
          final watch = Stopwatch()..start();
          final response = await innerHandler(request);
          final latency = watch.elapsed;
          Logger.api(request.method, response.statusCode,
              '${request.url}\t\t${latency.inMilliseconds}ms');
          return response;
        };
      };
    }

    // 定义 API 路由
    // ping
    router.get('/nbgui/v1/ping', (Request request) {
      return Response.ok('pong!');
    });

    // 获取 Bot 列表
    router.get('/nbgui/v1/bots/list', (Request request) async {
      JsonEncoder encoder = JsonEncoder.withIndent('  ');
      String prettyJson = encoder.convert(MainApp.botList);

      return Response.ok(
        prettyJson,
        headers: {'Content-Type': 'application/json'},
      );
    });

    // 获取 Bot 信息
    router.get('/nbgui/v1/bots/info/<id>', (Request request, String id) async {
      var bot = MainApp.botList.firstWhere(
        (bot) => bot['id'] == id,
        orElse: () => {'error': 'Bot Not Found!'},
      );
      var encoder = JsonEncoder.withIndent('  ');
      String prettyJson = encoder.convert(bot);
      return Response.ok(
        prettyJson,
        headers: {'Content-Type': 'application/json'},
      );
    });

    // 启动 Bot
    router.get('/nbgui/v1/bots/start/<id>', (Request request, String id) async {
      gOnOpen = id;
      Bot.run();
      return Response.ok(
        '{"status": "Bot $id started!"}',
        headers: {'Content-Type': 'application/json'},
      );
    });

    // 获取系统状态
    router.get('/nbgui/v1/system/status', (Request request) async {
      return Response.ok(
        await System.status(),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // 获取系统平台
    router.get('/nbgui/v1/system/platform', (Request request) async {
      return Response.ok(
        System.platform(),
        headers: {'Content-Type': 'application/json'},
      );
    });

    // 定义404错误处理
    router.all('/<catchall|.*>', (Request request) {
      return Response.notFound('404 Not Found: ${request.url}');
    });

// 分割线----------------------------------------------------------------------------------------------

    // 配置中间件
    var httpHandler = const Pipeline()
        .addMiddleware(customLogRequests())
        .addMiddleware(handleAuth(token: token))
        .addMiddleware(handleErrors())
        .addHandler(router.call);



    // 启动 HTTP 服务器
    await io.serve(httpHandler, host, httpPort);

    // 启动 WebSocket 服务器
    await io.serve(wsHandler, host, wsPort);

    // 打印服务器地址
    if (host.contains('::')) {
      Logger.info('Listening on http://[${host}]:$httpPort');
      Logger.info('Listening on ws://[${host}]:$wsPort');
    } else {
      Logger.info('Listening on http://$host:$httpPort');
      Logger.info('Listening on ws://$host:$wsPort');
    }
  }, (error, stackTrace) {
    Logger.error('Unhandled Exception: $error\nStack Trace:\n$stackTrace');
  });
}
