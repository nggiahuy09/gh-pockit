import 'package:meta/meta.dart';

/// What `env/<flavor>.json` says about the backend, checked against the flavor this build was made with (ADR-0038).
@immutable
sealed class GPBackendConfig {
  const GPBackendConfig();

  /// From `--dart-define-from-file`; [appFlavor] is Flutter's `appFlavor`.
  factory GPBackendConfig.fromEnvironment(String? appFlavor) => GPBackendConfig.resolve(
    appFlavor: appFlavor,
    envFlavor: const String.fromEnvironment('ENV_FLAVOR'),
    url: const String.fromEnvironment('SUPABASE_URL'),
    publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  factory GPBackendConfig.resolve({required String? appFlavor, required String envFlavor, required String url, required String publishableKey}) {
    if (appFlavor == null || envFlavor != appFlavor) return const GPInvalidBackendConfig(GPBackendConfigProblem.flavorMismatch);

    // Prod too, while there is no prod project; the change that creates one makes an empty prod file a refusal (ADR-0038).
    if (url.isEmpty && publishableKey.isEmpty) return const GPLocalOnlyBackendConfig();
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

/// Both keys empty: the app runs as before auth, every row owned by `'local'`.
final class GPLocalOnlyBackendConfig extends GPBackendConfig {
  const GPLocalOnlyBackendConfig();
}

final class GPRemoteBackendConfig extends GPBackendConfig {
  const GPRemoteBackendConfig({required this.url, required this.publishableKey});

  /// The project's API origin, `https://<ref>.supabase.co`, with no trailing slash.
  final String url;

  /// Ships in every build and is not a secret, but stays out of logs and `toString` with every other key.
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
  /// `ENV_FLAVOR` is not the flavor being built: `--flavor prod` with `env/dev.json`, or a file from before the key existed.
  flavorMismatch,

  /// One of the two keys is set and the other is empty.
  backendIncomplete,

  /// Not a bare `https://` origin, such as a dashboard link. Plain `http://` passes on dev only, for the local stack.
  urlMalformed,
}
