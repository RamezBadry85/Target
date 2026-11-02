import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/sembast_io.dart';
import 'package:target/features/customers/domain/customer.dart';
import 'package:target/features/customers/domain/customer_validation.dart';
import 'package:target/features/customers/data/customer_codec.dart';
import 'package:target/features/customers/data/customer_database.dart';
import 'package:target/features/customers/data/local_customer_repository.dart';

CustomerDraft draft({String name='مؤسسة الاختبار',String phone='01012345678',String city='القاهرة',String governorate='القاهرة',CustomerType type=CustomerType.clinic,String classification='A',int potential=125050})=>CustomerDraft(name:name,type:type,contacts:[CustomerContact(id:'contact-$phone',name:'جهة الاتصال',phone:phone,email:'')],city:city,governorate:governorate,classification:classification,potentialMinor:potential,notes:'ملاحظات عربية');

void main(){
  late LocalCustomerRepository repo;
  setUp(() async {repo=LocalCustomerRepository(await openCustomerDatabase(newDatabaseFactoryMemory(),'customers.db'));});
  tearDown(() async {await repo.close();});
  test('creation persists validated fields, UTC timestamps and atomic pending change',() async {
    final c=await repo.save(draft());
    expect(c.id,isNotEmpty);expect(c.revision,1);expect(c.createdAt.isUtc,isTrue);expect(c.updatedAt,c.createdAt);
    expect(c.data.name,'مؤسسة الاختبار');expect(c.data.potentialMinor,125050);expect(c.syncStatus,CustomerSyncStatus.pending);
    final changes=await repo.pendingChanges();expect(changes,hasLength(1));expect(changes.single.customerId,c.id);
    expect((changes.single.payload['customer'] as Map<String,Object?>)['id'],c.id);
  });
  test('edit preserves ID/creation and rejects a stale concurrent edit',() async {
    final first=await repo.save(draft());
    final edited=await repo.save(draft(name:'الاسم الجديد'),id:first.id,expectedRevision:first.revision);
    expect(edited.id,first.id);expect(edited.createdAt,first.createdAt);expect(edited.revision,2);
    await expectLater(repo.save(draft(name:'تعديل قديم'),id:first.id,expectedRevision:1),throwsA(isA<CustomerException>().having((e)=>e.problem,'problem',CustomerProblem.staleEdit)));
    expect((await repo.all()).single.data.name,'الاسم الجديد');expect(await repo.pendingChanges(),hasLength(2));
  });
  test('archive is a reversible tombstone, never hard delete',() async {
    final c=await repo.save(draft());final archived=await repo.setArchived(c.id,c.revision,true);
    expect(archived.archived,isTrue);expect(const CustomerQuery().apply(await repo.all()),isEmpty);
    expect(const CustomerQuery(archived:true).apply(await repo.all()),hasLength(1));
    final restored=await repo.setArchived(c.id,archived.revision,false);expect(restored.archived,isFalse);expect(await repo.all(),hasLength(1));expect(await repo.pendingChanges(),hasLength(3));
  });
  test('duplicates by canonical name/location or phone or email include archive',() async {
    final c=await repo.save(draft());
    await expectLater(repo.save(draft(name:'  مؤسسة الاختبار  ',phone:'01199999999')),throwsA(isA<CustomerException>().having((e)=>e.problem,'duplicate',CustomerProblem.duplicate)));
    await repo.setArchived(c.id,c.revision,true);
    await expectLater(repo.save(draft(name:'مختلف')),throwsA(isA<CustomerException>()));
    expect(await repo.all(),hasLength(1));expect(await repo.pendingChanges(),hasLength(2));
  });
  test('concurrent duplicate inserts are serialized in the transaction',() async {
    final attempts=await Future.wait([repo.save(draft()).then<Object>((v)=>v).catchError((Object e)=>e),repo.save(draft()).then<Object>((v)=>v).catchError((Object e)=>e)]);
    expect(attempts.whereType<Customer>(),hasLength(1));expect(attempts.whereType<CustomerException>(),hasLength(1));expect(await repo.pendingChanges(),hasLength(1));
  });
  test('search filters and deterministic sorting operate on real records',() async {
    await repo.save(draft());await repo.save(draft(name:'مستشفى آخر',phone:'01133333333',city:'الجيزة',governorate:'الجيزة',type:CustomerType.hospital,classification:'B',potential:250000));
    final all=await repo.all();
    expect(const CustomerQuery(search:'010123').apply(all),hasLength(1));
    expect(const CustomerQuery(governorate:'الجيزة',city:'الجيزة',type:CustomerType.hospital,classification:'B').apply(all),hasLength(1));
    expect(const CustomerQuery(sort:CustomerSort.potential).apply(all).first.data.potentialMinor,250000);
    expect(const CustomerQuery(search:'غير موجود').apply(all),isEmpty);
  });
  test('notes and activities are chronological and update the durable outbox',() async {
    var c=await repo.save(draft());
    await repo.addActivity(c.id,c.revision,ActivityType.note,'ملاحظة أولى',DateTime.utc(2024));
    c=(await repo.all()).single;
    await repo.addActivity(c.id,c.revision,ActivityType.visit,'زيارة اليوم',DateTime.now());
    final activities=await repo.activities(c.id);expect(activities,hasLength(2));expect(activities.first.type,ActivityType.visit);
    expect((await repo.pendingChanges()).last.payload['activities'],hasLength(2));
  });
  test('invalid activity cannot partially change customer or outbox',() async {
    final c=await repo.save(draft());await expectLater(repo.addActivity(c.id,1,ActivityType.note,'',DateTime.now()),throwsA(isA<CustomerException>()));
    expect(await repo.activities(c.id),isEmpty);expect((await repo.all()).single.revision,1);expect(await repo.pendingChanges(),hasLength(1));
  });
  test('backup recovers customers and activities into an empty workspace',() async {
    final c=await repo.save(draft());await repo.addActivity(c.id,1,ActivityType.note,'ملاحظة محفوظة',DateTime.utc(2024));
    final bytes=await repo.backup();final other=LocalCustomerRepository(await openCustomerDatabase(newDatabaseFactoryMemory(),'restore.db'));
    try{await other.restore(bytes);expect((await other.all()).single.id,c.id);expect((await other.activities(c.id)).single.text,'ملاحظة محفوظة');expect(await other.pendingChanges(),hasLength(1));
      await expectLater(other.restore(bytes),throwsA(isA<CustomerException>()));expect(await other.all(),hasLength(1));
    }finally{await other.close();}
  });
  test('corrupt backup is rejected without partial writes',() async {
    await expectLater(repo.restore(Uint8List.fromList([1,2,3])),throwsA(isA<CustomerException>()));expect(await repo.all(),isEmpty);expect(await repo.pendingChanges(),isEmpty);
  });
  test('data and outbox survive closing and reopening the file database offline',() async {
    final dir=await Directory.systemTemp.createTemp('target-customer-test');final path='${dir.path}/customers.db';
    try{var disk=LocalCustomerRepository(await openCustomerDatabase(databaseFactoryIo,path));final c=await disk.save(draft());await disk.close();
      disk=LocalCustomerRepository(await openCustomerDatabase(databaseFactoryIo,path));expect((await disk.all()).single.id,c.id);expect((await disk.pendingChanges()).single.customerId,c.id);await disk.close();
    }finally{await dir.delete(recursive:true);}
  });
  test('v1 to v2 migration preserves profiles and creates outbox once',() async {
    final factory=newDatabaseFactoryMemory();final old=await factory.openDatabase('v1.db',version:1);
    final c=Customer(id:'legacy-id',data:draft(),createdAt:DateTime.utc(2024),updatedAt:DateTime.utc(2024),revision:1);
    final row=CustomerCodec.customer(c)..remove('revision')..remove('syncStatus')..remove('remoteVersion');
    await customerStore.record(c.id).put(old,row);await old.close();
    var migrated=LocalCustomerRepository(await openCustomerDatabase(factory,'v1.db'));
    expect((await migrated.all()).single.data.name,c.data.name);expect((await migrated.pendingChanges()).single.customerId,c.id);await migrated.close();
    migrated=LocalCustomerRepository(await openCustomerDatabase(factory,'v1.db'));expect(await migrated.pendingChanges(),hasLength(1));await migrated.close();
  });
  test('a newer schema is not silently reset',() async {
    final factory=newDatabaseFactoryMemory();final newer=await factory.openDatabase('future.db',version:99);await newer.close();
    await expectLater(openCustomerDatabase(factory,'future.db'),throwsA(anything));
  });
}
