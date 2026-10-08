import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'إفطار صائم'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Iftar distribution for volunteers'**
  String get appSubtitle;

  /// No description provided for @hadithMeaning.
  ///
  /// In en, this message translates to:
  /// **'Whoever gives iftar to a fasting person shares in their reward'**
  String get hadithMeaning;

  /// No description provided for @blessingMeaning.
  ///
  /// In en, this message translates to:
  /// **'May God accept it'**
  String get blessingMeaning;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @createVolunteerAccount.
  ///
  /// In en, this message translates to:
  /// **'Create volunteer account'**
  String get createVolunteerAccount;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @loginLead.
  ///
  /// In en, this message translates to:
  /// **'Sign in to serve tonight in your region.'**
  String get loginLead;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Join the volunteers'**
  String get registerTitle;

  /// No description provided for @registerLead.
  ///
  /// In en, this message translates to:
  /// **'Each volunteer serves one region.'**
  String get registerLead;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fullName;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @region.
  ///
  /// In en, this message translates to:
  /// **'Region'**
  String get region;

  /// No description provided for @chooseRegion.
  ///
  /// In en, this message translates to:
  /// **'Choose your region'**
  String get chooseRegion;

  /// No description provided for @loadingRegions.
  ///
  /// In en, this message translates to:
  /// **'Loading regions…'**
  String get loadingRegions;

  /// No description provided for @regionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load regions'**
  String get regionsFailed;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required.'**
  String get usernameRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get passwordRequired;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get nameRequired;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get emailInvalid;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 6 characters.'**
  String get passwordTooShort;

  /// No description provided for @regionRequired.
  ///
  /// In en, this message translates to:
  /// **'Region is required.'**
  String get regionRequired;

  /// No description provided for @newVolunteerCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'New volunteer? Create an account'**
  String get newVolunteerCreateAccount;

  /// No description provided for @haveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already a volunteer? Sign in'**
  String get haveAccountSignIn;

  /// No description provided for @accountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created. You can sign in now.'**
  String get accountCreated;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get signUp;

  /// No description provided for @errLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Wrong username or password.'**
  String get errLoginFailed;

  /// No description provided for @errAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get errAccountDisabled;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get errNetwork;

  /// No description provided for @errTimeout.
  ///
  /// In en, this message translates to:
  /// **'The server is taking too long to respond. Try again.'**
  String get errTimeout;

  /// No description provided for @errSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errSessionExpired;

  /// No description provided for @errForbidden.
  ///
  /// In en, this message translates to:
  /// **'You are not allowed to perform this action.'**
  String get errForbidden;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get errNotFound;

  /// No description provided for @errServer.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on the server. Try again in a moment.'**
  String get errServer;

  /// No description provided for @errUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error. Try again.'**
  String get errUnknown;

  /// No description provided for @errNoRegion.
  ///
  /// In en, this message translates to:
  /// **'Your account has no region assigned. Ask an administrator.'**
  String get errNoRegion;

  /// No description provided for @errUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'Username or email is already in use.'**
  String get errUsernameTaken;

  /// No description provided for @titleOffline.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get titleOffline;

  /// No description provided for @titleSlow.
  ///
  /// In en, this message translates to:
  /// **'The server is slow'**
  String get titleSlow;

  /// No description provided for @titleServerError.
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get titleServerError;

  /// No description provided for @titleSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get titleSignedOut;

  /// No description provided for @titleNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get titleNotFound;

  /// No description provided for @titleGenericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get titleGenericError;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Fetching data'**
  String get loading;

  /// No description provided for @increase.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increase;

  /// No description provided for @decrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decrease;

  /// No description provided for @navPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get navPeople;

  /// No description provided for @navAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get navAdd;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navScan.
  ///
  /// In en, this message translates to:
  /// **'Scan a card'**
  String get navScan;

  /// No description provided for @ramadanDay.
  ///
  /// In en, this message translates to:
  /// **'Ramadan {day}'**
  String ramadanDay(String day);

  /// No description provided for @peopleTitle.
  ///
  /// In en, this message translates to:
  /// **'Fasting people'**
  String get peopleTitle;

  /// No description provided for @peopleCount.
  ///
  /// In en, this message translates to:
  /// **'{total} registered · {served} served today'**
  String peopleCount(String total, String served);

  /// No description provided for @searchPeople.
  ///
  /// In en, this message translates to:
  /// **'Search by name, ID, or CIN'**
  String get searchPeople;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get filterWaiting;

  /// No description provided for @filterServed.
  ///
  /// In en, this message translates to:
  /// **'Served'**
  String get filterServed;

  /// No description provided for @noPeopleTitle.
  ///
  /// In en, this message translates to:
  /// **'No fasting people yet'**
  String get noPeopleTitle;

  /// No description provided for @noPeopleMessage.
  ///
  /// In en, this message translates to:
  /// **'Add the first person to start distributing meals.'**
  String get noPeopleMessage;

  /// No description provided for @addPerson.
  ///
  /// In en, this message translates to:
  /// **'Add person'**
  String get addPerson;

  /// No description provided for @everyoneServed.
  ///
  /// In en, this message translates to:
  /// **'Everyone has been served tonight.'**
  String get everyoneServed;

  /// No description provided for @nobodyServedYet.
  ///
  /// In en, this message translates to:
  /// **'Nobody has been served yet tonight.'**
  String get nobodyServedYet;

  /// No description provided for @noMatch.
  ///
  /// In en, this message translates to:
  /// **'No one matches “{query}”.'**
  String noMatch(String query);

  /// No description provided for @searchTip.
  ///
  /// In en, this message translates to:
  /// **'Search by name, ID, CIN, or phone.'**
  String get searchTip;

  /// No description provided for @offlineLastList.
  ///
  /// In en, this message translates to:
  /// **'Offline. Showing the last loaded list.'**
  String get offlineLastList;

  /// No description provided for @mealSingleCount.
  ///
  /// In en, this message translates to:
  /// **'{count} single'**
  String mealSingleCount(int count);

  /// No description provided for @mealFamilyCount.
  ///
  /// In en, this message translates to:
  /// **'{count} family'**
  String mealFamilyCount(int count);

  /// No description provided for @servedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Served today'**
  String get servedTooltip;

  /// No description provided for @notServedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Not served yet today'**
  String get notServedTooltip;

  /// No description provided for @portions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 portion} other{{count} portions}}'**
  String portions(int count);

  /// No description provided for @addTitle.
  ///
  /// In en, this message translates to:
  /// **'New person'**
  String get addTitle;

  /// No description provided for @addSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the card first, it fills the ID'**
  String get addSubtitle;

  /// No description provided for @editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit person'**
  String get editTitle;

  /// No description provided for @cardId.
  ///
  /// In en, this message translates to:
  /// **'Card ID'**
  String get cardId;

  /// No description provided for @scanCard.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scanCard;

  /// No description provided for @cardRead.
  ///
  /// In en, this message translates to:
  /// **'Card read: #{id}'**
  String cardRead(String id);

  /// No description provided for @cardScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the card'**
  String get cardScanTitle;

  /// No description provided for @cardInvalid.
  ///
  /// In en, this message translates to:
  /// **'This code isn’t a card ID.'**
  String get cardInvalid;

  /// No description provided for @idRequired.
  ///
  /// In en, this message translates to:
  /// **'Scan or type the card ID'**
  String get idRequired;

  /// No description provided for @idInvalid.
  ///
  /// In en, this message translates to:
  /// **'The card ID must be a positive whole number'**
  String get idInvalid;

  /// No description provided for @idTaken.
  ///
  /// In en, this message translates to:
  /// **'This card ID is already registered'**
  String get idTaken;

  /// No description provided for @firstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstName;

  /// No description provided for @lastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastName;

  /// No description provided for @firstNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a first name'**
  String get firstNameRequired;

  /// No description provided for @lastNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a last name'**
  String get lastNameRequired;

  /// No description provided for @cinLabel.
  ///
  /// In en, this message translates to:
  /// **'CIN (8 digits)'**
  String get cinLabel;

  /// No description provided for @cinLength.
  ///
  /// In en, this message translates to:
  /// **'The CIN has 8 digits'**
  String get cinLength;

  /// No description provided for @duplicateCin.
  ///
  /// In en, this message translates to:
  /// **'Same CIN as {name} (#{id}). Is this the same person?'**
  String duplicateCin(String name, String id);

  /// No description provided for @openExistingRecord.
  ///
  /// In en, this message translates to:
  /// **'Open existing record'**
  String get openExistingRecord;

  /// No description provided for @mealsEachEvening.
  ///
  /// In en, this message translates to:
  /// **'Meals each evening'**
  String get mealsEachEvening;

  /// No description provided for @singleMeal.
  ///
  /// In en, this message translates to:
  /// **'Single meal'**
  String get singleMeal;

  /// No description provided for @familyMeal.
  ///
  /// In en, this message translates to:
  /// **'Family meal'**
  String get familyMeal;

  /// No description provided for @handsOverEachEvening.
  ///
  /// In en, this message translates to:
  /// **'Hands over {count, plural, =1{1 portion} other{{count} portions}} each evening'**
  String handsOverEachEvening(int count);

  /// No description provided for @mealsAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one meal'**
  String get mealsAtLeastOne;

  /// No description provided for @hereNow.
  ///
  /// In en, this message translates to:
  /// **'Here now'**
  String get hereNow;

  /// No description provided for @hereNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hand over tonight’s meal and record it'**
  String get hereNowSubtitle;

  /// No description provided for @optionalFields.
  ///
  /// In en, this message translates to:
  /// **'Phone and notes (optional)'**
  String get optionalFields;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @saveAndHandOver.
  ///
  /// In en, this message translates to:
  /// **'Save and hand over'**
  String get saveAndHandOver;

  /// No description provided for @saveAndAddAnother.
  ///
  /// In en, this message translates to:
  /// **'Save and add another'**
  String get saveAndAddAnother;

  /// No description provided for @updatePerson.
  ///
  /// In en, this message translates to:
  /// **'Update person details'**
  String get updatePerson;

  /// No description provided for @deletePerson.
  ///
  /// In en, this message translates to:
  /// **'Delete person'**
  String get deletePerson;

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this person?'**
  String get deleteTitle;

  /// No description provided for @deleteBody.
  ///
  /// In en, this message translates to:
  /// **'{name} will be removed from the fasting people list.'**
  String deleteBody(String name);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @personSaved.
  ///
  /// In en, this message translates to:
  /// **'{name} saved.'**
  String personSaved(String name);

  /// No description provided for @personSavedHandOver.
  ///
  /// In en, this message translates to:
  /// **'{name} saved. Hand over {count, plural, =1{1 portion} other{{count} portions}}.'**
  String personSavedHandOver(String name, int count);

  /// No description provided for @personUpdated.
  ///
  /// In en, this message translates to:
  /// **'Person updated.'**
  String get personUpdated;

  /// No description provided for @personDeleted.
  ///
  /// In en, this message translates to:
  /// **'{name} deleted.'**
  String personDeleted(String name);

  /// No description provided for @detailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Person details'**
  String get detailsTitle;

  /// No description provided for @identity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get identity;

  /// No description provided for @meals.
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get meals;

  /// No description provided for @identifier.
  ///
  /// In en, this message translates to:
  /// **'Card ID'**
  String get identifier;

  /// No description provided for @cinShortLabel.
  ///
  /// In en, this message translates to:
  /// **'CIN'**
  String get cinShortLabel;

  /// No description provided for @lastMeal.
  ///
  /// In en, this message translates to:
  /// **'Last meal: {date}'**
  String lastMeal(String date);

  /// No description provided for @mealToday.
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get mealToday;

  /// No description provided for @confirmMeal.
  ///
  /// In en, this message translates to:
  /// **'Confirm meal'**
  String get confirmMeal;

  /// No description provided for @alreadyServedToday.
  ///
  /// In en, this message translates to:
  /// **'Already served today'**
  String get alreadyServedToday;

  /// No description provided for @mealHistory.
  ///
  /// In en, this message translates to:
  /// **'Meal history ({count})'**
  String mealHistory(int count);

  /// No description provided for @mealHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Meals taken by {name}'**
  String mealHistoryTitle(String name);

  /// No description provided for @noMealsYet.
  ///
  /// In en, this message translates to:
  /// **'No meals taken yet.'**
  String get noMealsYet;

  /// No description provided for @mealConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Meal confirmed.'**
  String get mealConfirmed;

  /// No description provided for @alreadyCollected.
  ///
  /// In en, this message translates to:
  /// **'Already collected today.'**
  String get alreadyCollected;

  /// No description provided for @alreadyCollectedAt.
  ///
  /// In en, this message translates to:
  /// **'Already collected today at {time}.'**
  String alreadyCollectedAt(String time);

  /// No description provided for @editContact.
  ///
  /// In en, this message translates to:
  /// **'Edit phone and comment'**
  String get editContact;

  /// No description provided for @contactTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone and comment'**
  String get contactTitle;

  /// No description provided for @comment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get comment;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan card'**
  String get scanTitle;

  /// No description provided for @servedTonight.
  ///
  /// In en, this message translates to:
  /// **'{count} served tonight'**
  String servedTonight(int count);

  /// No description provided for @torchOn.
  ///
  /// In en, this message translates to:
  /// **'Turn torch on'**
  String get torchOn;

  /// No description provided for @torchOff.
  ///
  /// In en, this message translates to:
  /// **'Turn torch off'**
  String get torchOff;

  /// No description provided for @closeScanner.
  ///
  /// In en, this message translates to:
  /// **'Close scanner'**
  String get closeScanner;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Hold the card inside the arch'**
  String get scanHint;

  /// No description provided for @findNoCard.
  ///
  /// In en, this message translates to:
  /// **'Find someone without a card'**
  String get findNoCard;

  /// No description provided for @findNoCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search by name, CIN, or phone'**
  String get findNoCardSubtitle;

  /// No description provided for @checkingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking tonight’s status…'**
  String get checkingStatus;

  /// No description provided for @lookingUp.
  ///
  /// In en, this message translates to:
  /// **'Looking up #{id}…'**
  String lookingUp(int id);

  /// No description provided for @notServedTonight.
  ///
  /// In en, this message translates to:
  /// **'Not served tonight'**
  String get notServedTonight;

  /// No description provided for @handOver.
  ///
  /// In en, this message translates to:
  /// **'Hand over'**
  String get handOver;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get none;

  /// No description provided for @confirmHandOver.
  ///
  /// In en, this message translates to:
  /// **'Confirm hand-over'**
  String get confirmHandOver;

  /// No description provided for @confirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming…'**
  String get confirming;

  /// No description provided for @sendingSlow.
  ///
  /// In en, this message translates to:
  /// **'Sending… slow connection'**
  String get sendingSlow;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @noCardCheck.
  ///
  /// In en, this message translates to:
  /// **'No card: ask for the CIN ending in {digits}'**
  String noCardCheck(String digits);

  /// No description provided for @noCinOnFile.
  ///
  /// In en, this message translates to:
  /// **'No ID card number on file — check another document.'**
  String get noCinOnFile;

  /// No description provided for @servedLine.
  ///
  /// In en, this message translates to:
  /// **'Served {name} · {count, plural, =1{1 portion} other{{count} portions}}'**
  String servedLine(String name, int count);

  /// No description provided for @alreadyServedTonight.
  ///
  /// In en, this message translates to:
  /// **'Already served tonight'**
  String get alreadyServedTonight;

  /// No description provided for @alreadyServedNote.
  ///
  /// In en, this message translates to:
  /// **'Nothing to hand over. Kindly let them know it was collected at {time}.'**
  String alreadyServedNote(String time);

  /// No description provided for @alreadyServedNoteNoTime.
  ///
  /// In en, this message translates to:
  /// **'Nothing to hand over. Kindly let them know it was already collected tonight.'**
  String get alreadyServedNoteNoTime;

  /// No description provided for @undoCountdown.
  ///
  /// In en, this message translates to:
  /// **'Undo · {seconds}'**
  String undoCountdown(int seconds);

  /// No description provided for @undone.
  ///
  /// In en, this message translates to:
  /// **'Undone. {name} is not marked as served.'**
  String undone(String name);

  /// No description provided for @undoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t undo. Try again from History.'**
  String get undoFailed;

  /// No description provided for @undoTooLate.
  ///
  /// In en, this message translates to:
  /// **'It’s too late to undo. Ask an admin.'**
  String get undoTooLate;

  /// No description provided for @undoNeedsConnection.
  ///
  /// In en, this message translates to:
  /// **'Undo needs a connection. Try again from History.'**
  String get undoNeedsConnection;

  /// No description provided for @servedAtBy.
  ///
  /// In en, this message translates to:
  /// **'Served at {time} by {name}'**
  String servedAtBy(String time, String name);

  /// No description provided for @undoTonightsMeal.
  ///
  /// In en, this message translates to:
  /// **'Undo tonight’s meal'**
  String get undoTonightsMeal;

  /// No description provided for @servedBy.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String servedBy(String name);

  /// No description provided for @scanNextCard.
  ///
  /// In en, this message translates to:
  /// **'Scan next card'**
  String get scanNextCard;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @unknownCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Card #{id} isn’t registered'**
  String unknownCardTitle(int id);

  /// No description provided for @unknownCardMessage.
  ///
  /// In en, this message translates to:
  /// **'Nobody has this card in {region}.'**
  String unknownCardMessage(String region);

  /// No description provided for @registerThisCard.
  ///
  /// In en, this message translates to:
  /// **'Register this card'**
  String get registerThisCard;

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// No description provided for @invalidCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'This code can’t be read'**
  String get invalidCodeTitle;

  /// No description provided for @invalidCodeMessage.
  ///
  /// In en, this message translates to:
  /// **'It isn’t an Iftar Saem card, or it’s damaged.'**
  String get invalidCodeMessage;

  /// No description provided for @notConfirmedYet.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed yet'**
  String get notConfirmedYet;

  /// No description provided for @dontHandOverYet.
  ///
  /// In en, this message translates to:
  /// **'Don’t hand over until it’s confirmed'**
  String get dontHandOverYet;

  /// No description provided for @notConfirmedExplanation.
  ///
  /// In en, this message translates to:
  /// **'The meal isn’t confirmed until the server answers. Retry, and don’t serve twice.'**
  String get notConfirmedExplanation;

  /// No description provided for @cameraOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off'**
  String get cameraOffTitle;

  /// No description provided for @cameraOffMessage.
  ///
  /// In en, this message translates to:
  /// **'Allow camera access for this app in your phone settings to scan cards. You can still find people without a card.'**
  String get cameraOffMessage;

  /// No description provided for @cameraOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get cameraOpenSettings;

  /// No description provided for @cameraUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get cameraUnavailableTitle;

  /// No description provided for @cameraUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'The camera could not be started. You can still find people without a card.'**
  String get cameraUnavailableMessage;

  /// No description provided for @sealServe.
  ///
  /// In en, this message translates to:
  /// **'Can be served'**
  String get sealServe;

  /// No description provided for @sealServed.
  ///
  /// In en, this message translates to:
  /// **'Already served'**
  String get sealServed;

  /// No description provided for @sealChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get sealChecking;

  /// No description provided for @sealProblem.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get sealProblem;

  /// No description provided for @sealDone.
  ///
  /// In en, this message translates to:
  /// **'Served'**
  String get sealDone;

  /// No description provided for @findTitle.
  ///
  /// In en, this message translates to:
  /// **'Without a card'**
  String get findTitle;

  /// No description provided for @findSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Name, CIN, ID, or phone'**
  String get findSearchHint;

  /// No description provided for @findMinChars.
  ///
  /// In en, this message translates to:
  /// **'Type 2 letters or a number. Results come from this phone.'**
  String get findMinChars;

  /// No description provided for @findLookUpId.
  ///
  /// In en, this message translates to:
  /// **'Look up card #{id}'**
  String findLookUpId(int id);

  /// No description provided for @summaryKicker.
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get summaryKicker;

  /// No description provided for @summaryServedByYou.
  ///
  /// In en, this message translates to:
  /// **'iftars served by you'**
  String get summaryServedByYou;

  /// No description provided for @summaryDetail.
  ///
  /// In en, this message translates to:
  /// **'{family} family · {single} single · {portions} portions'**
  String summaryDetail(int family, int single, int portions);

  /// No description provided for @backToPeople.
  ///
  /// In en, this message translates to:
  /// **'Back to people'**
  String get backToPeople;

  /// No description provided for @keepScanning.
  ///
  /// In en, this message translates to:
  /// **'Keep scanning'**
  String get keepScanning;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;

  /// No description provided for @presetTonight.
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get presetTonight;

  /// No description provided for @presetWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get presetWeek;

  /// No description provided for @presetRamadan.
  ///
  /// In en, this message translates to:
  /// **'Ramadan'**
  String get presetRamadan;

  /// No description provided for @presetCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get presetCustom;

  /// No description provided for @ofPeopleServed.
  ///
  /// In en, this message translates to:
  /// **'of {count} people served'**
  String ofPeopleServed(int count);

  /// No description provided for @peopleServed.
  ///
  /// In en, this message translates to:
  /// **'people served'**
  String get peopleServed;

  /// No description provided for @figPortions.
  ///
  /// In en, this message translates to:
  /// **'portions'**
  String get figPortions;

  /// No description provided for @figSingle.
  ///
  /// In en, this message translates to:
  /// **'single'**
  String get figSingle;

  /// No description provided for @figFamily.
  ///
  /// In en, this message translates to:
  /// **'family portions'**
  String get figFamily;

  /// No description provided for @customDates.
  ///
  /// In en, this message translates to:
  /// **'Custom dates'**
  String get customDates;

  /// No description provided for @fromDate.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromDate;

  /// No description provided for @toDate.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toDate;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @rangeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The start date must be on or before the end date.'**
  String get rangeInvalid;

  /// No description provided for @rangeInFuture.
  ///
  /// In en, this message translates to:
  /// **'Pick dates up to today.'**
  String get rangeInFuture;

  /// No description provided for @byDay.
  ///
  /// In en, this message translates to:
  /// **'By day'**
  String get byDay;

  /// No description provided for @noStats.
  ///
  /// In en, this message translates to:
  /// **'No meals recorded in this period.'**
  String get noStats;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @ramadanKareem.
  ///
  /// In en, this message translates to:
  /// **'Ramadan Kareem'**
  String get ramadanKareem;

  /// No description provided for @noRegion.
  ///
  /// In en, this message translates to:
  /// **'No region'**
  String get noRegion;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get appearanceSystem;

  /// No description provided for @appearanceDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get appearanceDay;

  /// No description provided for @appearanceNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get appearanceNight;

  /// No description provided for @dataSection.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get dataSection;

  /// No description provided for @exportList.
  ///
  /// In en, this message translates to:
  /// **'Export fasting persons list'**
  String get exportList;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create the file.'**
  String get exportFailed;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @logoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logoutTitle;

  /// No description provided for @logoutBody.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to scan cards.'**
  String get logoutBody;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'A new version is available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available. You can keep working and update later.'**
  String updateAvailableBody(String version);

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Your version of the app is no longer supported. Please install the latest version to continue.'**
  String get updateRequiredBody;

  /// No description provided for @updateOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the browser.'**
  String get updateOpenFailed;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersion(String version);

  /// No description provided for @offlineUsingList.
  ///
  /// In en, this message translates to:
  /// **'Offline · using the list saved at {time}'**
  String offlineUsingList(String time);

  /// No description provided for @lastUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Last updated {time}'**
  String lastUpdatedAt(String time);

  /// No description provided for @offlineIndicator.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineIndicator;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
