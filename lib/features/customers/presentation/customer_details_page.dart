import 'package:flutter/material.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';
import '../domain/customer_validation.dart';
import 'customer_strings.dart';
import 'customer_error.dart';
import 'customer_form_page.dart';
import 'customer_activity_page.dart';

class CustomerDetailsPage extends StatelessWidget {
  const CustomerDetailsPage({super.key,required this.repository,required this.customerId});
  final CustomerRepository repository;
  final String customerId;
  Future<void> _archive(BuildContext context,Customer c) async {
    final s=CustomerStrings(context);
    final confirm=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:Text(c.archived ? s.t('استعادة العميل؟','Restore customer?') : s.t('أرشفة العميل؟','Archive customer?')),content:Text(s.t('لن يتم حذف البيانات. يمكن استعادة العميل من الأرشيف.','Data will not be deleted. Archived customers can be restored.')),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:Text(s.cancel)),FilledButton(onPressed:()=>Navigator.pop(context,true),child:Text(s.t('تأكيد','Confirm')))]));
    if(confirm!=true) return;
    try { await repository.setArchived(c.id,c.revision,!c.archived); }
    catch(error){if(context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(customerError(error,s))));}
  }
  @override
  Widget build(BuildContext context){ final s=CustomerStrings(context);
    return Scaffold(appBar:AppBar(title:Text(s.t('ملف العميل','Customer profile'))),body:StreamBuilder<List<Customer>>(stream:repository.watchAll(),builder:(context,snapshot){
      if(snapshot.hasError) return Center(child:Text(s.error));
      if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
      final c=snapshot.data!.where((c)=>c.id==customerId).firstOrNull;
      if(c==null) return Center(child:Text(s.t('العميل غير موجود','Customer not found')));
      final d=c.data;
      final fields={s.t('معرف العميل','Customer ID'):c.id,s.label('type'):s.type(d.type),s.label('status'):s.status(d.status),
        s.label('address'):d.address,s.label('governorate'):d.governorate,s.label('city'):d.city,s.label('area'):d.area,
        s.label('classification'):d.classification,s.label('businessSector'):d.businessSector,s.label('representative'):d.assignedRepresentativeId,
        s.label('potential'):'${CustomerValidation.money(d.potentialMinor)} ${d.currency}',s.label('credit'):d.creditLimitMinor==null ? '—' : '${CustomerValidation.money(d.creditLimitMinor!)} ${d.currency}',
        s.t('تاريخ الإنشاء','Created'):c.createdAt.toLocal().toIso8601String(),s.t('آخر تحديث','Updated'):c.updatedAt.toLocal().toIso8601String(),
        if(c.archivedAt!=null) s.t('تاريخ الأرشفة','Archived'):c.archivedAt!.toLocal().toIso8601String(),s.t('إصدار السجل','Record revision'):'${c.revision}',s.label('notes'):d.notes};
      return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1000),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Text(d.name,style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:12),Text(s.sync(c.syncStatus)),Text(s.cloudNotice),
        if(c.syncStatus==CustomerSyncStatus.conflict) Text(s.t('تم الاحتفاظ بالتغييرات المحلية ونسخة التعارض في قاعدة البيانات. لا يتم استبدالهما تلقائياً.','Local changes and the conflicting snapshot are retained. Neither is automatically overwritten.'),style:TextStyle(color:Theme.of(context).colorScheme.error)),
        const SizedBox(height:16),Wrap(spacing:12,runSpacing:12,children:[
          FilledButton.icon(onPressed:()=>Navigator.push<bool>(context,MaterialPageRoute(builder:(_)=>CustomerFormPage(repository:repository,customer:c))),icon:const Icon(Icons.edit_outlined),label:Text(s.t('تعديل','Edit'))),
          OutlinedButton.icon(onPressed:()=>_archive(context,c),icon:Icon(c.archived ? Icons.unarchive_outlined : Icons.archive_outlined),label:Text(c.archived ? s.t('استعادة','Restore') : s.t('أرشفة','Archive'))),
          OutlinedButton.icon(onPressed:()=>Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>CustomerActivityPage(repository:repository,customerId:c.id))),icon:const Icon(Icons.history),label:Text(s.t('سجل الأنشطة','Activity history'))),
        ]),const SizedBox(height:24),
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[for(final entry in fields.entries) Padding(padding:const EdgeInsets.symmetric(vertical:8),child:LayoutBuilder(builder:(context,box)=>box.maxWidth<500 ? Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(entry.key,style:const TextStyle(fontWeight:FontWeight.bold)),SelectableText(entry.value.isEmpty ? '—' : entry.value)]) : Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:220,child:Text(entry.key,style:const TextStyle(fontWeight:FontWeight.bold))),Expanded(child:SelectableText(entry.value.isEmpty ? '—' : entry.value))])))]))),
        const SizedBox(height:16),Text(s.t('جهات الاتصال','Contacts'),style:Theme.of(context).textTheme.titleLarge),
        for(final contact in d.contacts) Card(margin:const EdgeInsets.symmetric(vertical:8),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[SelectableText(contact.name.isEmpty ? '—' : contact.name),SelectableText('${s.label('phone')}: ${contact.phone}'),if(contact.alternativePhone.isNotEmpty) SelectableText('${s.label('alternativePhone')}: ${contact.alternativePhone}'),if(contact.email.isNotEmpty) SelectableText(contact.email)]))),
      ]))));
    }));
  }
}
