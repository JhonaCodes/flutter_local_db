import 'dart:io';

import 'package:flutter_local_db/flutter_local_db.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/native.dart';

/// `LocalDB.sync` on the native engine: a write to a synchronized table
/// records its change in the same commit, and the sync operations settle it.
void main() {
  late Directory directory;
  late DbTable<Note> notes;

  setUp(() async {
    directory = await TestHost.temporaryDirectory('local_db_sync');
    notes = DbTable<Note>(
      'notes',
      key: 'id',
      fromJson: Note.fromJson,
      syncWith: 'primary',
    );
  });

  tearDown(() async {
    await LocalDB.close();
    await directory.delete(recursive: true);
  });

  test('a write is pending until the server acknowledges it', () async {
    expect(await LocalDB.init(path: '${directory.path}/app'), isA<Ok>());

    expect(await notes.insert([const Note('n1', 'Draft')]), isA<Ok>());

    final batch = (await LocalDB.sync.claim(
      'primary',
    )).when(ok: (claimed) => claimed, err: (error) => fail('claim: $error'));
    expect(batch.envelopes.single.row, {'id': 'n1', 'title': 'Draft'});
    final settled = await LocalDB.sync.applyPushResult(
      'primary',
      PushResult(
        leaseId: batch.leaseId,
        acknowledged: [SyncAcknowledgement.of(batch.envelopes.single, 'v1')],
      ),
    );
    expect(settled, isA<Ok>());

    final state = (await LocalDB.sync.stateOf(notes, 'n1')).when(
      ok: (state) => state ?? fail('no state'),
      err: (error) => fail('state: $error'),
    );
    expect(state.state, SyncStateKind.synced);
    expect(state.serverVersion, 'v1');
  });

  test('before init, sync answers notOpen', () async {
    final status = await LocalDB.sync.status('primary');

    expect(
      status.when(ok: (_) => null, err: (error) => error.code),
      DbErrorCode.notOpen,
    );
  });
}

/// A note.
final class Note {
  const Note(this.id, this.title);

  factory Note.fromJson(Map<String, Object?> json) =>
      Note(json['id']! as String, json['title']! as String);

  final String id;
  final String title;

  Map<String, Object?> toJson() => {'id': id, 'title': title};
}
