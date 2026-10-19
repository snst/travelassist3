import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<void> deleteDatabaseFile(String name) async {
  final directory = await getApplicationDocumentsDirectory();
  final databasePath = p.join(directory.path, '$name.sqlite');
  for (final suffix in ['', '-journal', '-wal', '-shm']) {
    final file = File('$databasePath$suffix');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
