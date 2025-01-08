import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import '../utils/core.dart';
import '../utils/global.dart';
import '../utils/logger.dart';
import '../utils/manage.dart';
import '../utils/run_cmd.dart';
import '../utils/ws_handler.dart';

void main() {
  runZonedGuarded(() async {
    Logger.warn('NoneBot Agent will start in 3 seconds...');
    await Future.delayed(const Duration(seconds: 3));
    Logger.info('Welcome to NoneBot Agent!');
    Logger.info('By 【夜风】NightWind(2125714976@qq.com)');
    Logger.info('Released under the GPL-3 License.');
    Logger.info('Version: ${AgentMain.version()}');
    // 初始化服务器配置
    AgentMain.init();
    final String host = AgentMain.host();
    final int port = AgentMain.port();
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
    router.get('/nbgui/v1/bot/list', (Request request) async {
      JsonEncoder encoder = JsonEncoder.withIndent('  ');
      String prettyJson = encoder.convert(MainApp.botList);

      return Response.ok(prettyJson,
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 获取 Bot 信息
    router.get('/nbgui/v1/bot/info/<id>', (Request request, String id) async {
      var bot = MainApp.botList.firstWhere(
        (bot) => bot['id'] == id,
        orElse: () => {'error': 'Bot Not Found!'},
      );
      var encoder = JsonEncoder.withIndent('  ');
      String prettyJson = encoder.convert(bot);
      return Response.ok(prettyJson,
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 获取 Bot 日志
    router.get('/nbgui/v1/bot/log/<id>', (Request request, String id) async {
      var log = await Bot.log(id);
      return Response.ok(log,
          headers: {'Content-Type': 'text/plain'}, encoding: utf8);
    });

    // 启动 Bot
    router.get('/nbgui/v1/bot/run/<id>', (Request request, String id) async {
      if (!Bot.status(id)) {
        Bot.run(id);
        Logger.success('Bot $id started!');
        return Response.ok('{"status": "Bot $id started!"}',
            headers: {'Content-Type': 'application/json'}, encoding: utf8);
      } else {
        Logger.error('Bot $id is already running!');
        return Response.ok(
          '{"code": 1002, "error": "Bot $id is already running!"}',
          headers: {'Content-Type': 'application/json'},
          encoding: utf8,
        );
      }
    });

    // 停止 Bot
    router.get('/nbgui/v1/bot/stop/<id>', (Request request, String id) async {
      if (Bot.status(id)) {
        Bot.stop(id);
        Logger.success('Bot $id stopped!');
        return Response.ok('{"status": "Bot $id stopped!"}',
            headers: {'Content-Type': 'application/json'}, encoding: utf8);
      } else {
        Logger.error('Bot $id is not running!');
        return Response.ok(
          '{"code": 1001, "error": "Bot $id is not running!"}',
          headers: {'Content-Type': 'application/json'},
          encoding: utf8,
        );
      }
    });

    // 重启 Bot
    router.get('/nbgui/v1/bot/restart/<id>',
        (Request request, String id) async {
      gOnOpen = id;
      if (Bot.status(id)) {
        Bot.stop(id);
        await Future.delayed(const Duration(seconds: 1), () {
          Bot.run(id);
        });
        Logger.success('Bot $id restarted!');
        return Response.ok('{"status": "Bot $id restarted!"}',
            headers: {'Content-Type': 'application/json'}, encoding: utf8);
      } else {
        Logger.error('Bot $id is not running!');
        return Response.ok(
          '{"code": 1001, "error": "Bot $id is not running!"}',
          headers: {'Content-Type': 'application/json'},
          encoding: utf8,
        );
      }
    });

    // 导入 Bot
    router.post('/nbgui/v1/bot/import', (Request request) async {
      final body = await request.readAsString();
      var bot = jsonDecode(body);
      String name = bot['name'];
      String path = bot['path'];
      String protocolPath = bot['protocolPath'];
      bool withProtocol = bot['withProtocol'];
      String cmd = bot['cmd'];
      Bot.import(name, path, withProtocol, protocolPath, cmd);
      Logger.success('Bot $name imported!');
      return Response.ok('{"status": "Bot $name imported!"}',
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 创建 Bot
    router.post('/nbgui/v1/bot/create', (Request request) async {
      final body = await request.readAsString();
      var bot = jsonDecode(body);
      String path = bot['path'];
      String name = bot['name'];
      List drivers = bot['drivers'];
      List adapters = bot['adapters'];
      String template = bot['template'];
      String pluginDir = bot['pluginDir'];
      bool venv = bot['venv'];
      bool installDep = bot['installDep'];
      Logger.info('Bot $name start creating...');
      runInstall(
          path, name, drivers, adapters, template, pluginDir, venv, installDep);
      return Response.ok('{"status": "Bot $name start creating..."}',
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 删除 Bot
    router.delete('/nbgui/v1/bot/remove/<id>',
        (Request request, String id) async {
      gOnOpen = id;
      if (Bot.status(id)) {
        Bot.stop(id);
      }
      Bot.delete(id);
      Logger.success('Bot $id removed!');
      return Response.ok('{"status": "Bot $id removed!"}',
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 永久删除 Bot
    router.delete('/nbgui/v1/bot/delete/<id>',
        (Request request, String id) async {
      gOnOpen = id;
      if (Bot.status(id)) {
        Bot.stop(id);
      }
      Bot.deleteForever(id);
      Logger.success('Bot $id deleted!');
      return Response.ok('{"status": "Bot $id deleted!"}',
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 重命名 Bot
    router.post('/nbgui/v1/bot/rename/<id>',
        (Request request, String id) async {
      final body = await request.readAsString();
      var bot = jsonDecode(body);
      String name = bot['name'];
      Bot.rename(name, id);
      Logger.success('Bot $id renamed to $name!');
      return Response.ok('{"status": "Bot $id renamed to $name!"}',
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 获取系统状态
    router.get('/nbgui/v1/system/status', (Request request) async {
      return Response.ok(await System.status(),
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 获取系统平台
    router.get('/nbgui/v1/system/platform', (Request request) async {
      return Response.ok(System.platform(),
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 获取Agent版本信息
    router.get('/nbgui/v1/version', (Request request) async {
      Map<String, String> version = {
        'version': AgentMain.version(),
        'nbcli': MainApp.nbcli.replaceAll('nb: ', '').replaceAll('\n', ''),
        'python': MainApp.python,
      };
      return Response.ok(jsonEncode(version),
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 安装插件
    router.post('/nbgui/v1/plugin/install', (Request request) async {
      final body = await request.readAsString();
      var plugin = jsonDecode(body);
      String name = plugin['name'];
      String id = plugin['id'];
      Plugin.install(name, id);
      Logger.success('Plugin $name in $id start installing.');
      return Response.ok('{"status": "Plugin $name in $id start installing."}',
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 卸载插件
    router.post('/nbgui/v1/plugin/uninstall', (Request request) async {
      final body = await request.readAsString();
      var plugin = jsonDecode(body);
      String name = plugin['name'];
      String id = plugin['id'];
      Plugin.uninstall(name, id);
      Logger.success('Plugin $name in $id start uninstalling.');
      return Response.ok(
          '{"status": "Plugin $name in $id start uninstalling."}',
          headers: {'Content-Type': 'application/json'},
          encoding: utf8);
    });

    // 获取插件列表
    router.get('/nbgui/v1/plugin/list/<id>',
        (Request request, String id) async {
      return Response.ok(Plugin.list(id),
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 获取已禁用的插件列表
    router.get('/nbgui/v1/plugin/disabled/<id>',
        (Request request, String id) async {
      return Response.ok(Plugin.disabledList(id),
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 禁用插件
    router.post('/nbgui/v1/plugin/disable', (Request request) async {
      final body = await request.readAsString();
      var plugin = jsonDecode(body);
      String name = plugin['name'];
      String id = plugin['id'];
      Plugin.disable(name, id);
      Logger.success('Plugin $name in $id disabled.');
      return Response.ok('{"status": "Plugin $name in $id disabled."}',
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 启用插件
    router.post('/nbgui/v1/plugin/enable', (Request request) async {
      final body = await request.readAsString();
      var plugin = jsonDecode(body);
      String name = plugin['name'];
      String id = plugin['id'];
      Plugin.enable(name, id);
      Logger.success('Plugin $name in $id enabled.');
      return Response.ok('{"status": "Plugin $name in $id enabled."}',
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // 安装适配器
    router.post('/nbgui/v1/adapter/install', (Request request) async {
      final body = await request.readAsString();
      var adapter = jsonDecode(body);
      String name = adapter['name'];
      String id = adapter['id'];
      Adapter.install(name, id);
      Logger.success('Adapter $name in $id start installing.');
      return Response.ok('{"status": "Adapter $name in $id start installing."}',
          headers: {'Content-Type': 'application/json'}, encoding: utf8);
    });

    // WebSocket 路由
    router.get('/nbgui/v1/ws', (Request request) {
      return wsHandler(request);
    });

    // 定义404错误处理
    router.all('/<catchall|.*>', (Request request) {
      return Response.notFound('404 Not Found: ${request.url}');
    });

    // 配置中间件
    var httpHandler = const Pipeline()
        .addMiddleware(customLogRequests())
        .addMiddleware(handleAuth(token: token))
        .addMiddleware(handleErrors())
        .addHandler(router.call);

    await io.serve((Request request) {
      if (request.url.path == 'nbgui/v1/ws') {
        return wsHandler(request);
      }
      return httpHandler(request);
    }, host, port);

    if (host.contains(":")) {
      Logger.info(
          'HTTP server listening on http://[$host]:$port (Ctrl+C to quit)');
      Logger.info(
          'WebSocket server listening on ws://[$host]:$port/nbgui/v1/ws');
    } else {
      Logger.info('Serving at http://$host:$port (Ctrl+C to quit)');
      Logger.info('WebSocket server listening on ws://$host:$port/nbgui/v1/ws');
    }
  }, (error, stackTrace) {
    Logger.error('Unhandled Exception: $error\nStack Trace:\n$stackTrace');
  });
}
