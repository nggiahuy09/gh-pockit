/// Lowercase with no separators: each is matched as a substring of a key normalised the same way, so `token` also covers `refresh_token`.
const Set<String> sensitiveFieldTokens = {
  'amount',
  'balance',
  'minorunits',
  'note',
  'memo',
  'description',
  'merchant',
  'email',
  'phone',
  'address',
  'fullname',
  'displayname',
  'password',
  'token',
  'secret',
  'apikey',
  'credential',
  'authorization',
  // Whole objects: a dumped DTO, row or body carries every field above.
  'payload',
  'body',
  'dto',
  'row',
};

const String redactedPlaceholder = '[redacted]';

Map<String, Object?> redactSensitiveFields(Map<String, Object?>? fields) {
  if (fields == null || fields.isEmpty) return const {};

  return {
    for (final MapEntry<String, Object?> entry in fields.entries) entry.key: _isSensitive(entry.key) ? redactedPlaceholder : _redactValue(entry.value),
  };
}

Object? _redactValue(Object? value) {
  return switch (value) {
    final Map<String, Object?> map => redactSensitiveFields(map),
    final Map<Object?, Object?> map => redactSensitiveFields(map.map((Object? k, Object? v) => MapEntry<String, Object?>('$k', v))),
    final Iterable<Object?> list => list.map(_redactValue).toList(),
    _ => value,
  };
}

bool _isSensitive(String key) {
  final normalised = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  return sensitiveFieldTokens.any(normalised.contains);
}
