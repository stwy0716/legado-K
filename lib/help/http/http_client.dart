import 'package:dio/dio.dart';

class HttpClient {
  static final Dio _dio = Dio();
  static Dio get instance => _dio;
}
