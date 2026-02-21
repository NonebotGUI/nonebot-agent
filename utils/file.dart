import 'dart:io';
import 'logger.dart';
import 'manage.dart';
import 'package:path/path.dart' as p;

class FileUtils {
  /// 列出对应id下的文件和目录
  static List<Map<String, String>> readDir(String uuid, String subPath) {
    final botPtah = Bot.path(uuid);
    final path = p.join(botPtah, subPath);
    final directory = Directory(path);
    final result = <Map<String, String>>[];

    if (!directory.existsSync()) {
      Logger.error("Directory does not exist: $path");
      return result;
    }
    try {
      for (final entity in directory.listSync()) {
        if (entity is File) {
          result.add({
            'name': p.basename(entity.path),
            'type': 'file',
          });
        } else if (entity is Directory) {
          result.add({
            'name': p.basename(entity.path),
            'type': 'directory',
          });
        }
      }
      // 对结果进行排序
      result.sort((a, b) {
        if (a['type'] == 'directory' && b['type'] == 'file') {
          return -1;
        }
        if (a['type'] == 'file' && b['type'] == 'directory') {
          return 1;
        }
        return a['name']!.compareTo(b['name']!);
      });
      return result;
    } catch (e, st) {
      Logger.error("Failed to read directory: $path, error: $e\n$st");
      return result;
    }
  }

  /// 创建目录
  static bool createDir(String uuid, String subPath, String dirName) {
    final botPtah = Bot.path(uuid);
    final path = p.join(botPtah, subPath, dirName);
    final directory = Directory(path);
    if (dirName.contains('/') || dirName.contains('\\')) {
      Logger.error("Directory name cannot contain path separators: $dirName");
      return false;
    }
    if (dirName.isEmpty) {
      Logger.error("Directory name cannot be empty.");
      return false;
    }
    if (dirName == '.' || dirName == '..') {
      Logger.error("Directory name cannot be '.' or '..'.");
      return false;
    }
    if (directory.existsSync()) {
      Logger.error("Directory already exists: $path");
      return false;
    }
    try {
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
      return true;
    } catch (e, st) {
      Logger.error("Failed to create directory: $path, error: $e\n$st");
      return false;
    }
  }

  /// 删除目录或者文件
  static bool deletePath(String uuid, String subPath, String name) {
    final botPtah = Bot.path(uuid);
    final path = p.join(botPtah, subPath, name);
    final entity = FileSystemEntity.typeSync(path);
    try {
      if (entity == FileSystemEntityType.directory) {
        final directory = Directory(path);
        if (directory.existsSync()) {
          directory.deleteSync(recursive: true);
        }
      } else if (entity == FileSystemEntityType.file) {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } else {
        Logger.error("Path does not exist: $path");
        return false;
      }
      return true;
    } catch (e, st) {
      Logger.error("Failed to delete path: $path, error: $e\n$st");
      return false;
    }
  }

  /// 复制文件或目录
  static bool copyPath(
      String uuid, String subPath, String sourceName, String targetName) {
    final botPtah = Bot.path(uuid);
    final sourcePath = p.join(botPtah, subPath, sourceName);
    var targetDir = p.join(botPtah, targetName);
    var targetPath = p.join(targetDir, p.basename(sourcePath));

    try {
      final sourceType = FileSystemEntity.typeSync(sourcePath);
      if (sourceType == FileSystemEntityType.notFound) {
        Logger.error("Source path not found: $sourcePath");
        return false;
      }

      if (sourceType == FileSystemEntityType.file) {
        File(sourcePath).copySync(targetPath);
      } else if (sourceType == FileSystemEntityType.directory) {
        final sourceDir = Directory(sourcePath);
        final targetDir = Directory(targetPath);
        if (!targetDir.existsSync()) {
          targetDir.createSync(recursive: true);
        }
        for (var entity in sourceDir.listSync()) {
          final entityName = p.basename(entity.path);
          final newTargetPath = p.join(targetDir.path, entityName);
          if (entity is File) {
            entity.copySync(newTargetPath);
          } else if (entity is Directory) {
            copyPath(uuid, '', entity.path.substring(botPtah.length + 1),
                newTargetPath.substring(botPtah.length + 1));
          }
        }
      }
      Logger.info("Copied '$sourcePath' to '$targetPath'");
      return true;
    } catch (e, st) {
      Logger.error(
          "Failed to copy path from $sourcePath to $targetPath, error: $e\n$st");
      return false;
    }
  }

  static bool renamePath(
      String uuid, String subPath, String oldName, String newName) {
    final botPtah = Bot.path(uuid);
    final oldPath = p.join(botPtah, subPath, oldName);
    final newPath = p.join(botPtah, subPath, newName);
    final entityType = FileSystemEntity.typeSync(oldPath);
    if (entityType == FileSystemEntityType.notFound) {
      Logger.error("Path does not exist: $oldPath");
      return false;
    }
    try {
      if (entityType == FileSystemEntityType.directory) {
        final directory = Directory(oldPath);
        directory.renameSync(newPath);
      } else if (entityType == FileSystemEntityType.file) {
        final file = File(oldPath);
        file.renameSync(newPath);
      }
      return true;
    } catch (e, st) {
      Logger.error(
          "Failed to rename path from $oldPath to $newPath, error: $e\n$st");
      return false;
    }
  }

  /// 读取文件内容
  static String? readFile(String uuid, String subPath, String fileName) {
    final botPtah = Bot.path(uuid);
    final filePath = p.join(botPtah, subPath, fileName);
    final file = File(filePath);
    if (!file.existsSync()) {
      Logger.error("File does not exist: $filePath");
      return null;
    }
    try {
      return file.readAsStringSync();
    } catch (e, st) {
      Logger.error("Failed to read file: $filePath, error: $e\n$st");
      return null;
    }
  }

  /// 写入文件内容
  static bool writeFile(
      String uuid, String subPath, String fileName, String content) {
    final botPtah = Bot.path(uuid);
    final filePath = p.join(botPtah, subPath, fileName);
    final file = File(filePath);
    try {
      file.writeAsStringSync(content);
      return true;
    } catch (e, st) {
      Logger.error("Failed to write file: $filePath, error: $e\n$st");
      return false;
    }
  }

  /// 移动文件或目录
  static bool movePath(
      String uuid, String subPath, String sourceName, String targetName) {
    final botPtah = Bot.path(uuid);
    final sourcePath = p.join(botPtah, subPath, sourceName);

    // 获取目标目录的绝对路径 (targetName 是前端传来的 destination path)
    var targetDir = p.join(botPtah, targetName);

    // 将文件名拼接到目标目录，构成完整的目标文件路径
    var targetPath = p.join(targetDir, p.basename(sourcePath));

    try {
      final sourceType = FileSystemEntity.typeSync(sourcePath);
      if (sourceType == FileSystemEntityType.notFound) {
        Logger.error("Source path does not exist: $sourcePath");
        return false;
      }

      Directory(p.dirname(targetPath)).createSync(recursive: true);
      if (sourceType == FileSystemEntityType.directory) {
        Directory(sourcePath).renameSync(targetPath);
      } else if (sourceType == FileSystemEntityType.file) {
        File(sourcePath).renameSync(targetPath);
      }
      Logger.info("Moved '$sourcePath' to '$targetPath'");
      return true;
    } catch (e, st) {
      Logger.error(
          "Failed to move path from $sourcePath to $targetPath, error: $e\n$st");
      return false;
    }
  }

  /// 创建空文件
  static bool createFile(String uuid, String subPath, String fileName) {
    final botPtah = Bot.path(uuid);
    final filePath = p.join(botPtah, subPath, fileName);
    final file = File(filePath);
    if (fileName.contains('/') || fileName.contains('\\')) {
      Logger.error("File name cannot contain path separators: $fileName");
      return false;
    }
    if (fileName.isEmpty) {
      Logger.error("File name cannot be empty.");
      return false;
    }
    if (fileName == '.' || fileName == '..') {
      Logger.error("File name cannot be '.' or '..'.");
      return false;
    }
    if (file.existsSync()) {
      Logger.error("File already exists: $filePath");
      return false;
    }
    try {
      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }
      return true;
    } catch (e, st) {
      Logger.error("Failed to create file: $filePath, error: $e\n$st");
      return false;
    }
  }
}
