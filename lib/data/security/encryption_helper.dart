import 'dart:convert';
import 'package:crypto/crypto.dart';

class EncryptionHelper {
  static String md5(String input) => md5.convert(utf8.encode(input)).toString();
  static String sha256(String input) => sha256.convert(utf8.encode(input)).toString();
}
