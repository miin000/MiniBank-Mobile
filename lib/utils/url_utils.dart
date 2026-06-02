String toWsUrl(String baseUrl) {
  return baseUrl
      .replaceFirst(RegExp(r'^https'), 'wss')
      .replaceFirst(RegExp(r'^http'), 'ws')
      .replaceAll(RegExp(r'/+$'), '')
      + '/ws';
}