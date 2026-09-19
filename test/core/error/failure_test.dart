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
  // Every code, not one representative: each maps to its own sentence, so the "no two failures share a message" check below is what proves a new code did
  // not quietly reuse an existing string.
  GPValidationFailure(GPValidationCode.accountNameEmpty),
  GPValidationFailure(GPValidationCode.accountNameTooLong),
  GPConflictFailure(entityId: 'tx-1', localVersion: 3, remoteVersion: 4),
  GPNotFoundFailure(),
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

  group('GPValidationFailure', () {
    test('every validation code appears in allFailures', () {
      // The same manual-mirror problem the `allFailures` doc describes, one level down: a code with no row above ships with an untested message.
      final covered = allFailures.whereType<GPValidationFailure>().map((failure) => failure.code).toSet();

      expect(covered, GPValidationCode.values.toSet());
    });

    test('is equal by value, not by identity', () {
      // Built without `const` on purpose, for the same reason as GPConflictFailure below: `const` would hand back one canonicalised object and the
      // `identical` check would pass without saying anything about `operator ==`.
      // ignore: prefer_const_constructors
      final first = GPValidationFailure(GPValidationCode.accountNameEmpty);
      // Same reason as above.
      // ignore: prefer_const_constructors
      final second = GPValidationFailure(GPValidationCode.accountNameEmpty);

      expect(identical(first, second), isFalse);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(const GPValidationFailure(GPValidationCode.accountNameTooLong)));
    });

    test('toString carries the code and nothing else', () {
      // Golden rule 9: a code is exactly what a log line may hold, and the field name it refers to is not user data.
      expect(const GPValidationFailure(GPValidationCode.accountNameEmpty).toString(), 'GPValidationFailure(code: accountNameEmpty)');
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

    test('a validation message names the rule that broke, not just "invalid"', () {
      // The reason GPValidationCode exists: a single generic sentence makes the user hunt for the field that is wrong. If these two ever converge, that
      // has been given up.
      const empty = GPValidationFailure(GPValidationCode.accountNameEmpty);
      const tooLong = GPValidationFailure(GPValidationCode.accountNameTooLong);

      expect(empty.message(const GPLocaleEn()), isNot(tooLong.message(const GPLocaleEn())));
      expect(empty.message(const GPLocaleVi()), isNot(tooLong.message(const GPLocaleVi())));
    });

    test('a validation message carries no limit number', () {
      // `AccountEntity.nameMaxLength` lives in a feature's domain and presentation must not import it to build a sentence; a hard-coded 100 in two languages is
      // a number that goes stale silently. The form field shows the limit with a live counter instead.
      for (final locale in locales) {
        expect(const GPValidationFailure(GPValidationCode.accountNameTooLong).message(locale), isNot(contains('100')));
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
