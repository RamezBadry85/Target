import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';
import 'customer_database.dart';

Future<Database> openLocalCustomerDatabase() =>
    openCustomerDatabase(databaseFactoryWeb, 'target-customers');
