import 'database_helper.dart';
import '../repositories/auth_repository.dart';

class SyncService {
  final AuthRepository authRepository;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  SyncService({required this.authRepository});

  Future<void> sync() async {
    print("---Enter Sync---");
    await push();
    await pull();
  }

  Future<void> push() async {
    print("---Enter push---");
  }

  Future<void> pull() async {
    print("---Enter pull---");
  

    final currentSeq = await _dbHelper.getCurrentDbSequence();
    print("currentSeq: $currentSeq");

    final response = await authRepository.get(
      '/api/sync/',
      queryParameters: {'since': currentSeq},
    );

    final body = response.data as Map<String, dynamic>;
    print("BODY: $body");

    final changes = (body['changes'] as List<dynamic>? ?? []);
    final int newSeq = (body['next_cursor'] as int?) ?? currentSeq;

    for (final dynamic changeRaw in changes) {
      final change = changeRaw as Map<String, dynamic>;
      final String type = change['type'] as String;
      final String op = change['op'] as String;
      final dynamic data = change['data'];
      final String id = change['id'] as String;

      print("Handling change: type=$type, op=$op, id=$id, data=$data");

      // Sicherstellen, dass data ein Map ist
      final Map<String, dynamic>? dataMap =
          data is Map<String, dynamic> ? data : null;

      if (op == 'upsert') {
        await upsert(type, dataMap);
      } else if (op == 'delete') {
        await delete(type, dataMap);
      } else {
        print("Unknown op: $op");
      }
    }

    await _dbHelper.setDbSequence(newSeq);

    final currentSeq2 = await _dbHelper.getCurrentDbSequence();
    print(currentSeq2);
    // print("SYNC: updated dbSequence to $newSeq");
  }

  Future<void> upsert(type, dataMap) async {
    switch (type) {
      case 'user':
        if (dataMap != null) {
          print("upsert user: $dataMap");
          await _dbHelper.upsertUserFromServer(dataMap);
        } else {
          print("WARN: user change ohne dataMap");
        }
        break;
      case 'event':
        if (dataMap != null) {
          await _dbHelper.upsertEventFromServer(dataMap);
        } else {
          print("WARN: event change ohne dataMap");
        }
        break;
      case 'session':
        if (dataMap != null) {
          await _dbHelper.upsertSessionFromServer(dataMap);
        } else {
          print("WARN: session change ohne dataMap");
        }
        break;
      default:
        print("Unknown type: $type");
    }
  }

  Future<void> delete(type, dataMap) async {
    print("---Enter push---");
    // switch (type) {
    //   case 'user':
    //     await _dbHelper.hardDeleteUserFromServer(id);
    //     break;
    //   case 'event':
    //     await _dbHelper.hardDeleteEventFromServer(id);
    //     break;
    //   case 'session':
    //     await _dbHelper.hardDeleteSessionFromServer(id);
    //     break;
    //   default:
    //     print("Unknown type for delete: $type");
    // }
  }
}
