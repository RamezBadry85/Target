import 'package:flutter/material.dart';
import '../domain/customer.dart';

class CustomerStrings {
  CustomerStrings(BuildContext context):arabic=Localizations.localeOf(context).languageCode=='ar';
  final bool arabic;
  String t(String ar,String en)=>arabic ? ar : en;
  String type(CustomerType type)=>t(['مستشفى','عيادة','مركز طبي','جامعة','جهة صحية حكومية','جهة صحية خاصة','موزع','منظمة أخرى'][type.index],['Hospital','Clinic','Medical center','University','Government healthcare','Private healthcare','Distributor','Other organization'][type.index]);
  String status(CustomerStatus status)=>t(['محتمل','نشط','غير نشط'][status.index],['Prospect','Active','Inactive'][status.index]);
  String sync(CustomerSyncStatus status)=>t(['محفوظ محلياً','محفوظ محلياً · بانتظار المزامنة','تمت المزامنة','خطأ في المزامنة','تعارض · يلزم التدخل'][status.index],['Saved locally','Saved locally · Pending synchronization','Synchronized','Synchronization error','Conflict · Review required'][status.index]);
  String activity(ActivityType type)=>t(['زيارة','مكالمة هاتفية','اجتماع','متابعة','عرض سعر','عملية بيع','تحصيل','ملاحظة عامة'][type.index],['Visit','Phone call','Meeting','Follow-up','Quotation','Sale','Collection','General note'][type.index]);
  String get cloudNotice=>t('البيانات محفوظة على هذا الجهاز فقط. لم يتم إعداد مزامنة سحابية. احتفظ بنسخة احتياطية؛ قد يمسح المتصفح بيانات الموقع.','Data is stored on this device only. Cloud sync is not configured. Keep a backup; browsers can clear site storage.');
  String get save=>t('حفظ محلياً','Save locally');
  String get cancel=>t('إلغاء','Cancel');
  String get required=>t('هذا الحقل مطلوب','This field is required');
  String get error=>t('تعذر إكمال العملية. لم يتم تأكيد الحفظ. حاول مجدداً.','Operation failed. Saving was not confirmed. Please retry.');
  String label(String key)=>t(_ar[key] ?? key,_en[key] ?? key);
  static const _ar={'name':'اسم العميل / المؤسسة','contactName':'اسم جهة الاتصال','phone':'رقم الهاتف','alternativePhone':'هاتف بديل','email':'البريد الإلكتروني','address':'العنوان','governorate':'المحافظة','city':'المدينة','area':'المنطقة','classification':'التصنيف','businessSector':'قطاع الأعمال','representative':'معرف المندوب (اختياري)','currency':'العملة (رمز ISO)','potential':'القيمة المحتملة','credit':'الحد الائتماني (اختياري)','notes':'ملاحظات','type':'نوع العميل','status':'الحالة'};
  static const _en={'name':'Customer / organization name','contactName':'Contact person','phone':'Phone number','alternativePhone':'Alternative phone','email':'Email','address':'Address','governorate':'Governorate','city':'City','area':'Area','classification':'Classification','businessSector':'Business sector','representative':'Representative ID (optional)','currency':'Currency (ISO code)','potential':'Potential value','credit':'Credit limit (optional)','notes':'Notes','type':'Customer type','status':'Status'};
}
