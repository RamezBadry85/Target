import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../files/document_files.dart';
import '../backup_document.dart';
import '../backup_service.dart';
import '../../../features/customers/domain/customer_repository.dart';
import '../../../features/customers/data/local_customer_repository.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key,required this.openModule});
  final Future<CustomerModule> Function() openModule;
  @override
  State<BackupPage> createState()=>_BackupPageState();
}
class _BackupPageState extends State<BackupPage> {
  bool _busy=false;
  String? _message;
  bool get ar=>Localizations.localeOf(context).languageCode=='ar';
  String t(String a,String e)=>ar?a:e;
  Future<void> _run(bool restore) async {
    setState(() { _busy=true; _message=null; });
    try {
      final repository=(await widget.openModule()).repository;
      if(repository is! LocalCustomerRepository) throw StateError('Unsupported repository');
      final service=BackupService(repository);
      if(!restore) {
        final document=await service.create();
        final bytes=document.encode();
        final name=BackupDocument.filename(document.createdAt);
        if(!await DocumentFiles.save(bytes,name,'json')) { if(mounted) setState(()=>_message=t('تم إلغاء الحفظ','Save cancelled')); return; }
        if(mounted) setState(()=>_message='$name.json\n${document.createdAt.toIso8601String()} · ${bytes.length} bytes\n${t("تم الحفظ. الملف غير مشفر؛ احفظه في مكان آمن.","Saved. Backup is unencrypted; store it securely.")}');
      } else {
        final bytes=await DocumentFiles.pickBackup();
        if(bytes==null)return;
        final document=BackupDocument.decode(bytes);
        if(!mounted)return;
        final choice=await showDialog<String>(context:context,barrierDismissible:false,builder:(context)=>AlertDialog(
          title:Text(t('مراجعة الاستعادة','Review restore')),
          content:SingleChildScrollView(child:Text('${document.createdAt.toIso8601String()}\n${document.counts}\n${bytes.length} bytes\n${t("تم التحقق من البصمة والإصدار. الاستبدال يغيّر البيانات الحالية ويتطلب حفظ نسخة أمان أولاً. لا يوجد دمج. سيتم تطبيق إعداد اللغة عند إعادة التشغيل.","Checksum and version verified. Replacement changes existing data and requires saving a safety backup first. No merge. Language setting applies on restart.")}')),
          actions:[TextButton(onPressed:()=>Navigator.pop(context),child:Text(t('إلغاء','Cancel'))),
            OutlinedButton(onPressed:()=>Navigator.pop(context,'empty'),child:Text(t('قاعدة فارغة فقط','Empty database only'))),
            if(!kIsWeb) FilledButton(onPressed:()=>Navigator.pop(context,'replace'),child:Text(t('أوافق على الاستبدال بعد نسخة الأمان','Confirm replace after safety backup'))),
          ],
        ));
        if(choice==null)return;
        await service.restore(bytes,replaceConfirmed:choice=='replace',saveSafetyBackup:(data,name)=>DocumentFiles.save(data,name,'json'));
        if(mounted)setState(()=>_message=t('تمت الاستعادة بنجاح. أعد تشغيل التطبيق لتطبيق إعداد اللغة.','Restore completed. Restart to apply the language setting.'));
      }
    } catch(error) { if(mounted)setState(()=>_message='${t("تعذر إكمال العملية","Operation failed")}: $error'); }
    finally { if(mounted)setState(()=>_busy=false); }
  }
  @override
  Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Text(t('إدارة النسخ الاحتياطية','Backup management'),style:Theme.of(context).textTheme.headlineSmall),
    Text(t('نسخة محمولة للعملاء وجهات الاتصال والأنشطة والأرشيف والمزامنة المحلية وإعداد اللغة. لا تتضمن أسراراً أو ملفات مؤقتة. الملفات غير مشفرة.','Portable customer, contact, activity, archive, local sync and language backup. No secrets or temporary files. Files are unencrypted.')),
    const SizedBox(height:16),
    Wrap(spacing:12,runSpacing:12,children:[FilledButton.icon(onPressed:_busy?null:()=>_run(false),icon:const Icon(Icons.save_alt),label:Text(t('إنشاء نسخة واختيار مكان الحفظ','Create backup and choose location'))),OutlinedButton.icon(onPressed:_busy?null:()=>_run(true),icon:const Icon(Icons.restore),label:Text(t('استعادة نسخة','Restore backup')))]),
    if(_busy)const LinearProgressIndicator(),
    if(_message!=null)SelectableText(_message!),
    Text(t('احفظ نسخة الأمان في مكان مستقل. الاستعادة تتحقق من الملف قبل أي تغيير وتتم في معاملة واحدة. لا نحذف النسخ أو البيانات تلقائياً.','Keep the safety backup separately. Validation precedes changes; restore commits in one transaction. No automatic deletion of backups or data.')),
  ]);
}
