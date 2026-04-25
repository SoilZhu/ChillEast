import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/homework_model.dart';

class HomeworkStorage {
  static const String _fileName = 'homework_list.json';

  Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<void> saveHomeworkList(List<HomeworkModel> homeworks) async {
    try {
      final file = await _getFile();
      final jsonList = homeworks.map((h) => h.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      // 忽略
    }
  }

  Future<List<HomeworkModel>> readHomeworkList() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList.map((j) => HomeworkModel.fromJson(j as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteHomeworkList() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 忽略
    }
  }
}
