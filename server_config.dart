class ServerConfig {
  // まとめて変更したいときはこの1箇所だけ編集。
  // 例: --dart-define=SERVER_BASE_URL=http://10.0.2.2:3000
  static const String baseUrl = String.fromEnvironment(
    'SERVER_BASE_URL',
    defaultValue: 'http://192.168.11.8:3000',
  );

  static final Uri baseUri = Uri.parse(baseUrl);

  static String wsBaseUrl() {
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    return baseUri.replace(scheme: wsScheme).toString();
  }

  static Uri api(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return baseUri.replace(path: normalizedPath);
  }

  static String assetUrl(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return baseUri.replace(path: normalizedPath).toString();
  }
}