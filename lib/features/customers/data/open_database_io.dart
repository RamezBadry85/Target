import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'customer_database.dart';

Future<Database> openLocalCustomerDatabase() async {
  final directory = await getApplicationSupportDirectory();
  await directory.create(recursive: true);
  return openCustomerDatabase(
    databaseFactoryIo,
    path.join(directory.path, 'target-customers.db'),
  );
}
