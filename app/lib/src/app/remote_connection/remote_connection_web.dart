import 'dart:io';

import 'package:flutter/foundation.dart';

import 'remote_status.dart';

const defaultRemoteHeartbeatInterval = Duration(seconds: 15);
const remoteSeatTokenHeader = 'X-Kolkhoz-Seat-Token';

typedef RemoteWebSocketConnector =
    Future<WebSocket> Function(Uri uri, Map<String, dynamic> headers);
typedef RemoteRequestHandler =
    Future<Object?> Function(
      String method,
      String path,
      Map<String, String> query,
      Map<String, String> headers,
      Object? body,
    );

/// Network play is deliberately absent from the public browser demo.
class RemoteConnection extends ChangeNotifier {
  RemoteConnection({
    required this.baseURL,
    required this.accessTokenProvider,
    required this.deviceID,
    required this.activeSessionID,
    this.requestHandler,
    this.heartbeatInterval = defaultRemoteHeartbeatInterval,
  });

  final Duration heartbeatInterval;
  final String? Function() activeSessionID;
  final Uri baseURL;
  final Future<String?> Function() accessTokenProvider;
  final String deviceID;
  final RemoteRequestHandler? requestHandler;

  RemoteStatus get status =>
      const RemoteStatus(availability: RemoteAvailability.unreachable);
  bool get heartbeatRunning => false;

  Future<Object?> request({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Object? body,
    bool includeAuthorization = true,
  }) async {
    final handler = requestHandler;
    if (handler != null) {
      return handler(method, path, query, headers, body);
    }
    throw UnsupportedError('Online play is not included in the web demo');
  }

  Future<Map<String, Object?>> requestJson({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Object? body,
    bool includeAuthorization = true,
  }) async {
    final value = await request(
      method: method,
      path: path,
      query: query,
      headers: headers,
      body: body,
      includeAuthorization: includeAuthorization,
    );
    if (value is! Map) {
      throw const FormatException('Remote response must be a JSON object');
    }
    return value.cast<String, Object?>();
  }

  Uri resolve(String path, [Map<String, String> query = const {}]) {
    final normalizedBase = baseURL.path.endsWith('/')
        ? baseURL
        : baseURL.replace(path: '${baseURL.path}/');
    final resolved = normalizedBase.resolve(path);
    return query.isEmpty ? resolved : resolved.replace(queryParameters: query);
  }

  Future<WebSocket> openSocket({
    required String path,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
  }) => Future.error(
    UnsupportedError('Online play is not included in the web demo'),
  );

  void startHeartbeat() {}
  void stopHeartbeat() {}
  Future<void> refreshHeartbeat() async {}
}
