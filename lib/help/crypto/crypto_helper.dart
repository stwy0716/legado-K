import 'dart:convert';
import 'package:crypto/crypto.dart';
class CryptoHelper { static String md5(String s) => md5.convert(utf8.encode(s)).toString(); }
