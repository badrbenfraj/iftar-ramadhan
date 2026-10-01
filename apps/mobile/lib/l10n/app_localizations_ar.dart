// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'إفطار صائم';

  @override
  String get appSubtitle => 'توزيع الإفطار للمتطوّعين';

  @override
  String get hadithMeaning => '';

  @override
  String get blessingMeaning => '';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get createVolunteerAccount => 'إنشاء حساب متطوّع';

  @override
  String get welcomeBack => 'مرحباً بعودتك';

  @override
  String get loginLead => 'سجّل الدخول للتوزيع الليلة في منطقتك.';

  @override
  String get registerTitle => 'انضمّ إلى المتطوّعين';

  @override
  String get registerLead => 'كل متطوّع يوزّع في منطقة واحدة.';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get password => 'كلمة المرور';

  @override
  String get fullName => 'الاسم';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get region => 'المنطقة';

  @override
  String get chooseRegion => 'اختر منطقتك';

  @override
  String get loadingRegions => 'جارٍ تحميل المناطق…';

  @override
  String get regionsFailed => 'تعذّر تحميل المناطق';

  @override
  String get showPassword => 'إظهار كلمة المرور';

  @override
  String get hidePassword => 'إخفاء كلمة المرور';

  @override
  String get usernameRequired => 'اسم المستخدم مطلوب.';

  @override
  String get passwordRequired => 'كلمة المرور مطلوبة.';

  @override
  String get nameRequired => 'الاسم مطلوب.';

  @override
  String get emailRequired => 'البريد الإلكتروني مطلوب.';

  @override
  String get emailInvalid => 'أدخل بريداً إلكترونياً صحيحاً.';

  @override
  String get passwordTooShort => '6 أحرف على الأقل.';

  @override
  String get regionRequired => 'المنطقة مطلوبة.';

  @override
  String get newVolunteerCreateAccount => 'متطوّع جديد؟ أنشئ حساباً';

  @override
  String get haveAccountSignIn => 'لديك حساب؟ سجّل الدخول';

  @override
  String get accountCreated => 'تم إنشاء الحساب. يمكنك تسجيل الدخول الآن.';

  @override
  String get signUp => 'إنشاء الحساب';

  @override
  String get errLoginFailed => 'اسم المستخدم أو كلمة المرور غير صحيحة.';

  @override
  String get errAccountDisabled => 'تم تعطيل هذا الحساب.';

  @override
  String get errNetwork =>
      'لا يوجد اتصال بالإنترنت. تحقّق من الشبكة وأعد المحاولة.';

  @override
  String get errTimeout => 'الخادم يتأخر في الرد. أعد المحاولة.';

  @override
  String get errSessionExpired => 'انتهت الجلسة. سجّل الدخول من جديد.';

  @override
  String get errForbidden => 'غير مسموح لك بهذا الإجراء.';

  @override
  String get errNotFound => 'غير موجود.';

  @override
  String get errServer => 'حدث خطأ في الخادم. أعد المحاولة بعد قليل.';

  @override
  String get errUnknown => 'خطأ غير متوقع. أعد المحاولة.';

  @override
  String get errNoRegion => 'لا توجد منطقة مرتبطة بحسابك. تواصل مع المشرف.';

  @override
  String get errUsernameTaken => 'اسم المستخدم أو البريد مستعمل من قبل.';

  @override
  String get titleOffline => 'أنت غير متصل';

  @override
  String get titleSlow => 'الخادم بطيء';

  @override
  String get titleServerError => 'خطأ في الخادم';

  @override
  String get titleSignedOut => 'تم تسجيل الخروج';

  @override
  String get titleNotFound => 'غير موجود';

  @override
  String get titleGenericError => 'حدث خطأ';

  @override
  String get tryAgain => 'أعد المحاولة';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get edit => 'تعديل';

  @override
  String get back => 'رجوع';

  @override
  String get loading => 'جارٍ تحميل البيانات';

  @override
  String get increase => 'زيادة';

  @override
  String get decrease => 'إنقاص';

  @override
  String get navPeople => 'الصائمون';

  @override
  String get navAdd => 'إضافة';

  @override
  String get navStats => 'إحصائيات';

  @override
  String get navProfile => 'حسابي';

  @override
  String get navScan => 'مسح بطاقة';

  @override
  String ramadanDay(int day) {
    return '$day رمضان';
  }

  @override
  String get peopleTitle => 'الصائمون';

  @override
  String peopleCount(int total, int served) {
    return '$total مسجّلاً · $served استلموا اليوم';
  }

  @override
  String get searchPeople => 'ابحث بالاسم أو الرقم أو ب.ت.و';

  @override
  String get clearSearch => 'مسح البحث';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterWaiting => 'في الانتظار';

  @override
  String get filterServed => 'استلموا';

  @override
  String get noPeopleTitle => 'لا يوجد صائمون بعد';

  @override
  String get noPeopleMessage => 'أضف أول شخص لبدء التوزيع.';

  @override
  String get addPerson => 'إضافة شخص';

  @override
  String get everyoneServed => 'استلم الجميع الليلة.';

  @override
  String noMatch(String query) {
    return 'لا أحد يطابق «$query».';
  }

  @override
  String get searchTip => 'ابحث بالاسم أو الرقم أو ب.ت.و أو الهاتف.';

  @override
  String get offlineLastList => 'دون اتصال. تُعرض آخر قائمة محمّلة.';

  @override
  String mealSingleCount(int count) {
    return '$count فردية';
  }

  @override
  String mealFamilyCount(int count) {
    return '$count عائلية';
  }

  @override
  String get servedTooltip => 'استلم اليوم';

  @override
  String get notServedTooltip => 'لم يستلم بعد اليوم';

  @override
  String portions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة',
      few: '$count حصص',
      two: 'حصتان',
      one: 'حصة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get addTitle => 'شخص جديد';

  @override
  String get addSubtitle => 'امسح البطاقة أولاً، فهي تملأ الرقم';

  @override
  String get editTitle => 'تعديل الشخص';

  @override
  String get cardId => 'رقم البطاقة';

  @override
  String get scanCard => 'مسح';

  @override
  String cardRead(int id) {
    return 'تمت قراءة البطاقة: $id';
  }

  @override
  String get cardScanTitle => 'امسح البطاقة';

  @override
  String get cardInvalid => 'هذا الرمز ليس رقم بطاقة.';

  @override
  String get idRequired => 'امسح رقم البطاقة أو اكتبه';

  @override
  String get idInvalid => 'رقم البطاقة يجب أن يكون عدداً صحيحاً موجباً';

  @override
  String get idTaken => 'رقم البطاقة هذا مسجّل من قبل';

  @override
  String get firstName => 'الاسم';

  @override
  String get lastName => 'اللقب';

  @override
  String get firstNameRequired => 'أضف الاسم';

  @override
  String get lastNameRequired => 'أضف اللقب';

  @override
  String get cinLabel => 'ب.ت.و (8 أرقام)';

  @override
  String get cinLength => 'رقم ب.ت.و يتكوّن من 8 أرقام';

  @override
  String duplicateCin(String name, int id) {
    return 'نفس رقم ب.ت.و لـ $name (رقم $id). هل هو الشخص نفسه؟';
  }

  @override
  String get openExistingRecord => 'فتح الملف الموجود';

  @override
  String get mealsEachEvening => 'الوجبات كل مساء';

  @override
  String get singleMeal => 'وجبة فردية';

  @override
  String get familyMeal => 'وجبة عائلية';

  @override
  String handsOverEachEvening(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة',
      few: '$count حصص',
      two: 'حصتين',
      one: 'حصة واحدة',
    );
    return 'يستلم $_temp0 كل مساء';
  }

  @override
  String get mealsAtLeastOne => 'اختر وجبة واحدة على الأقل';

  @override
  String get hereNow => 'حاضر الآن';

  @override
  String get hereNowSubtitle => 'تسليم وجبة الليلة وتسجيلها';

  @override
  String get optionalFields => 'الهاتف والملاحظات (اختياري)';

  @override
  String get phone => 'الهاتف';

  @override
  String get notes => 'ملاحظات';

  @override
  String get saveAndHandOver => 'حفظ وتسليم';

  @override
  String get saveAndAddAnother => 'حفظ وإضافة آخر';

  @override
  String get updatePerson => 'تحديث المعطيات';

  @override
  String get deletePerson => 'حذف الشخص';

  @override
  String get deleteTitle => 'حذف هذا الشخص؟';

  @override
  String deleteBody(String name) {
    return 'سيُحذف $name من قائمة الصائمين.';
  }

  @override
  String get delete => 'حذف';

  @override
  String personSaved(String name) {
    return 'تم حفظ $name.';
  }

  @override
  String personSavedHandOver(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة',
      few: '$count حصص',
      two: 'حصتين',
      one: 'حصة واحدة',
    );
    return 'تم حفظ $name. سلّمه $_temp0.';
  }

  @override
  String get personUpdated => 'تم تحديث المعطيات.';

  @override
  String personDeleted(String name) {
    return 'تم حذف $name.';
  }

  @override
  String get detailsTitle => 'تفاصيل الشخص';

  @override
  String get identity => 'الهوية';

  @override
  String get meals => 'الوجبات';

  @override
  String get identifier => 'رقم البطاقة';

  @override
  String get cinShortLabel => 'ب.ت.و';

  @override
  String lastMeal(String date) {
    return 'آخر وجبة: $date';
  }

  @override
  String get mealToday => 'الليلة';

  @override
  String get confirmMeal => 'تأكيد الوجبة';

  @override
  String get alreadyServedToday => 'استلم اليوم';

  @override
  String mealHistory(int count) {
    return 'سجل الوجبات ($count)';
  }

  @override
  String mealHistoryTitle(String name) {
    return 'الوجبات التي استلمها $name';
  }

  @override
  String get noMealsYet => 'لا توجد وجبات بعد.';

  @override
  String get mealConfirmed => 'تم تأكيد الوجبة.';

  @override
  String get alreadyCollected => 'استلم اليوم.';

  @override
  String alreadyCollectedAt(String time) {
    return 'استلم اليوم على الساعة $time.';
  }

  @override
  String get editContact => 'تعديل الهاتف والملاحظة';

  @override
  String get contactTitle => 'الهاتف والملاحظة';

  @override
  String get comment => 'ملاحظة';

  @override
  String get scanTitle => 'مسح البطاقة';

  @override
  String servedTonight(int count) {
    return '$count استلموا الليلة';
  }

  @override
  String get torchOn => 'تشغيل المصباح';

  @override
  String get torchOff => 'إطفاء المصباح';

  @override
  String get closeScanner => 'إغلاق الماسح';

  @override
  String get scanHint => 'ضع البطاقة داخل القوس';

  @override
  String get findNoCard => 'البحث عن شخص بلا بطاقة';

  @override
  String get findNoCardSubtitle => 'بالاسم أو ب.ت.و أو الهاتف';

  @override
  String get checkingStatus => 'جارٍ التحقق من حالة الليلة…';

  @override
  String lookingUp(int id) {
    return 'جارٍ البحث عن $id…';
  }

  @override
  String get notServedTonight => 'لم يستلم الليلة';

  @override
  String get handOver => 'يُسلَّم له';

  @override
  String get none => 'لا شيء';

  @override
  String get confirmHandOver => 'تأكيد التسليم';

  @override
  String get confirming => 'جارٍ التأكيد…';

  @override
  String get skip => 'تخطّي';

  @override
  String get details => 'التفاصيل';

  @override
  String noCardCheck(String digits) {
    return 'بلا بطاقة: اطلب رقم ب.ت.و المنتهي بـ $digits';
  }

  @override
  String servedLine(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حصة',
      few: '$count حصص',
      two: 'حصتان',
      one: 'حصة واحدة',
    );
    return 'تم التسليم: $name · $_temp0';
  }

  @override
  String get alreadyServedTonight => 'استلم الليلة';

  @override
  String alreadyServedNote(String time) {
    return 'لا شيء للتسليم. أخبره بلطف أنه استلم على الساعة $time.';
  }

  @override
  String get alreadyServedNoteNoTime =>
      'لا شيء للتسليم. أخبره بلطف أنه استلم الليلة.';

  @override
  String get scanNextCard => 'البطاقة التالية';

  @override
  String get history => 'السجل';

  @override
  String unknownCardTitle(int id) {
    return 'البطاقة رقم $id غير مسجّلة';
  }

  @override
  String unknownCardMessage(String region) {
    return 'لا أحد يحمل هذه البطاقة في $region.';
  }

  @override
  String get registerThisCard => 'تسجيل هذه البطاقة';

  @override
  String get scanAgain => 'إعادة المسح';

  @override
  String get invalidCodeTitle => 'تعذّرت قراءة هذا الرمز';

  @override
  String get invalidCodeMessage => 'ليست بطاقة إفطار صائم، أو أنها تالفة.';

  @override
  String get notConfirmedYet => 'لم يُؤكَّد بعد';

  @override
  String get dontHandOverYet => 'لا تسلّم قبل التأكيد';

  @override
  String get notConfirmedExplanation =>
      'لا تُؤكَّد الوجبة إلا بعد رد الخادم. أعد المحاولة، ولا تسلّم مرتين.';

  @override
  String get cameraOffTitle => 'الوصول إلى الكاميرا معطّل';

  @override
  String get cameraOffMessage =>
      'اسمح لهذا التطبيق باستعمال الكاميرا من إعدادات الهاتف لمسح البطاقات. يمكنك دائماً البحث عن شخص بلا بطاقة.';

  @override
  String get cameraUnavailableTitle => 'الكاميرا غير متاحة';

  @override
  String get cameraUnavailableMessage =>
      'تعذّر تشغيل الكاميرا. يمكنك دائماً البحث عن شخص بلا بطاقة.';

  @override
  String get sealServe => 'يمكن التسليم';

  @override
  String get sealServed => 'استلم';

  @override
  String get sealChecking => 'جارٍ التحقق';

  @override
  String get sealProblem => 'يحتاج انتباهاً';

  @override
  String get sealDone => 'تم التسليم';

  @override
  String get findTitle => 'بلا بطاقة';

  @override
  String get findSearchHint => 'الاسم أو ب.ت.و أو الرقم أو الهاتف';

  @override
  String get findMinChars => 'اكتب حرفين أو رقماً. النتائج من هذا الهاتف.';

  @override
  String findLookUpId(int id) {
    return 'البحث عن البطاقة $id';
  }

  @override
  String get summaryKicker => 'الليلة';

  @override
  String get summaryServedByYou => 'إفطاراً قدّمتَه';

  @override
  String summaryDetail(int family, int single, int portions) {
    return '$family عائلية · $single فردية · $portions حصة';
  }

  @override
  String get backToPeople => 'العودة إلى القائمة';

  @override
  String get keepScanning => 'مواصلة المسح';

  @override
  String get statsTitle => 'الإحصائيات';

  @override
  String get presetTonight => 'الليلة';

  @override
  String get presetWeek => 'هذا الأسبوع';

  @override
  String get presetRamadan => 'رمضان';

  @override
  String get presetCustom => 'مخصّص';

  @override
  String ofPeopleServed(int count) {
    return 'من $count شخصاً استلموا';
  }

  @override
  String get peopleServed => 'شخصاً استلموا';

  @override
  String get figPortions => 'حصة';

  @override
  String get figSingle => 'فردية';

  @override
  String get figFamily => 'حصص عائلية';

  @override
  String get customDates => 'تواريخ مخصّصة';

  @override
  String get fromDate => 'من';

  @override
  String get toDate => 'إلى';

  @override
  String get apply => 'تطبيق';

  @override
  String get rangeInvalid =>
      'تاريخ البداية يجب أن يسبق تاريخ النهاية أو يساويه.';

  @override
  String get byDay => 'حسب اليوم';

  @override
  String get noStats => 'لا توجد وجبات مسجّلة في هذه الفترة.';

  @override
  String get profileTitle => 'حسابي';

  @override
  String get ramadanKareem => 'رمضان كريم';

  @override
  String get noRegion => 'بلا منطقة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get appearance => 'المظهر';

  @override
  String get appearanceSystem => 'حسب الهاتف';

  @override
  String get appearanceDay => 'نهار';

  @override
  String get appearanceNight => 'ليل';

  @override
  String get dataSection => 'البيانات';

  @override
  String get exportList => 'تصدير قائمة الصائمين';

  @override
  String get exportFailed => 'تعذّر إنشاء الملف.';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get logoutTitle => 'تسجيل الخروج؟';

  @override
  String get logoutBody => 'ستحتاج إلى تسجيل الدخول من جديد لمسح البطاقات.';
}
