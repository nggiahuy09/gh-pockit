/// Field names whose value must never reach a log sink.
///
/// Golden rule 9: never log financial payloads. A log line may carry an id, an entity type and an error code — nothing that says how much money moved, or
/// who moved it. This matters more than it looks: logs end up in `logcat`, in a crash report attachment and in a Sentry breadcrumb, none of which are
/// places for someone's salary or their email address.
///
/// Matching is by *substring* on a normalised key, so one entry covers a family of names: `token` also catches `accessToken`, `refresh_token` and
/// `token_expiry`.
const Set<String> sensitiveFieldTokens = {
  // Money and what it was for.
  'amount',
  'balance',
  'minorunits',
  'note',
  'memo',
  'description',
  'merchant',
  // Identity.
  'email',
  'phone',
  'address',
  'fullname',
  'displayname',
  // Credentials.
  'password',
  'token',
  'secret',
  'apikey',
  'credential',
  'authorization',
  // Whole-object escape hatches: a DTO or a request body dumped into a log carries every field above with it.
  'payload',
  'body',
  'dto',
  'row',
};

/// Value written in place of a redacted one.
const String redactedPlaceholder = '[redacted]';

/// Returns [fields] with every sensitive value replaced by
/// [redactedPlaceholder], recursing into nested maps and lists.
///
/// The key is kept: knowing that a failed mutation *had* an amount is useful, knowing the amount is not.
Map<String, Object?> redactSensitiveFields(Map<String, Object?>? fields) {
  if (fields == null || fields.isEmpty) return const {};

  return {
    for (final MapEntry<String, Object?> entry in fields.entries) entry.key: _isSensitive(entry.key) ? redactedPlaceholder : _redactValue(entry.value),
  };
}

Object? _redactValue(Object? value) {
  return switch (value) {
    // A nested map may still be keyed by a sensitive name.
    final Map<String, Object?> map => redactSensitiveFields(map),
    final Map<Object?, Object?> map => redactSensitiveFields(map.map((Object? k, Object? v) => MapEntry<String, Object?>('$k', v))),
    final Iterable<Object?> list => list.map(_redactValue).toList(),
    _ => value,
  };
}

bool _isSensitive(String key) {
  // `amount_minor`, `amountMinor` and `AMOUNT-MINOR` are the same key as far as leaking goes, so compare on a form that ignores case and separators.
  final normalised = key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  return sensitiveFieldTokens.any(normalised.contains);
}
