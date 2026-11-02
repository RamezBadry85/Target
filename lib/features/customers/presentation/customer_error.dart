import '../domain/customer_validation.dart';
import 'customer_strings.dart';

String customerError(Object error,CustomerStrings s) {
  if(error is! CustomerException) return s.error;
  return switch(error.problem) {
    CustomerProblem.duplicate => s.t('يوجد عميل بنفس الاسم والموقع أو الهاتف أو البريد، بما في ذلك الأرشيف. راجع السجل قبل الإضافة.','A matching name/location, phone or email exists, including archived records. Review before adding.'),
    CustomerProblem.staleEdit => s.t('تم تعديل العميل في نافذة أخرى. احتفظ بنسخة من تعديلاتك ثم أغلق النموذج وأعد فتحه.','This customer changed in another window. Preserve your edits, then close and reopen the form.'),
    CustomerProblem.validation => s.t('راجع الحقول المطلوبة وصيغ البيانات.','Review required fields and data formats.'),
    CustomerProblem.invalidBackup => s.t('النسخة غير صالحة أو مساحة العمل ليست فارغة. لم يتم استبدال بياناتك.','Invalid backup or workspace is not empty. Your data was not replaced.'),
    CustomerProblem.conflict => s.t('تعارض بيانات: تم الاحتفاظ بالنسختين. يلزم حل التعارض قبل المزامنة.','Data conflict: both versions are retained. Resolve before synchronization.'),
    _ => s.error,
  };
}
