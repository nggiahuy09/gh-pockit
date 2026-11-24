import 'package:meta/meta.dart';

/// `env/<flavor>.json`, checked against the build's flavor (ADR-0038).
@immutable
sealed class GPBackendConfig {
  const GPBackendConfig();

  factory GPBackendConfig.fromEnvironment(String? appFlavor) => GPBackendConfig.resolve(
    appFlavor: appFlavor,
    envFlavor: const String.fromEnvironment('ENV_FLAVOR'),
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  factory GPBackendConfig.resolve({required String? appFlavor, required String envFlavor, required String url, required String publishableKey}) {
    // Before the flavor check: with no backend there is nothing to mix up (ADR-0038).
    if (url.isEmpty && publishableKey.isEmpty) return const GPLocalOnlyBackendConfig();
    if (appFlavor == null || envFlavor != appFlavor) return const GPInvalidBackendConfig(GPBackendConfigProblem.flavorMismatch);
    if (url.isEmpty || publishableKey.isEmpty) return const GPInvalidBackendConfig(GPBackendConfigProblem.backendIncomplete);

    final isProd = appFlavor == _prodFlavor;
    final parsed = Uri.tryParse(url);
    if (parsed == null || !_isOrigin(parsed) || !(parsed.scheme == 'https' || (!isProd && parsed.scheme == 'http'))) {
      return const GPInvalidBackendConfig(GPBackendConfigProblem.urlMalformed);
    }

    return GPRemoteBackendConfig(url: parsed.origin, publishableKey: publishableKey);
  }

  static const String _prodFlavor = 'prod';

  static bool _isOrigin(Uri uri) => uri.host.isNotEmpty && (uri.path.isEmpty || uri.path == '/') && !uri.hasQuery && !uri.hasFragment;
}

final class GPLocalOnlyBackendConfig extends GPBackendConfig {
  const GPLocalOnlyBackendConfig();
}

final class GPRemoteBackendConfig extends GPBackendConfig {
  const GPRemoteBackendConfig({required this.url, required this.publishableKey});

  /// The API origin, with no trailing slash.
  final String url;

  /// Not a secret, but kept out of `toString`.
  final String publishableKey;

  @override
  String toString() => 'GPRemoteBackendConfig(url: $url)';
}

final class GPInvalidBackendConfig extends GPBackendConfig {
  const GPInvalidBackendConfig(this.problem);

  final GPBackendConfigProblem problem;

  @override
  String toString() => 'GPInvalidBackendConfig(${problem.name})';
}

enum GPBackendConfigProblem {
  /// A backend set for another flavor, or a file from before `ENV_FLAVOR`.
  flavorMismatch,

  backendIncomplete,

  /// Not a bare origin (e.g. a dashboard link); `http://` passes on dev only.
  urlMalformed,
}
