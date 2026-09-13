import 'package:flutter_test/flutter_test.dart';
import 'package:ghpockit/core/error/failure.dart';
import 'package:ghpockit/core/error/failure_message.dart';
import 'package:ghpockit/core/localization/locale_base/locale_base.dart';
import 'package:ghpockit/core/localization/locale_en/locale_en.dart';
import 'package:ghpockit/core/localization/locale_vi/locale_vi.dart';

/// Every subtype of [GPFailure], listed by hand.
///
/// Dart cannot enumerate the subtypes of a sealed class at runtime, so this list is the manual mirror of the exhaustive switch in
/// `failure_message.dart`. It is not redundant with the compiler check: the compiler guarantees the switch handles every subtype, this guarantees the
/// *tests* see every subtype. Forget to add a row and a new failure ships untested — that is the only gap the compiler leaves.
const allFailures = <GPFailure>[
  GPNetworkFailure(),
  GPTimeoutFailure(),
  GPAuthenticationFailure(),
  GPAuthorizationFailure(),
  GPValidationFailure(),
  GPConflictFailure(entityId: 'tx-1', localVersion: 3, remoteVersion: 4),
  GPDatabaseFailure(),
  GPUnknownFailure(),
];

void main() {
  group('GPFailure', () {
    test('fieldless failures compare equal without a hand-written operator', () {
      // `const` canonicalisation is what makes this work, which is why only GPConflictFailure needs an explicit `==`.
      expect(const GPNetworkFailure(), const GPNetworkFailure());
      expect(const GPUnknownFailure(), const GPUnknownFailure());
      expect(const GPNetworkFailure(), isNot(const GPTimeoutFailure()));
    });

    test('two failures of different types are never equal', () {
      for (var i = 0; i < allFailures.length; i++) {
        for (var j = 0; j < allFailures.length; j++) {
          if (i == j) continue;
          expect(allFailures[i], isNot(allFailures[j]), reason: '${allFailures[i].runtimeType} must not equal ${allFailures[j].runtimeType}');
        }
      }
    });
  });

  group('GPConflictFailure', () {
    test('is equal by value, not by identity', () {
      // Built without `const` on purpose: at runtime the conflict resolver constructs these from real version numbers, so they are two distinct
      // objects rather than one canonicalised instance. That is exactly the case `operator ==` exists for, which is why `prefer_const_constructors`
      // is suppressed here instead of obeyed — obeying it would turn this into a test of const canonicalisation and assert nothing about equality.
      // ignore: prefer_const_constructors
      final first = GPConflictFailure(entityId: 'tx-1', localVersion: 3, remoteVersion: 4);
      // Same reason as above: `const` here would hand back the very same object and `identical` below would pass for the wrong reason.
      // ignore: prefer_const_constructors
      final second = GPConflictFailure(entityId: 'tx-1', localVersion: 3, remoteVersion: 4);

      expect(identical(first, second), isFalse);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test('differs when any single field differs', () {
      const base = GPConflictFailure(entityId: 'tx-1', localVersion: 3, remoteVersion: 4);

      expect(base, isNot(const GPConflictFailure(entityId: 'tx-2', localVersion: 3, remoteVersion: 4)));
      expect(base, isNot(const GPConflictFailure(entityId: 'tx-1', localVersion: 9, remoteVersion: 4)));
      expect(base, isNot(const GPConflictFailure(entityId: 'tx-1', localVersion: 3, remoteVersion: 9)));
    });

    test('toString carries the id and versions and nothing else', () {
      // Golden rule 9: id + entity type + error code may be logged, financial payloads may not. There is no amount or note to leak here, and there
      // must never be one — this test is the guard for whoever adds a field later.
      const failure = GPConflictFailure(entityId: 'tx-1', localVersion: 3, remoteVersion: 4);

      expect(failure.toString(), 'GPConflictFailure(entityId: tx-1, localVersion: 3, remoteVersion: 4)');
    });
  });

  group('GPFailureMessage', () {
    const locales = <GPLocaleBase>[GPLocaleEn(), GPLocaleVi()];

    for (final locale in locales) {
      group(locale.locale.name, () {
        test('every failure resolves to a non-empty message', () {
          for (final failure in allFailures) {
            expect(failure.message(locale).trim(), isNotEmpty, reason: '${failure.runtimeType} has no message');
          }
        });

        test('no two failures share a message', () {
          // A duplicate would mean the user cannot tell two situations apart — "no internet" and "the server rejected your change" need different
          // actions from them.
          final messages = allFailures.map((failure) => failure.message(locale)).toList();

          expect(messages.toSet(), hasLength(messages.length));
        });
      });
    }

    test('English and Vietnamese never return the same string', () {
      // Catches the copy-paste that leaves an untranslated English sentence in GPLocaleVi. The analyzer cannot see that — it only checks that the
      // getter exists.
      for (final failure in allFailures) {
        expect(failure.message(const GPLocaleEn()), isNot(failure.message(const GPLocaleVi())), reason: '${failure.runtimeType} is not translated');
      }
    });

    test('a conflict reads the same regardless of which row conflicted', () {
      // The message is a function of the type, not the payload (ADR-0004). If this ever fails, the entity id has leaked into user-facing copy.
      const first = GPConflictFailure(entityId: 'tx-1', localVersion: 1, remoteVersion: 2);
      const second = GPConflictFailure(entityId: 'acc-9', localVersion: 7, remoteVersion: 8);

      expect(first.message(const GPLocaleEn()), second.message(const GPLocaleEn()));
    });
  });
}
