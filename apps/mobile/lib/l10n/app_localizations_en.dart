// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'إفطار صائم';

  @override
  String get appSubtitle => 'Iftar distribution for volunteers';

  @override
  String get hadithMeaning =>
      'Whoever gives iftar to a fasting person shares in their reward';

  @override
  String get blessingMeaning => 'May God accept it';

  @override
  String get signIn => 'Sign in';

  @override
  String get createVolunteerAccount => 'Create volunteer account';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get loginLead => 'Sign in to serve tonight in your region.';

  @override
  String get registerTitle => 'Join the volunteers';

  @override
  String get registerLead => 'Each volunteer serves one region.';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get fullName => 'Name';

  @override
  String get email => 'Email';

  @override
  String get region => 'Region';

  @override
  String get chooseRegion => 'Choose your region';

  @override
  String get loadingRegions => 'Loading regions…';

  @override
  String get regionsFailed => 'Could not load regions';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get usernameRequired => 'Username is required.';

  @override
  String get passwordRequired => 'Password is required.';

  @override
  String get nameRequired => 'Name is required.';

  @override
  String get emailRequired => 'Email is required.';

  @override
  String get emailInvalid => 'Enter a valid email address.';

  @override
  String get passwordTooShort => 'Use at least 6 characters.';

  @override
  String get regionRequired => 'Region is required.';

  @override
  String get newVolunteerCreateAccount => 'New volunteer? Create an account';

  @override
  String get haveAccountSignIn => 'Already a volunteer? Sign in';

  @override
  String get accountCreated => 'Account created. You can sign in now.';

  @override
  String get signUp => 'Create account';

  @override
  String get errLoginFailed => 'Wrong username or password.';

  @override
  String get errAccountDisabled => 'This account has been disabled.';

  @override
  String get errNetwork =>
      'No internet connection. Check your network and try again.';

  @override
  String get errTimeout =>
      'The server is taking too long to respond. Try again.';

  @override
  String get errSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errForbidden => 'You are not allowed to perform this action.';

  @override
  String get errNotFound => 'Not found.';

  @override
  String get errServer =>
      'Something went wrong on the server. Try again in a moment.';

  @override
  String get errUnknown => 'Unexpected error. Try again.';

  @override
  String get errNoRegion =>
      'Your account has no region assigned. Ask an administrator.';

  @override
  String get errUsernameTaken => 'Username or email is already in use.';

  @override
  String get titleOffline => 'You are offline';

  @override
  String get titleSlow => 'The server is slow';

  @override
  String get titleServerError => 'Server error';

  @override
  String get titleSignedOut => 'Signed out';

  @override
  String get titleNotFound => 'Not found';

  @override
  String get titleGenericError => 'Something went wrong';

  @override
  String get tryAgain => 'Try again';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';

  @override
  String get back => 'Back';

  @override
  String get loading => 'Fetching data';

  @override
  String get increase => 'Increase';

  @override
  String get decrease => 'Decrease';

  @override
  String get navPeople => 'People';

  @override
  String get navAdd => 'Add';

  @override
  String get navStats => 'Stats';

  @override
  String get navProfile => 'Profile';

  @override
  String get navScan => 'Scan a card';

  @override
  String ramadanDay(String day) {
    return 'Ramadan $day';
  }

  @override
  String get peopleTitle => 'Fasting people';

  @override
  String peopleCount(String total, String served) {
    return '$total registered · $served served today';
  }

  @override
  String get searchPeople => 'Search by name, ID, or CIN';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get filterAll => 'All';

  @override
  String get filterWaiting => 'Waiting';

  @override
  String get filterServed => 'Served';

  @override
  String get noPeopleTitle => 'No fasting people yet';

  @override
  String get noPeopleMessage =>
      'Add the first person to start distributing meals.';

  @override
  String get addPerson => 'Add person';

  @override
  String get everyoneServed => 'Everyone has been served tonight.';

  @override
  String get nobodyServedYet => 'Nobody has been served yet tonight.';

  @override
  String noMatch(String query) {
    return 'No one matches “$query”.';
  }

  @override
  String get searchTip => 'Search by name, ID, CIN, or phone.';

  @override
  String get offlineLastList => 'Offline. Showing the last loaded list.';

  @override
  String mealSingleCount(int count) {
    return '$count single';
  }

  @override
  String mealFamilyCount(int count) {
    return '$count family';
  }

  @override
  String get servedTooltip => 'Served today';

  @override
  String get notServedTooltip => 'Not served yet today';

  @override
  String portions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portions',
      one: '1 portion',
    );
    return '$_temp0';
  }

  @override
  String get addTitle => 'New person';

  @override
  String get addSubtitle => 'Scan the card first, it fills the ID';

  @override
  String get editTitle => 'Edit person';

  @override
  String get cardId => 'Card ID';

  @override
  String get scanCard => 'Scan';

  @override
  String cardRead(String id) {
    return 'Card read: #$id';
  }

  @override
  String get cardScanTitle => 'Scan the card';

  @override
  String get cardInvalid => 'This code isn’t a card ID.';

  @override
  String get idRequired => 'Scan or type the card ID';

  @override
  String get idInvalid => 'The card ID must be a positive whole number';

  @override
  String get idTaken => 'This card ID is already registered';

  @override
  String get firstName => 'First name';

  @override
  String get lastName => 'Last name';

  @override
  String get firstNameRequired => 'Add a first name';

  @override
  String get lastNameRequired => 'Add a last name';

  @override
  String get cinLabel => 'CIN (8 digits)';

  @override
  String get cinLength => 'The CIN has 8 digits';

  @override
  String duplicateCin(String name, String id) {
    return 'Same CIN as $name (#$id). Is this the same person?';
  }

  @override
  String get openExistingRecord => 'Open existing record';

  @override
  String get mealsEachEvening => 'Meals each evening';

  @override
  String get singleMeal => 'Single meal';

  @override
  String get familyMeal => 'Family meal';

  @override
  String handsOverEachEvening(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portions',
      one: '1 portion',
    );
    return 'Hands over $_temp0 each evening';
  }

  @override
  String get mealsAtLeastOne => 'Choose at least one meal';

  @override
  String get hereNow => 'Here now';

  @override
  String get hereNowSubtitle => 'Hand over tonight’s meal and record it';

  @override
  String get optionalFields => 'Phone and notes (optional)';

  @override
  String get phone => 'Phone';

  @override
  String get notes => 'Notes';

  @override
  String get saveAndHandOver => 'Save and hand over';

  @override
  String get saveAndAddAnother => 'Save and add another';

  @override
  String get updatePerson => 'Update person details';

  @override
  String get deletePerson => 'Delete person';

  @override
  String get deleteTitle => 'Delete this person?';

  @override
  String deleteBody(String name) {
    return '$name will be removed from the fasting people list.';
  }

  @override
  String get delete => 'Delete';

  @override
  String personSaved(String name) {
    return '$name saved.';
  }

  @override
  String personSavedHandOver(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portions',
      one: '1 portion',
    );
    return '$name saved. Hand over $_temp0.';
  }

  @override
  String get personUpdated => 'Person updated.';

  @override
  String personDeleted(String name) {
    return '$name deleted.';
  }

  @override
  String get detailsTitle => 'Person details';

  @override
  String get identity => 'Identity';

  @override
  String get meals => 'Meals';

  @override
  String get identifier => 'Card ID';

  @override
  String get cinShortLabel => 'CIN';

  @override
  String lastMeal(String date) {
    return 'Last meal: $date';
  }

  @override
  String get mealToday => 'Tonight';

  @override
  String get confirmMeal => 'Confirm meal';

  @override
  String get alreadyServedToday => 'Already served today';

  @override
  String mealHistory(int count) {
    return 'Meal history ($count)';
  }

  @override
  String mealHistoryTitle(String name) {
    return 'Meals taken by $name';
  }

  @override
  String get noMealsYet => 'No meals taken yet.';

  @override
  String get mealConfirmed => 'Meal confirmed.';

  @override
  String get alreadyCollected => 'Already collected today.';

  @override
  String alreadyCollectedAt(String time) {
    return 'Already collected today at $time.';
  }

  @override
  String get editContact => 'Edit phone and comment';

  @override
  String get contactTitle => 'Phone and comment';

  @override
  String get comment => 'Comment';

  @override
  String get scanTitle => 'Scan card';

  @override
  String servedTonight(int count) {
    return '$count served tonight';
  }

  @override
  String get torchOn => 'Turn torch on';

  @override
  String get torchOff => 'Turn torch off';

  @override
  String get closeScanner => 'Close scanner';

  @override
  String get scanHint => 'Hold the card inside the arch';

  @override
  String get findNoCard => 'Find someone without a card';

  @override
  String get findNoCardSubtitle => 'Search by name, CIN, or phone';

  @override
  String get checkingStatus => 'Checking tonight’s status…';

  @override
  String lookingUp(int id) {
    return 'Looking up #$id…';
  }

  @override
  String get notServedTonight => 'Not served tonight';

  @override
  String get handOver => 'Hand over';

  @override
  String get none => 'none';

  @override
  String get confirmHandOver => 'Confirm hand-over';

  @override
  String get confirming => 'Confirming…';

  @override
  String get sendingSlow => 'Sending… slow connection';

  @override
  String get skip => 'Skip';

  @override
  String get details => 'Details';

  @override
  String noCardCheck(String digits) {
    return 'No card: ask for the CIN ending in $digits';
  }

  @override
  String get noCinOnFile =>
      'No ID card number on file — check another document.';

  @override
  String servedLine(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portions',
      one: '1 portion',
    );
    return 'Served $name · $_temp0';
  }

  @override
  String get alreadyServedTonight => 'Already served tonight';

  @override
  String alreadyServedNote(String time) {
    return 'Nothing to hand over. Kindly let them know it was collected at $time.';
  }

  @override
  String get alreadyServedNoteNoTime =>
      'Nothing to hand over. Kindly let them know it was already collected tonight.';

  @override
  String undoCountdown(int seconds) {
    return 'Undo · $seconds';
  }

  @override
  String undone(String name) {
    return 'Undone. $name is not marked as served.';
  }

  @override
  String get undoFailed => 'Couldn’t undo. Try again from History.';

  @override
  String get undoTooLate => 'It’s too late to undo. Ask an admin.';

  @override
  String get undoNeedsConnection =>
      'Undo needs a connection. Try again from History.';

  @override
  String servedAtBy(String time, String name) {
    return 'Served at $time by $name';
  }

  @override
  String get undoTonightsMeal => 'Undo tonight’s meal';

  @override
  String servedBy(String name) {
    return 'by $name';
  }

  @override
  String get scanNextCard => 'Scan next card';

  @override
  String get history => 'History';

  @override
  String unknownCardTitle(int id) {
    return 'Card #$id isn’t registered';
  }

  @override
  String unknownCardMessage(String region) {
    return 'Nobody has this card in $region.';
  }

  @override
  String get registerThisCard => 'Register this card';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get invalidCodeTitle => 'This code can’t be read';

  @override
  String get invalidCodeMessage =>
      'It isn’t an Iftar Saem card, or it’s damaged.';

  @override
  String get notConfirmedYet => 'Not confirmed yet';

  @override
  String get dontHandOverYet => 'Don’t hand over until it’s confirmed';

  @override
  String get notConfirmedExplanation =>
      'The meal isn’t confirmed until the server answers. Retry, and don’t serve twice.';

  @override
  String get cameraOffTitle => 'Camera access is off';

  @override
  String get cameraOffMessage =>
      'Allow camera access for this app in your phone settings to scan cards. You can still find people without a card.';

  @override
  String get cameraOpenSettings => 'Open settings';

  @override
  String get cameraUnavailableTitle => 'Camera unavailable';

  @override
  String get cameraUnavailableMessage =>
      'The camera could not be started. You can still find people without a card.';

  @override
  String get sealServe => 'Can be served';

  @override
  String get sealServed => 'Already served';

  @override
  String get sealChecking => 'Checking';

  @override
  String get sealProblem => 'Needs attention';

  @override
  String get sealDone => 'Served';

  @override
  String get findTitle => 'Without a card';

  @override
  String get findSearchHint => 'Name, CIN, ID, or phone';

  @override
  String get findMinChars =>
      'Type 2 letters or a number. Results come from this phone.';

  @override
  String findLookUpId(int id) {
    return 'Look up card #$id';
  }

  @override
  String get summaryKicker => 'Tonight';

  @override
  String get summaryServedByYou => 'iftars served by you';

  @override
  String summaryDetail(int family, int single, int portions) {
    return '$family family · $single single · $portions portions';
  }

  @override
  String get backToPeople => 'Back to people';

  @override
  String get keepScanning => 'Keep scanning';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get presetTonight => 'Tonight';

  @override
  String get presetWeek => 'This week';

  @override
  String get presetRamadan => 'Ramadan';

  @override
  String get presetCustom => 'Custom';

  @override
  String ofPeopleServed(int count) {
    return 'of $count people served';
  }

  @override
  String get peopleServed => 'people served';

  @override
  String get figPortions => 'portions';

  @override
  String get figSingle => 'single';

  @override
  String get figFamily => 'family portions';

  @override
  String get customDates => 'Custom dates';

  @override
  String get fromDate => 'From';

  @override
  String get toDate => 'To';

  @override
  String get apply => 'Apply';

  @override
  String get rangeInvalid =>
      'The start date must be on or before the end date.';

  @override
  String get rangeInFuture => 'Pick dates up to today.';

  @override
  String get byDay => 'By day';

  @override
  String get noStats => 'No meals recorded in this period.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get ramadanKareem => 'Ramadan Kareem';

  @override
  String get noRegion => 'No region';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceSystem => 'System';

  @override
  String get appearanceDay => 'Day';

  @override
  String get appearanceNight => 'Night';

  @override
  String get dataSection => 'Data';

  @override
  String get exportList => 'Export fasting persons list';

  @override
  String get exportFailed => 'Could not create the file.';

  @override
  String get logout => 'Log out';

  @override
  String get logoutTitle => 'Log out?';

  @override
  String get logoutBody => 'You will need to sign in again to scan cards.';

  @override
  String get updateAvailableTitle => 'A new version is available';

  @override
  String updateAvailableBody(String version) {
    return 'Version $version is available. You can keep working and update later.';
  }

  @override
  String get updateNow => 'Update';

  @override
  String get updateLater => 'Later';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String get updateRequiredBody =>
      'Your version of the app is no longer supported. Please install the latest version to continue.';

  @override
  String get updateOpenFailed => 'Could not open the browser.';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }
}
