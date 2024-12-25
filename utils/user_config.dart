import 'dart:convert';
import 'dart:io';

/// 用户配置文件
class UserConfig {
  static final File _configFile = File('config.json');

  /// 初始化用户配置文件
  static Map<String, dynamic> _config() {
    File file = File('config.json');
    String content = file.readAsStringSync();
    return jsonDecode(content);
  }

  /// 是否自动检查更新
  static bool checkUpdate() {
    Map<String, dynamic> jsonMap = _config();
    if (jsonMap.containsKey("checkUpdate")) {
      bool checkUpdate = jsonMap['checkUpdate'];
      return checkUpdate;
    } else {
      setCheckUpdate(true);
      return true;
    }
  }

  /// 设置是否自动检查更新
  static void setCheckUpdate(checkUpdate) {
    Map<String, dynamic> jsonMap = _config();
    jsonMap['checkUpdate'] = checkUpdate;
    _configFile.writeAsStringSync(jsonEncode(jsonMap));
  }

  /// Python路径
  static dynamic pythonPath() {
    Map<String, dynamic> jsonMap = _config();
    String pyPath = jsonMap['python'].toString();
    if (pyPath == 'default') {
      if (Platform.isLinux || Platform.isMacOS) {
        return 'python3';
      } else if (Platform.isWindows) {
        return 'python.exe';
      }
    } else {
      return pyPath.replaceAll('\\', '\\\\');
    }
  }

  /// 设置Python路径
  static void setPythonPath(pythonPath) {
    Map<String, dynamic> jsonMap = _config();
    jsonMap['python'] = pythonPath;
    _configFile.writeAsStringSync(jsonEncode(jsonMap));
  }

  /// NoneBot-CLI路径
  static dynamic nbcliPath() {
    Map<String, dynamic> jsonMap = _config();
    String nbcliPath = jsonMap['nbcli'].toString();
    if (nbcliPath == 'default') {
      return 'nb';
    } else {
      return nbcliPath.replaceAll('\\', '\\\\');
    }
  }

  /// 设置NoneBot-CLI路径
  static void setNbcliPath(nbcliPath) {
    Map<String, dynamic> jsonMap = _config();
    jsonMap['nbcli'] = nbcliPath;
    _configFile.writeAsStringSync(jsonEncode(jsonMap));
  }

  /// Bot日志最大行数
  static int logMaxLines() {
    Map<String, dynamic> jsonMap = _config();
    if (jsonMap.containsKey("logMaxLines")) {
      int logMaxLines = jsonMap['logMaxLines'];
      return logMaxLines;
    } else {
      setLogMaxLines(75);
      return 75;
    }
  }

  /// 设置Bot日志最大行数
  static void setLogMaxLines(logMaxLines) {
    Map<String, dynamic> jsonMap = _config();
    jsonMap['logMaxLines'] = logMaxLines;
    _configFile.writeAsStringSync(jsonEncode(jsonMap));
  }
}
