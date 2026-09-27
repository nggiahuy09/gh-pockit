// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SettingsTableTable extends SettingsTable with TableInfo<$SettingsTableTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SettingsTableTable createAlias(String alias) {
    return $SettingsTableTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  /// Namespaced by dotted prefix (`locale.selected`) so a later feature cannot collide with an older one by picking the same short word.
  final String key;

  /// Always a string, whatever the caller means by it. Parsing belongs to the store that owns the key — `GPDriftLocaleStore` for `locale.*` — not here.
  final String value;

  /// Epoch millis, UTC (§6 — never an ISO string). Written from `GPClock`, never `DateTime.now()`, so a test can state the time instead of racing it.
  final int updatedAt;
  const SettingRow({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SettingsTableCompanion toCompanion(bool nullToAbsent) {
    return SettingsTableCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SettingRow copyWith({String? key, String? value, int? updatedAt}) => SettingRow(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SettingRow copyWithCompanion(SettingsTableCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) => identical(this, other) || (other is SettingRow && other.key == this.key && other.value == this.value && other.updatedAt == this.updatedAt);
}

class SettingsTableCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SettingsTableCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsTableCompanion.insert({
    required String key,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsTableCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SettingsTableCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsTableCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountsTableTable extends AccountsTable with TableInfo<$AccountsTableTable, AccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    check: () => currencyCode.length.equals(3),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _initialBalanceMeta = const VerificationMeta(
    'initialBalance',
  );
  @override
  late final GeneratedColumn<int> initialBalance = GeneratedColumn<int>(
    'initial_balance',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    name,
    type,
    currencyCode,
    initialBalance,
    isArchived,
    createdAt,
    updatedAt,
    version,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('initial_balance')) {
      context.handle(
        _initialBalanceMeta,
        initialBalance.isAcceptableOrUnknown(
          data['initial_balance']!,
          _initialBalanceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_initialBalanceMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    } else if (isInserting) {
      context.missing(_isArchivedMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      initialBalance: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}initial_balance'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $AccountsTableTable createAlias(String alias) {
    return $AccountsTableTable(attachedDatabase, alias);
  }
}

class AccountRow extends DataClass implements Insertable<AccountRow> {
  /// UUID, generated client-side by `GPUuidGenerator` before the insert (golden rule 4, ADR-0002).
  ///
  /// Not `clientDefault`: drift would then mint the id inside the insert, and the repository would have to read the row back to learn what it just wrote —
  /// which is the round trip client-side ids exist to remove. The caller generates it, the caller keeps it, the outbox references it.
  final String id;

  /// `localOwnerId` until W10. Never null — see `core/database/owner_id.dart`.
  final String ownerId;

  /// User-facing, user-editable. No length constraint here on purpose: "an account name may not be blank" is a business rule, and §3 puts business rules in
  /// `domain/` where T5's `AccountEntity` can state it once for every caller, not in a CHECK that only the DB path enforces.
  final String name;

  /// `AccountType` as of T5, stored as plain text and converted by `AccountMapper` at T6 — not `textEnum<AccountType>()`.
  ///
  /// `textEnum` persists the Dart constant's *name*, which turns renaming an enum value into a silent data migration: the code compiles, the old rows stop
  /// matching, and nothing fails until a user notices their accounts lost their type. An explicit mapper makes the stored vocabulary a thing a reviewer can
  /// see in a diff, and it is also what §3's three-model rule asks for — the row and the entity are allowed to disagree about representation.
  final String type;

  /// ISO-4217, e.g. `VND`, `USD`.
  ///
  /// The one hand-written CHECK on this table, and the reason it is not "domain validation leaking into the DB": this column decides how [initialBalance]
  /// is read. VND has exponent 0 and USD exponent 2, so a malformed code makes the integer next to it un-interpretable rather than merely invalid. That is
  /// a storage-integrity property, and W3 T4's `CurrencyCode` catalog layers the business meaning — which codes actually exist — on top of it.
  ///
  /// `check()` rather than the shorter `withLength(min: 3, max: 3)`, which is what this column was written as first. `withLength` compiles to a Dart-side
  /// validator and nothing else: the column reached the schema dump as a bare `TEXT NOT NULL`, so it would have held for a companion insert and evaporated
  /// for a raw upsert or a migration. `check()` is written into the `CREATE TABLE` instead, which also carries it into the fixtures W9 migrates against.
  /// Both paths are asserted in `test/features/accounts/data/tables/accounts_table_test.dart` — the second test is there precisely to fail if someone
  /// "simplifies" this back.
  final String currencyCode;

  /// Minor units, `int` — golden rule 2. 1.500.000 ₫ is `1500000`; $12.34 is `1234`. There is no `double` anywhere on the path from here to the UI.
  ///
  /// The *opening* balance only. The current balance is never a column: §6 forbids a stored derived value without a recompute strategy, and §12.8 names it
  /// an anti-pattern outright. It is `initial_balance + SUM(transactions)` over an index, measured at W8.
  final int initialBalance;

  /// Archived ≠ deleted. An archived account disappears from pickers but keeps its history and keeps syncing; [deletedAt] is the tombstone.
  ///
  /// `boolean()` rather than `integer()`: the storage is the same `INTEGER` the blueprint specifies, drift adds `CHECK (is_archived IN (0, 1))` for free,
  /// and the Dart side gets a `bool` instead of an `int` that a caller could compare against 2.
  final bool isArchived;

  /// Epoch millis, UTC — never an ISO string (§6), never `DateTime.now()` (§8 wants a fake clock, `GPClock` provides one).
  final int createdAt;

  /// Epoch millis, UTC. Half of the pull cursor at W12 T2, so it must move on every write the server should learn about.
  final int updatedAt;

  /// Optimistic-concurrency token (§7). Starts at 1 on create and is set from the server's response, never incremented hopefully on the client.
  final int version;

  /// Soft-delete tombstone (golden rule 5): epoch millis when deleted, null while alive. Every local query filters `deleted_at IS NULL` — audited across
  /// all DAOs at W12 T3.
  ///
  /// Not indexed. At transaction scale a partial index earns its keep; a user has a handful of accounts, and an index nothing needs is still an index every
  /// write maintains.
  final int? deletedAt;
  const AccountRow({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.initialBalance,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['currency_code'] = Variable<String>(currencyCode);
    map['initial_balance'] = Variable<int>(initialBalance);
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  AccountsTableCompanion toCompanion(bool nullToAbsent) {
    return AccountsTableCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      name: Value(name),
      type: Value(type),
      currencyCode: Value(currencyCode),
      initialBalance: Value(initialBalance),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: Value(version),
      deletedAt: deletedAt == null && nullToAbsent ? const Value.absent() : Value(deletedAt),
    );
  }

  factory AccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountRow(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      initialBalance: serializer.fromJson<int>(json['initialBalance']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'initialBalance': serializer.toJson<int>(initialBalance),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int>(version),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  AccountRow copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? type,
    String? currencyCode,
    int? initialBalance,
    bool? isArchived,
    int? createdAt,
    int? updatedAt,
    int? version,
    Value<int?> deletedAt = const Value.absent(),
  }) => AccountRow(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    name: name ?? this.name,
    type: type ?? this.type,
    currencyCode: currencyCode ?? this.currencyCode,
    initialBalance: initialBalance ?? this.initialBalance,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  AccountRow copyWithCompanion(AccountsTableCompanion data) {
    return AccountRow(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      currencyCode: data.currencyCode.present ? data.currencyCode.value : this.currencyCode,
      initialBalance: data.initialBalance.present ? data.initialBalance.value : this.initialBalance,
      isArchived: data.isArchived.present ? data.isArchived.value : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountRow(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    name,
    type,
    currencyCode,
    initialBalance,
    isArchived,
    createdAt,
    updatedAt,
    version,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountRow &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.name == this.name &&
          other.type == this.type &&
          other.currencyCode == this.currencyCode &&
          other.initialBalance == this.initialBalance &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.deletedAt == this.deletedAt);
}

class AccountsTableCompanion extends UpdateCompanion<AccountRow> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> name;
  final Value<String> type;
  final Value<String> currencyCode;
  final Value<int> initialBalance;
  final Value<bool> isArchived;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> version;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const AccountsTableCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.initialBalance = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsTableCompanion.insert({
    required String id,
    required String ownerId,
    required String name,
    required String type,
    required String currencyCode,
    required int initialBalance,
    required bool isArchived,
    required int createdAt,
    required int updatedAt,
    required int version,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       name = Value(name),
       type = Value(type),
       currencyCode = Value(currencyCode),
       initialBalance = Value(initialBalance),
       isArchived = Value(isArchived),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       version = Value(version);
  static Insertable<AccountRow> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? currencyCode,
    Expression<int>? initialBalance,
    Expression<bool>? isArchived,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (initialBalance != null) 'initial_balance': initialBalance,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? name,
    Value<String>? type,
    Value<String>? currencyCode,
    Value<int>? initialBalance,
    Value<bool>? isArchived,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? version,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return AccountsTableCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      type: type ?? this.type,
      currencyCode: currencyCode ?? this.currencyCode,
      initialBalance: initialBalance ?? this.initialBalance,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (initialBalance.present) {
      map['initial_balance'] = Variable<int>(initialBalance.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsTableCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTableTable extends CategoriesTable with TableInfo<$CategoriesTableTable, CategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameKeyMeta = const VerificationMeta(
    'nameKey',
  );
  @override
  late final GeneratedColumn<String> nameKey = GeneratedColumn<String>(
    'name_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorKeyMeta = const VerificationMeta(
    'colorKey',
  );
  @override
  late final GeneratedColumn<String> colorKey = GeneratedColumn<String>(
    'color_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta(
    'isSystem',
  );
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system" IN (0, 1))',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    nameKey,
    name,
    type,
    iconKey,
    colorKey,
    isSystem,
    createdAt,
    updatedAt,
    version,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('name_key')) {
      context.handle(
        _nameKeyMeta,
        nameKey.isAcceptableOrUnknown(data['name_key']!, _nameKeyMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    }
    if (data.containsKey('color_key')) {
      context.handle(
        _colorKeyMeta,
        colorKey.isAcceptableOrUnknown(data['color_key']!, _colorKeyMeta),
      );
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    } else if (isInserting) {
      context.missing(_isSystemMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      nameKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_key'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      ),
      colorKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_key'],
      ),
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $CategoriesTableTable createAlias(String alias) {
    return $CategoriesTableTable(attachedDatabase, alias);
  }
}

class CategoryRow extends DataClass implements Insertable<CategoryRow> {
  /// UUID. For a user-created category it is `GPUuidGenerator.v7`, as everywhere else; for a seeded one it is `v5` over `owner_id|name_key`, so that two
  /// devices belonging to the same user mint the *same* id for "Food" and a pull reconciles them instead of showing the user two of everything. See
  /// `category_seeder.dart`.
  final String id;

  /// `localOwnerId` until W10. Never null — see `core/database/owner_id.dart`.
  final String ownerId;

  /// Translation key for a seeded category (`category.food`), null for one the user created. Never translated text — see the class doc.
  final String? nameKey;

  /// The name the user typed, and the one that wins when both are present. Null on a seeded category nobody has renamed.
  final String? name;

  /// `CategoryType` — `expense` or `income` — stored as plain text and converted by the mapper at T6, not `textEnum<CategoryType>()`. Same reasoning as
  /// `accounts.type`: `textEnum` persists the Dart constant's name, which turns a rename into a silent data migration.
  final String type;

  /// A key into the app's icon set, resolved in presentation — `icon_food`, not a code point. A stored code point is a number that means nothing after the
  /// icon font changes, and Material's identifiers are not stable enough to put in a database.
  final String? iconKey;

  /// A key into the theme's palette, resolved in presentation. Never `#FF5722`: a stored hex is a colour that ignores dark mode and cannot be re-themed.
  final String? colorKey;

  /// True for the rows the seeder wrote. It is not a permission — the user may rename, recolour and soft-delete a system category — it is provenance, and
  /// W6 uses it to offer "restore defaults" and to keep a fresh install's categories out of the "you created these" list.
  final bool isSystem;

  /// Epoch millis, UTC (§6). Written from `GPClock`, never `DateTime.now()`.
  final int createdAt;

  /// Epoch millis, UTC. Half the pull cursor at W12 T2.
  final int updatedAt;

  /// Optimistic-concurrency token (§7). Starts at 1, set from the server's response, never bumped hopefully on the client.
  final int version;

  /// Soft-delete tombstone (golden rule 5). Not indexed, same as `accounts`: a user has tens of categories, and an index nothing needs is one every write
  /// maintains.
  final int? deletedAt;
  const CategoryRow({
    required this.id,
    required this.ownerId,
    this.nameKey,
    this.name,
    required this.type,
    this.iconKey,
    this.colorKey,
    required this.isSystem,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    if (!nullToAbsent || nameKey != null) {
      map['name_key'] = Variable<String>(nameKey);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || iconKey != null) {
      map['icon_key'] = Variable<String>(iconKey);
    }
    if (!nullToAbsent || colorKey != null) {
      map['color_key'] = Variable<String>(colorKey);
    }
    map['is_system'] = Variable<bool>(isSystem);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  CategoriesTableCompanion toCompanion(bool nullToAbsent) {
    return CategoriesTableCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      nameKey: nameKey == null && nullToAbsent ? const Value.absent() : Value(nameKey),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      type: Value(type),
      iconKey: iconKey == null && nullToAbsent ? const Value.absent() : Value(iconKey),
      colorKey: colorKey == null && nullToAbsent ? const Value.absent() : Value(colorKey),
      isSystem: Value(isSystem),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: Value(version),
      deletedAt: deletedAt == null && nullToAbsent ? const Value.absent() : Value(deletedAt),
    );
  }

  factory CategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryRow(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      nameKey: serializer.fromJson<String?>(json['nameKey']),
      name: serializer.fromJson<String?>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      iconKey: serializer.fromJson<String?>(json['iconKey']),
      colorKey: serializer.fromJson<String?>(json['colorKey']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'nameKey': serializer.toJson<String?>(nameKey),
      'name': serializer.toJson<String?>(name),
      'type': serializer.toJson<String>(type),
      'iconKey': serializer.toJson<String?>(iconKey),
      'colorKey': serializer.toJson<String?>(colorKey),
      'isSystem': serializer.toJson<bool>(isSystem),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int>(version),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  CategoryRow copyWith({
    String? id,
    String? ownerId,
    Value<String?> nameKey = const Value.absent(),
    Value<String?> name = const Value.absent(),
    String? type,
    Value<String?> iconKey = const Value.absent(),
    Value<String?> colorKey = const Value.absent(),
    bool? isSystem,
    int? createdAt,
    int? updatedAt,
    int? version,
    Value<int?> deletedAt = const Value.absent(),
  }) => CategoryRow(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    nameKey: nameKey.present ? nameKey.value : this.nameKey,
    name: name.present ? name.value : this.name,
    type: type ?? this.type,
    iconKey: iconKey.present ? iconKey.value : this.iconKey,
    colorKey: colorKey.present ? colorKey.value : this.colorKey,
    isSystem: isSystem ?? this.isSystem,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  CategoryRow copyWithCompanion(CategoriesTableCompanion data) {
    return CategoryRow(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      nameKey: data.nameKey.present ? data.nameKey.value : this.nameKey,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      colorKey: data.colorKey.present ? data.colorKey.value : this.colorKey,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryRow(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('nameKey: $nameKey, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('iconKey: $iconKey, ')
          ..write('colorKey: $colorKey, ')
          ..write('isSystem: $isSystem, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    nameKey,
    name,
    type,
    iconKey,
    colorKey,
    isSystem,
    createdAt,
    updatedAt,
    version,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryRow &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.nameKey == this.nameKey &&
          other.name == this.name &&
          other.type == this.type &&
          other.iconKey == this.iconKey &&
          other.colorKey == this.colorKey &&
          other.isSystem == this.isSystem &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version &&
          other.deletedAt == this.deletedAt);
}

class CategoriesTableCompanion extends UpdateCompanion<CategoryRow> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String?> nameKey;
  final Value<String?> name;
  final Value<String> type;
  final Value<String?> iconKey;
  final Value<String?> colorKey;
  final Value<bool> isSystem;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> version;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const CategoriesTableCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.nameKey = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.colorKey = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesTableCompanion.insert({
    required String id,
    required String ownerId,
    this.nameKey = const Value.absent(),
    this.name = const Value.absent(),
    required String type,
    this.iconKey = const Value.absent(),
    this.colorKey = const Value.absent(),
    required bool isSystem,
    required int createdAt,
    required int updatedAt,
    required int version,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       type = Value(type),
       isSystem = Value(isSystem),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       version = Value(version);
  static Insertable<CategoryRow> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? nameKey,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? iconKey,
    Expression<String>? colorKey,
    Expression<bool>? isSystem,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (nameKey != null) 'name_key': nameKey,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (iconKey != null) 'icon_key': iconKey,
      if (colorKey != null) 'color_key': colorKey,
      if (isSystem != null) 'is_system': isSystem,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String?>? nameKey,
    Value<String?>? name,
    Value<String>? type,
    Value<String?>? iconKey,
    Value<String?>? colorKey,
    Value<bool>? isSystem,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? version,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return CategoriesTableCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      nameKey: nameKey ?? this.nameKey,
      name: name ?? this.name,
      type: type ?? this.type,
      iconKey: iconKey ?? this.iconKey,
      colorKey: colorKey ?? this.colorKey,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (nameKey.present) {
      map['name_key'] = Variable<String>(nameKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (colorKey.present) {
      map['color_key'] = Variable<String>(colorKey.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesTableCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('nameKey: $nameKey, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('iconKey: $iconKey, ')
          ..write('colorKey: $colorKey, ')
          ..write('isSystem: $isSystem, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$GPAppDatabase extends GeneratedDatabase {
  _$GPAppDatabase(QueryExecutor e) : super(e);
  $GPAppDatabaseManager get managers => $GPAppDatabaseManager(this);
  late final $SettingsTableTable settingsTable = $SettingsTableTable(this);
  late final $AccountsTableTable accountsTable = $AccountsTableTable(this);
  late final $CategoriesTableTable categoriesTable = $CategoriesTableTable(
    this,
  );
  late final Index accountsOwnerIdIsArchived = Index(
    'accounts_owner_id_is_archived',
    'CREATE INDEX accounts_owner_id_is_archived ON accounts (owner_id, is_archived)',
  );
  late final Index categoriesOwnerIdType = Index(
    'categories_owner_id_type',
    'CREATE INDEX categories_owner_id_type ON categories (owner_id, type)',
  );
  late final Index categoriesOwnerIdNameKey = Index(
    'categories_owner_id_name_key',
    'CREATE UNIQUE INDEX categories_owner_id_name_key ON categories (owner_id, name_key)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settingsTable,
    accountsTable,
    categoriesTable,
    accountsOwnerIdIsArchived,
    categoriesOwnerIdType,
    categoriesOwnerIdNameKey,
  ];
}

typedef $$SettingsTableTableCreateCompanionBuilder =
    SettingsTableCompanion Function({
      required String key,
      required String value,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SettingsTableTableUpdateCompanionBuilder =
    SettingsTableCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SettingsTableTableFilterComposer extends Composer<_$GPAppDatabase, $SettingsTableTable> {
  $$SettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableTableOrderingComposer extends Composer<_$GPAppDatabase, $SettingsTableTable> {
  $$SettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableTableAnnotationComposer extends Composer<_$GPAppDatabase, $SettingsTableTable> {
  $$SettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SettingsTableTableTableManager
    extends
        RootTableManager<
          _$GPAppDatabase,
          $SettingsTableTable,
          SettingRow,
          $$SettingsTableTableFilterComposer,
          $$SettingsTableTableOrderingComposer,
          $$SettingsTableTableAnnotationComposer,
          $$SettingsTableTableCreateCompanionBuilder,
          $$SettingsTableTableUpdateCompanionBuilder,
          (SettingRow, BaseReferences<_$GPAppDatabase, $SettingsTableTable, SettingRow>),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableTableManager(
    _$GPAppDatabase db,
    $SettingsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$SettingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsTableCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SettingsTableCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$GPAppDatabase,
      $SettingsTableTable,
      SettingRow,
      $$SettingsTableTableFilterComposer,
      $$SettingsTableTableOrderingComposer,
      $$SettingsTableTableAnnotationComposer,
      $$SettingsTableTableCreateCompanionBuilder,
      $$SettingsTableTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$GPAppDatabase, $SettingsTableTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$AccountsTableTableCreateCompanionBuilder =
    AccountsTableCompanion Function({
      required String id,
      required String ownerId,
      required String name,
      required String type,
      required String currencyCode,
      required int initialBalance,
      required bool isArchived,
      required int createdAt,
      required int updatedAt,
      required int version,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$AccountsTableTableUpdateCompanionBuilder =
    AccountsTableCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> name,
      Value<String> type,
      Value<String> currencyCode,
      Value<int> initialBalance,
      Value<bool> isArchived,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> version,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$AccountsTableTableFilterComposer extends Composer<_$GPAppDatabase, $AccountsTableTable> {
  $$AccountsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get initialBalance => $composableBuilder(
    column: $table.initialBalance,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountsTableTableOrderingComposer extends Composer<_$GPAppDatabase, $AccountsTableTable> {
  $$AccountsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get initialBalance => $composableBuilder(
    column: $table.initialBalance,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableTableAnnotationComposer extends Composer<_$GPAppDatabase, $AccountsTableTable> {
  $$AccountsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId => $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type => $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get initialBalance => $composableBuilder(
    column: $table.initialBalance,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version => $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get deletedAt => $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$AccountsTableTableTableManager
    extends
        RootTableManager<
          _$GPAppDatabase,
          $AccountsTableTable,
          AccountRow,
          $$AccountsTableTableFilterComposer,
          $$AccountsTableTableOrderingComposer,
          $$AccountsTableTableAnnotationComposer,
          $$AccountsTableTableCreateCompanionBuilder,
          $$AccountsTableTableUpdateCompanionBuilder,
          (AccountRow, BaseReferences<_$GPAppDatabase, $AccountsTableTable, AccountRow>),
          AccountRow,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableTableManager(
    _$GPAppDatabase db,
    $AccountsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AccountsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AccountsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$AccountsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<int> initialBalance = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsTableCompanion(
                id: id,
                ownerId: ownerId,
                name: name,
                type: type,
                currencyCode: currencyCode,
                initialBalance: initialBalance,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                required String name,
                required String type,
                required String currencyCode,
                required int initialBalance,
                required bool isArchived,
                required int createdAt,
                required int updatedAt,
                required int version,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsTableCompanion.insert(
                id: id,
                ownerId: ownerId,
                name: name,
                type: type,
                currencyCode: currencyCode,
                initialBalance: initialBalance,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$GPAppDatabase,
      $AccountsTableTable,
      AccountRow,
      $$AccountsTableTableFilterComposer,
      $$AccountsTableTableOrderingComposer,
      $$AccountsTableTableAnnotationComposer,
      $$AccountsTableTableCreateCompanionBuilder,
      $$AccountsTableTableUpdateCompanionBuilder,
      (AccountRow, BaseReferences<_$GPAppDatabase, $AccountsTableTable, AccountRow>),
      AccountRow,
      PrefetchHooks Function()
    >;
typedef $$CategoriesTableTableCreateCompanionBuilder =
    CategoriesTableCompanion Function({
      required String id,
      required String ownerId,
      Value<String?> nameKey,
      Value<String?> name,
      required String type,
      Value<String?> iconKey,
      Value<String?> colorKey,
      required bool isSystem,
      required int createdAt,
      required int updatedAt,
      required int version,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$CategoriesTableTableUpdateCompanionBuilder =
    CategoriesTableCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String?> nameKey,
      Value<String?> name,
      Value<String> type,
      Value<String?> iconKey,
      Value<String?> colorKey,
      Value<bool> isSystem,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> version,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$CategoriesTableTableFilterComposer extends Composer<_$GPAppDatabase, $CategoriesTableTable> {
  $$CategoriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorKey => $composableBuilder(
    column: $table.colorKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableTableOrderingComposer extends Composer<_$GPAppDatabase, $CategoriesTableTable> {
  $$CategoriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorKey => $composableBuilder(
    column: $table.colorKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableTableAnnotationComposer extends Composer<_$GPAppDatabase, $CategoriesTableTable> {
  $$CategoriesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId => $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get nameKey => $composableBuilder(column: $table.nameKey, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type => $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get iconKey => $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<String> get colorKey => $composableBuilder(column: $table.colorKey, builder: (column) => column);

  GeneratedColumn<bool> get isSystem => $composableBuilder(column: $table.isSystem, builder: (column) => column);

  GeneratedColumn<int> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version => $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get deletedAt => $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$CategoriesTableTableTableManager
    extends
        RootTableManager<
          _$GPAppDatabase,
          $CategoriesTableTable,
          CategoryRow,
          $$CategoriesTableTableFilterComposer,
          $$CategoriesTableTableOrderingComposer,
          $$CategoriesTableTableAnnotationComposer,
          $$CategoriesTableTableCreateCompanionBuilder,
          $$CategoriesTableTableUpdateCompanionBuilder,
          (CategoryRow, BaseReferences<_$GPAppDatabase, $CategoriesTableTable, CategoryRow>),
          CategoryRow,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableTableManager(
    _$GPAppDatabase db,
    $CategoriesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$CategoriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$CategoriesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$CategoriesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String?> nameKey = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> iconKey = const Value.absent(),
                Value<String?> colorKey = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesTableCompanion(
                id: id,
                ownerId: ownerId,
                nameKey: nameKey,
                name: name,
                type: type,
                iconKey: iconKey,
                colorKey: colorKey,
                isSystem: isSystem,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ownerId,
                Value<String?> nameKey = const Value.absent(),
                Value<String?> name = const Value.absent(),
                required String type,
                Value<String?> iconKey = const Value.absent(),
                Value<String?> colorKey = const Value.absent(),
                required bool isSystem,
                required int createdAt,
                required int updatedAt,
                required int version,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesTableCompanion.insert(
                id: id,
                ownerId: ownerId,
                nameKey: nameKey,
                name: name,
                type: type,
                iconKey: iconKey,
                colorKey: colorKey,
                isSystem: isSystem,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0.map((e) => (e.readTable(table), BaseReferences(db, table, e))).toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$GPAppDatabase,
      $CategoriesTableTable,
      CategoryRow,
      $$CategoriesTableTableFilterComposer,
      $$CategoriesTableTableOrderingComposer,
      $$CategoriesTableTableAnnotationComposer,
      $$CategoriesTableTableCreateCompanionBuilder,
      $$CategoriesTableTableUpdateCompanionBuilder,
      (CategoryRow, BaseReferences<_$GPAppDatabase, $CategoriesTableTable, CategoryRow>),
      CategoryRow,
      PrefetchHooks Function()
    >;

class $GPAppDatabaseManager {
  final _$GPAppDatabase _db;
  $GPAppDatabaseManager(this._db);
  $$SettingsTableTableTableManager get settingsTable => $$SettingsTableTableTableManager(_db, _db.settingsTable);
  $$AccountsTableTableTableManager get accountsTable => $$AccountsTableTableTableManager(_db, _db.accountsTable);
  $$CategoriesTableTableTableManager get categoriesTable => $$CategoriesTableTableTableManager(_db, _db.categoriesTable);
}
