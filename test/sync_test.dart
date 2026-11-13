import 'package:flutter_test/flutter_test.dart';
import 'package:game_planner/data/app_store.dart';
import 'package:game_planner/data/sync_row.dart';
import 'package:game_planner/models/game.dart';
import 'package:game_planner/models/schedule.dart';
import 'package:game_planner/models/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late SharedPreferences prefs;

  Future<AppStore> open() async =>
      AppStore(prefs, clock: () => now);

  setUp(() async {
    now = DateTime.utc(2026, 10, 28, 12);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Schedule sched(String id, String title) =>
      Schedule(id: id, title: title, start: DateTime(2026, 10, 28, 20));

  test('로컬 변경은 대기열에 쌓이고, 다시 열어도 유지된다', () async {
    final store = await open();
    store.upsertSchedule(sched('a', '레이드'));
    expect(store.pending.keys, ['a']);

    final reopened = await open();
    expect(reopened.schedules.single.title, '레이드');
    expect(reopened.pending.keys, ['a']);
  });

  test('바뀌지 않은 commit은 대기열에 넣지 않는다', () async {
    final store = await open();
    store.upsertSchedule(sched('a', '레이드'));
    store.markPushed(store.pending.values.toList());
    store.commit();
    expect(store.pending, isEmpty);
  });

  test('삭제는 tombstone으로 올라간다', () async {
    final store = await open();
    store.upsertSchedule(sched('a', '레이드'));
    store.markPushed(store.pending.values.toList());
    store.deleteSchedule(store.schedules.single);
    expect(store.pending['a']!.deleted, isTrue);
    expect(store.pending['a']!.kind, 'schedule');
  });

  test('서버가 더 최신이면 반영, 오래됐으면 무시', () async {
    final store = await open();
    store.upsertSchedule(sched('a', '로컬'));

    store.applyRemote([
      SyncRow(
        id: 'a',
        kind: 'schedule',
        data: sched('a', '옛날').toJson(),
        deleted: false,
        updatedAt: now.subtract(const Duration(minutes: 1)),
      ),
    ]);
    expect(store.schedules.single.title, '로컬');
    expect(store.pending, contains('a'));

    store.applyRemote([
      SyncRow(
        id: 'a',
        kind: 'schedule',
        data: sched('a', 'PC에서 수정').toJson(),
        deleted: false,
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
    ]);
    expect(store.schedules.single.title, 'PC에서 수정');
    expect(store.pending, isEmpty);
  });

  test('서버에서 받은 데이터는 키 순서가 달라도 다시 올리지 않는다', () async {
    final store = await open();
    final game = Game(id: 'g', name: '로아', chores: [
      Chore(id: 'c', title: '카던', period: ChorePeriod.daily),
    ]);
    // jsonb처럼 키 순서가 뒤섞인 데이터
    final shuffled = Map.fromEntries(game.toJson().entries.toList().reversed);
    store.applyRemote([
      SyncRow(id: 'g', kind: 'game', data: shuffled, deleted: false, updatedAt: now),
    ]);
    store.commit();
    expect(store.games.single.name, '로아');
    expect(store.pending, isEmpty);
  });

  test('서버 삭제 반영', () async {
    final store = await open();
    store.upsertGame(Game(id: 'g', name: '메이플'));
    store.markPushed(store.pending.values.toList());
    store.applyRemote([
      SyncRow(
        id: 'g',
        kind: 'game',
        data: null,
        deleted: true,
        updatedAt: now.add(const Duration(seconds: 1)),
      ),
    ]);
    expect(store.games, isEmpty);
    store.commit();
    expect(store.pending, isEmpty);
  });

  test('할 일도 동기화되고, 모르는 종류는 무시한다', () async {
    final store = await open();
    store.upsertTask(Task(id: 't', title: '보고서', category: TaskCategory.work));
    expect(store.pending['t']!.kind, 'task');

    store.applyRemote([
      SyncRow(
        id: 't',
        kind: 'task',
        data: Task(id: 't', title: '보고서 제출', category: TaskCategory.work, done: true).toJson(),
        deleted: false,
        updatedAt: now.add(const Duration(minutes: 1)),
      ),
      SyncRow(id: 'x', kind: 'future_kind', data: {'a': 1}, deleted: false, updatedAt: now),
    ]);
    expect(store.tasks.single.title, '보고서 제출');
    expect(store.tasks.single.done, isTrue);
    expect(store.schedules, isEmpty);
    expect(store.games, isEmpty);
  });

  test('동기화 도입 전 데이터는 처음 열 때 전부 올릴 대상이 된다', () async {
    SharedPreferences.setMockInitialValues({
      'app_data_v1': '{"schedules":[{"id":"old","title":"기존","start":"2026-10-01T10:00:00.000"}],"games":[]}',
    });
    prefs = await SharedPreferences.getInstance();
    final store = await open();
    expect(store.pending.keys, ['old']);
  });

  test('두 기기에서 서로 다른 숙제를 체크해도 둘 다 남는다 (완료 기록 분리)', () async {
    // 기기 A
    SharedPreferences.setMockInitialValues({});
    final a = AppStore(await SharedPreferences.getInstance(), clock: () => now);
    a.games.add(Game(id: 'g', name: '메이플', resetHour: 0, chores: [
      Chore(id: 'c1', title: '몬파', period: ChorePeriod.daily),
      Chore(id: 'c2', title: '우르스', period: ChorePeriod.daily),
    ]));
    a.commit();
    final gameRow = a.pending['g']!;

    // 기기 B: 같은 게임을 받은 상태
    SharedPreferences.setMockInitialValues({});
    final b = AppStore(await SharedPreferences.getInstance(), clock: () => now);
    b.applyRemote([gameRow]);
    a.markPushed(a.pending.values.toList());

    // A는 c1, B는 c2를 체크
    a.toggleChore(a.games.single, a.games.single.chores[0]);
    b.toggleChore(b.games.single, b.games.single.chores[1]);
    // 게임 레코드는 바뀌지 않고 완료 기록만 올라간다
    expect(a.pending.keys, ['done:c1']);
    expect(b.pending.keys, ['done:c2']);

    // 서로 받기
    a.applyRemote(b.pending.values);
    b.applyRemote(a.pending.values);
    for (final s in [a, b]) {
      final g = s.games.single;
      expect(g.chores.every((c) => g.isChoreDone(c, now)), isTrue);
    }
  });

  test('예전 데이터의 완료 상태(lastDone)는 완료 기록으로 옮겨진다', () async {
    SharedPreferences.setMockInitialValues({
      'app_data_v1': '{"schedules":[],"games":[{"id":"g","name":"메이플","resetHour":0,'
          '"chores":[{"id":"c","title":"몬파","period":"daily","lastDone":"${now.toLocal().toIso8601String()}"}]}]}',
    });
    final s = AppStore(await SharedPreferences.getInstance(), clock: () => now);
    expect(s.marks.keys, ['done:c']);
    expect(s.games.single.isChoreDone(s.games.single.chores.single, now), isTrue);
    expect(s.pending.keys, containsAll(['g', 'done:c']));
  });
}
