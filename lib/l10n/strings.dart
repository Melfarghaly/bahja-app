import 'package:flutter/widgets.dart';

/// UI strings (Arabic first, English second). Texts that come from the API
/// (errors, summaries, labels) are already in the request language.
class S {
  const S(this.isArabic);

  final bool isArabic;

  static S of(BuildContext context) =>
      S(Localizations.localeOf(context).languageCode == 'ar');

  String _t(String ar, String en) => isArabic ? ar : en;

  // General
  String get appName => _t('بهجة', 'Bahga');
  String get retry => _t('إعادة المحاولة', 'Retry');
  String get cancel => _t('إلغاء', 'Cancel');
  String get save => _t('حفظ', 'Save');
  String get confirm => _t('تأكيد', 'Confirm');
  String get loadMore => _t('تحميل المزيد', 'Load more');
  String get nothingHere => _t('لا يوجد شيء هنا بعد', 'Nothing here yet');
  String get done => _t('تم', 'Done');

  // Auth
  String get welcome => _t('أهلاً بك في بهجة', 'Welcome to Bahga');
  String get welcomeSub => _t(
    'تابع يوم طفلك لحظة بلحظة',
    "Follow your child's day, moment by moment",
  );
  String get loginField => _t('رقم الهاتف أو البريد', 'Phone or email');
  String get password => _t('كلمة المرور', 'Password');
  String get signIn => _t('تسجيل الدخول', 'Sign in');
  String get signInWithSms => _t(
    'الدخول برمز SMS (لأولياء الأمور)',
    'Sign in with an SMS code (parents)',
  );
  String get signInWithPassword =>
      _t('الدخول بكلمة المرور', 'Sign in with password');
  String get phone => _t('رقم الموبايل', 'Mobile number');
  String get sendCode => _t('إرسال الرمز', 'Send code');
  String get code => _t('الرمز المكوّن من 6 أرقام', '6-digit code');
  String get verify => _t('تأكيد ودخول', 'Verify & sign in');
  String resendIn(int s) => _t('إعادة الإرسال بعد $s ث', 'Resend in ${s}s');
  String get resend => _t('إعادة إرسال الرمز', 'Resend code');
  String get chooseNursery => _t('اختر الحضانة', 'Choose a nursery');
  String get noNurseries => _t(
    'حسابك غير مرتبط بأي حضانة بعد. تواصل مع إدارة الحضانة.',
    'Your account is not linked to a nursery yet. Please contact the nursery.',
  );
  String get signOut => _t('تسجيل الخروج', 'Sign out');

  // Navigation
  String get myChildren => _t('أطفالي', 'My children');
  String get attendance => _t('الحضور', 'Attendance');
  String get wall => _t('الحائط', 'Wall');
  String get notifications => _t('الإشعارات', 'Notifications');
  String get invoices => _t('الفواتير', 'Invoices');
  String get account => _t('حسابي', 'Account');

  // Guardian
  String get present => _t('في الحضانة', 'At nursery');
  String get pickedUp => _t('انصرف', 'Picked up');
  String get absent => _t('لم يحضر اليوم', 'Not in today');
  String arrivedAt(String t) => _t('وصل $t', 'Arrived $t');
  String leftAt(String t, String? by) => by == null
      ? _t('انصرف $t', 'Left $t')
      : _t('انصرف $t مع $by', 'Left $t with $by');
  String get pickupCode => _t('كود الاستلام', 'Pickup code');
  String get pickupCodeHint => _t(
    'اعرض هذا الكود على المعلمة عند الباب. يتجدد تلقائياً كل 30 ثانية.',
    'Show this code to the teacher at the door. It refreshes every 30 seconds.',
  );
  String get dailyWall => _t('يوميات اليوم', 'Daily wall');
  String get attendanceHistory => _t('سجل الحضور', 'Attendance history');
  String get pickupPasses => _t('تصاريح الاستلام', 'Pickup passes');
  String get newPass => _t('تصريح جديد', 'New pass');
  String get passName => _t('اسم المستلم', "Collector's name");
  String get passValidHours => _t('صالح لمدة (ساعات)', 'Valid for (hours)');
  String get note => _t('ملاحظة', 'Note');
  String passCodeShown(String code) => _t(
    'كود التصريح: $code\nأُرسل للمستلم في رسالة SMS. لن يظهر مرة أخرى.',
    'Pass code: $code\nIt was sent to the collector by SMS and will not be shown again.',
  );
  String get revoke => _t('إلغاء التصريح', 'Revoke');
  String get settings => _t('الإعدادات', 'Settings');
  String get appNotifications => _t('إشعارات التطبيق', 'App notifications');
  String get smsMessages => _t('الرسائل النصية SMS', 'SMS messages');
  String get photoConsent => _t('إذن التصوير', 'Photo permission');
  String get photoConsentWall =>
      _t('السماح بتصوير طفلي ليومياته', 'Allow photos of my child on the wall');
  String get photoConsentGroup =>
      _t('السماح بظهوره في صور جماعية', 'Allow my child in group photos');
  String get primaryOnly => _t(
    'وليّ الأمر الأساسي فقط يمكنه تغيير إذن التصوير.',
    'Only the primary guardian can change photo permission.',
  );
  String get acknowledge => _t('اطّلعت على التقرير', 'I have read this');
  String get acknowledged => _t('تم الإقرار', 'Acknowledged');
  String get allergies => _t('حساسية', 'Allergies');

  // Billing
  String get balance => _t('المتبقي', 'Balance');
  String get payNow => _t('ادفع الآن', 'Pay now');
  String get fawryCode => _t('كود الدفع في فوري', 'Fawry payment code');
  String get fawryHint => _t(
    'ادفع بهذا الكود في أي منفذ فوري أو من تطبيق البنك.',
    'Pay with this code at any Fawry outlet or from your banking app.',
  );

  // Staff
  String get checkIn => _t('تسجيل حضور', 'Check in');
  String get checkOut => _t('تسليم', 'Check out');
  String get scanAtDoor => _t('مسح كود الاستلام', 'Scan pickup code');
  String get passCodeEntry => _t('إدخال كود تصريح', 'Enter a pass code');
  String get whoIsCollecting => _t('من يستلم الطفل؟', 'Who is collecting?');
  String get notAllowed =>
      _t('غير مسموح — لا تسلّمي الطفل', 'Not allowed — do not hand over');
  String get allowed => _t('مسموح بالاستلام', 'Allowed');
  String get latePickup => _t('تأخر الاستلام', 'Late pickup');
  String get post => _t('نشر', 'Post');
  String get newMoment => _t('تحديث جديد', 'New update');
  String get wholeClass => _t('الفصل كله', 'Whole class');
  String get chooseChildren => _t('اختر الأطفال', 'Choose children');
  String get addPhotos => _t('إضافة صور', 'Add photos');
  String get subscription => _t('الاشتراك', 'Subscription');
  String get language => _t('اللغة', 'Language');
}
