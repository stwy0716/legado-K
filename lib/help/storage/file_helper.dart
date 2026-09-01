import 'dart:io';
class FileHelper { static Future<String> readFile(String path) => File(path).readAsString(); }
