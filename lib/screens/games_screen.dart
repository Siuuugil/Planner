import 'package:flutter/material.dart';

import '../data/store_scope.dart';
import '../widgets/game_widgets.dart';
import 'game_detail_screen.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('게임 스펙업')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showGameEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('게임 추가'),
      ),
      body: store.games.isEmpty
          ? Center(
              child: Text(
                '하고 있는 게임을 추가해 보세요',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
              children: [
                for (final g in store.games)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(g.colorValue),
                        foregroundColor: Colors.white,
                        child: Text(g.name.characters.first),
                      ),
                      title: Text(g.name),
                      subtitle: Text(
                        '숙제 ${g.chores.where((c) => g.isChoreDone(c, now)).length}/${g.chores.length}'
                        ' · 목표 ${g.goals.where((x) => x.achieved).length}/${g.goals.length} 달성',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GameDetailScreen(gameId: g.id),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
