/// Error codes of the native engine (stable across versions), plus the
/// errors raised on the Dart side.
enum LocalDbErrorCode {
  /// The statement names a table that is not defined.
  tableNotFound('TableNotFound'),

  /// A table definition is invalid.
  invalidSchema('InvalidSchema'),

  /// A table is already defined with another primary key.
  schemaMismatch('SchemaMismatch'),

  /// An insert used a primary key that already exists.
  duplicateKey('DuplicateKey'),

  /// A write would duplicate a value of a unique index.
  uniqueViolation('UniqueViolation'),

  /// A row has no primary key and the table does not generate one.
  missingPrimaryKey('MissingPrimaryKey'),

  /// The request is malformed.
  invalidRequest('InvalidRequest'),

  /// A write did not affect the number of rows it expected.
  affectedRowsMismatch('AffectedRowsMismatch'),

  /// A stored row cannot be decoded.
  corruptRecord('CorruptRecord'),

  /// An indexed value is too large for an LMDB key.
  keyTooLarge('KeyTooLarge'),

  /// The database reached its maximum size (`LocalDbOptions.maxMapSize`).
  mapFull('MapFull'),

  /// The database was written by flutter_local_db 1.x (LMDB 0.9).
  legacyFormat('LegacyFormat'),

  /// LMDB reported an error.
  storage('StorageError'),

  /// A file system operation failed.
  io('IoError'),

  /// The transaction was already committed, rolled back or expired.
  transactionClosed('TransactionClosed'),

  /// A write failed in this transaction, which can only be rolled back.
  transactionAborted('TransactionAborted'),

  /// The transaction was rolled back after staying idle too long.
  transactionExpired('TransactionExpired'),

  /// A write was sent to a read-only transaction.
  readOnlyTransaction('ReadOnlyTransaction'),

  /// A savepoint was released or rolled back while none was open.
  noSavepoint('NoSavepoint'),

  /// The transaction was committed while a savepoint was open.
  savepointOpen('SavepointOpen'),

  /// The database was used directly inside one of its own transactions (use
  /// the transaction instead).
  transactionReentrancy('TransactionReentrancy'),

  /// The transaction does not belong to this database.
  unknownTransaction('UnknownTransaction'),

  /// The directory is already open by another engine of this process.
  alreadyOpen('AlreadyOpen'),

  /// The database is closed.
  closed('Closed'),

  /// The native library speaks another protocol version.
  unsupportedProtocol('UnsupportedProtocol'),

  /// The native library panicked (the panic was contained).
  internalPanic('InternalPanic'),

  /// The query API needs the native engine, which this platform (web) lacks.
  unsupportedPlatform('UnsupportedPlatform'),

  /// The native library could not be loaded or called.
  nativeLibrary('NativeLibrary'),

  /// A code this version does not know.
  unknown('');

  const LocalDbErrorCode(this.wire);

  /// The code sent by the native engine.
  final String wire;

  /// The code for a wire [code].
  static LocalDbErrorCode fromWire(String code) => values.firstWhere(
    (value) => value.wire == code && value != unknown,
    orElse: () => unknown,
  );
}

/// An error of the query API ([LocalDatabase]).
final class LocalDbException implements Exception {
  /// An error with [code] and a human readable [message].
  const LocalDbException(this.code, this.message, {String? wireCode})
    : wireCode = wireCode ?? '';

  /// What failed; stable across versions.
  final LocalDbErrorCode code;

  /// Description for humans; may change between versions.
  final String message;

  /// The raw code sent by the native engine (useful for [LocalDbErrorCode.unknown]).
  final String wireCode;

  @override
  String toString() => 'LocalDbException(${code.name}): $message';
}
