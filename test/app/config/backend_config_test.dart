import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/app/config/backend_config.dart';

const _url = 'https://abcdefghijklmnop.supabase.co';
const _key = 'sb_publishable_test';

GPBackendConfig _resolve({String? appFlavor = 'dev', String envFlavor = 'dev', String url = _url, String publishableKey = _key}) =>
    GPBackendConfig.resolve(appFlavor: appFlavor, envFlavor: envFlavor, url: url, publishableKey: publishableKey);

void main() {
  group('flavor', () {
    test('a matching env file resolves to its backend', () {
      final config = _resolve();

      expect(config, isA<GPRemoteBackendConfig>().having((c) => c.url, 'url', _url).having((c) => c.publishableKey, 'publishableKey', _key));
    });

    test('prod built with the dev file is refused', () {
      expect(_resolve(appFlavor: 'prod'), _invalid(GPBackendConfigProblem.flavorMismatch));
    });

    test('dev built with the prod file is refused', () {
      expect(_resolve(envFlavor: 'prod'), _invalid(GPBackendConfigProblem.flavorMismatch));
    });

    test('a file from before ENV_FLAVOR existed is refused', () {
      expect(_resolve(envFlavor: ''), _invalid(GPBackendConfigProblem.flavorMismatch));
    });

    test('no flavor at all is refused, even with an empty file', () {
      expect(_resolve(appFlavor: null, envFlavor: '', url: '', publishableKey: ''), _invalid(GPBackendConfigProblem.flavorMismatch));
    });
  });

  group('empty keys', () {
    test('both empty runs local-only on dev', () {
      expect(_resolve(url: '', publishableKey: ''), isA<GPLocalOnlyBackendConfig>());
    });

    test('both empty runs local-only on prod too, while there is no prod project', () {
      expect(_resolve(appFlavor: 'prod', envFlavor: 'prod', url: '', publishableKey: ''), isA<GPLocalOnlyBackendConfig>());
    });

    test('a URL without a key is refused', () {
      expect(_resolve(publishableKey: ''), _invalid(GPBackendConfigProblem.backendIncomplete));
    });

    test('a key without a URL is refused', () {
      expect(_resolve(url: ''), _invalid(GPBackendConfigProblem.backendIncomplete));
    });
  });

  group('url', () {
    test('a trailing slash is dropped', () {
      expect(_resolve(url: '$_url/'), isA<GPRemoteBackendConfig>().having((c) => c.url, 'url', _url));
    });

    test('the dashboard link is refused', () {
      expect(_resolve(url: 'https://supabase.com/dashboard/project/abcdefghijklmnop'), _invalid(GPBackendConfigProblem.urlMalformed));
    });

    test('a path, a query or a fragment is refused', () {
      for (final url in ['$_url/auth/v1', '$_url?x=1', '$_url#top']) {
        expect(_resolve(url: url), _invalid(GPBackendConfigProblem.urlMalformed), reason: url);
      }
    });

    test('no scheme, or not http(s), is refused', () {
      for (final url in ['abcdefghijklmnop.supabase.co', 'ftp://abcdefghijklmnop.supabase.co', ' $_url', 'https://']) {
        expect(_resolve(url: url), _invalid(GPBackendConfigProblem.urlMalformed), reason: url);
      }
    });

    test('plain http reaches the local stack on dev, port kept', () {
      expect(_resolve(url: 'http://127.0.0.1:54321'), isA<GPRemoteBackendConfig>().having((c) => c.url, 'url', 'http://127.0.0.1:54321'));
    });

    test('plain http is refused on prod', () {
      expect(_resolve(appFlavor: 'prod', envFlavor: 'prod', url: 'http://abcdefghijklmnop.supabase.co'), _invalid(GPBackendConfigProblem.urlMalformed));
    });
  });

  test('toString never prints the key', () {
    expect(_resolve().toString(), isNot(contains(_key)));
  });
}

Matcher _invalid(GPBackendConfigProblem problem) => isA<GPInvalidBackendConfig>().having((config) => config.problem, 'problem', problem);
