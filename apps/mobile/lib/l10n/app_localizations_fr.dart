// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'إفطار صائم';

  @override
  String get appSubtitle => 'Distribution d’iftar pour bénévoles';

  @override
  String get hadithMeaning =>
      'Celui qui donne l’iftar à un jeûneur partage sa récompense';

  @override
  String get blessingMeaning => 'Qu’Allah l’accepte';

  @override
  String get signIn => 'Se connecter';

  @override
  String get createVolunteerAccount => 'Créer un compte bénévole';

  @override
  String get welcomeBack => 'Bon retour';

  @override
  String get loginLead =>
      'Connectez-vous pour servir ce soir dans votre région.';

  @override
  String get registerTitle => 'Rejoindre les bénévoles';

  @override
  String get registerLead => 'Chaque bénévole sert une région.';

  @override
  String get username => 'Nom d’utilisateur';

  @override
  String get password => 'Mot de passe';

  @override
  String get fullName => 'Nom';

  @override
  String get email => 'E-mail';

  @override
  String get region => 'Région';

  @override
  String get chooseRegion => 'Choisissez votre région';

  @override
  String get loadingRegions => 'Chargement des régions…';

  @override
  String get regionsFailed => 'Impossible de charger les régions';

  @override
  String get showPassword => 'Afficher le mot de passe';

  @override
  String get hidePassword => 'Masquer le mot de passe';

  @override
  String get usernameRequired => 'Le nom d’utilisateur est obligatoire.';

  @override
  String get passwordRequired => 'Le mot de passe est obligatoire.';

  @override
  String get nameRequired => 'Le nom est obligatoire.';

  @override
  String get emailRequired => 'L’e-mail est obligatoire.';

  @override
  String get emailInvalid => 'Saisissez une adresse e-mail valide.';

  @override
  String get passwordTooShort => 'Au moins 6 caractères.';

  @override
  String get regionRequired => 'La région est obligatoire.';

  @override
  String get newVolunteerCreateAccount => 'Nouveau bénévole ? Créer un compte';

  @override
  String get haveAccountSignIn => 'Déjà bénévole ? Se connecter';

  @override
  String get accountCreated => 'Compte créé. Vous pouvez vous connecter.';

  @override
  String get signUp => 'Créer le compte';

  @override
  String get errLoginFailed => 'Nom d’utilisateur ou mot de passe incorrect.';

  @override
  String get errAccountDisabled => 'Ce compte a été désactivé.';

  @override
  String get errNetwork =>
      'Pas de connexion internet. Vérifiez votre réseau et réessayez.';

  @override
  String get errTimeout =>
      'Le serveur met trop de temps à répondre. Réessayez.';

  @override
  String get errSessionExpired => 'Votre session a expiré. Reconnectez-vous.';

  @override
  String get errForbidden => 'Vous n’êtes pas autorisé à faire cette action.';

  @override
  String get errNotFound => 'Introuvable.';

  @override
  String get errServer =>
      'Un problème est survenu sur le serveur. Réessayez dans un instant.';

  @override
  String get errUnknown => 'Erreur inattendue. Réessayez.';

  @override
  String get errNoRegion =>
      'Aucune région n’est attribuée à votre compte. Contactez un administrateur.';

  @override
  String get errUsernameTaken =>
      'Ce nom d’utilisateur ou cet e-mail est déjà utilisé.';

  @override
  String get titleOffline => 'Vous êtes hors ligne';

  @override
  String get titleSlow => 'Le serveur est lent';

  @override
  String get titleServerError => 'Erreur du serveur';

  @override
  String get titleSignedOut => 'Déconnecté';

  @override
  String get titleNotFound => 'Introuvable';

  @override
  String get titleGenericError => 'Un problème est survenu';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get retry => 'Réessayer';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get edit => 'Modifier';

  @override
  String get back => 'Retour';

  @override
  String get loading => 'Chargement des données';

  @override
  String get increase => 'Augmenter';

  @override
  String get decrease => 'Diminuer';

  @override
  String get navPeople => 'Personnes';

  @override
  String get navAdd => 'Ajouter';

  @override
  String get navStats => 'Stats';

  @override
  String get navProfile => 'Profil';

  @override
  String get navScan => 'Scanner une carte';

  @override
  String ramadanDay(String day) {
    return 'Ramadan $day';
  }

  @override
  String get peopleTitle => 'Personnes inscrites';

  @override
  String peopleCount(String total, String served) {
    return '$total inscrits · $served servis aujourd’hui';
  }

  @override
  String get searchPeople => 'Rechercher par nom, n° ou CIN';

  @override
  String get clearSearch => 'Effacer la recherche';

  @override
  String get filterAll => 'Tous';

  @override
  String get filterWaiting => 'En attente';

  @override
  String get filterServed => 'Servis';

  @override
  String get noPeopleTitle => 'Aucune personne inscrite';

  @override
  String get noPeopleMessage =>
      'Ajoutez la première personne pour commencer la distribution.';

  @override
  String get addPerson => 'Ajouter une personne';

  @override
  String get everyoneServed => 'Tout le monde a été servi ce soir.';

  @override
  String get nobodyServedYet => 'Personne n’a encore été servi ce soir.';

  @override
  String noMatch(String query) {
    return 'Personne ne correspond à « $query ».';
  }

  @override
  String get searchTip => 'Recherchez par nom, n°, CIN ou téléphone.';

  @override
  String get offlineLastList =>
      'Hors ligne. Affichage de la dernière liste chargée.';

  @override
  String mealSingleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count individuels',
      one: '$count individuel',
    );
    return '$_temp0';
  }

  @override
  String mealFamilyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count familles',
      one: '$count famille',
    );
    return '$_temp0';
  }

  @override
  String get servedTooltip => 'Servi aujourd’hui';

  @override
  String get notServedTooltip => 'Pas encore servi aujourd’hui';

  @override
  String portions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portions',
      one: '$count portion',
    );
    return '$_temp0';
  }

  @override
  String get addTitle => 'Nouvelle personne';

  @override
  String get addSubtitle => 'Scannez d’abord la carte, elle remplit le n°';

  @override
  String get editTitle => 'Modifier la personne';

  @override
  String get cardId => 'N° de carte';

  @override
  String get scanCard => 'Scanner';

  @override
  String cardRead(String id) {
    return 'Carte lue : n° $id';
  }

  @override
  String get cardScanTitle => 'Scannez la carte';

  @override
  String get cardInvalid => 'Ce code n’est pas un n° de carte.';

  @override
  String get idRequired => 'Scannez ou saisissez le n° de carte';

  @override
  String get idInvalid => 'Le n° de carte doit être un nombre entier positif';

  @override
  String get idTaken => 'Ce n° de carte est déjà inscrit';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get firstNameRequired => 'Ajoutez un prénom';

  @override
  String get lastNameRequired => 'Ajoutez un nom';

  @override
  String get cinLabel => 'CIN (8 chiffres)';

  @override
  String get cinLength => 'La CIN compte 8 chiffres';

  @override
  String duplicateCin(String name, String id) {
    return 'Même CIN que $name (n° $id). Est-ce la même personne ?';
  }

  @override
  String get openExistingRecord => 'Ouvrir la fiche existante';

  @override
  String get mealsEachEvening => 'Repas chaque soir';

  @override
  String get singleMeal => 'Repas individuel';

  @override
  String get familyMeal => 'Repas famille';

  @override
  String handsOverEachEvening(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portions',
      one: '$count portion',
    );
    return 'Remet $_temp0 chaque soir';
  }

  @override
  String get mealsAtLeastOne => 'Choisissez au moins un repas';

  @override
  String get hereNow => 'Présent maintenant';

  @override
  String get hereNowSubtitle => 'Remettre le repas de ce soir et l’enregistrer';

  @override
  String get optionalFields => 'Téléphone et notes (facultatif)';

  @override
  String get phone => 'Téléphone';

  @override
  String get notes => 'Notes';

  @override
  String get saveAndHandOver => 'Enregistrer et remettre';

  @override
  String get saveAndAddAnother => 'Enregistrer et ajouter';

  @override
  String get updatePerson => 'Mettre à jour';

  @override
  String get deletePerson => 'Supprimer la personne';

  @override
  String get deleteTitle => 'Supprimer cette personne ?';

  @override
  String deleteBody(String name) {
    return '$name sera retiré de la liste des personnes inscrites.';
  }

  @override
  String get delete => 'Supprimer';

  @override
  String personSaved(String name) {
    return '$name enregistré.';
  }

  @override
  String personSavedHandOver(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portions',
      one: '$count portion',
    );
    return '$name enregistré. Remettez $_temp0.';
  }

  @override
  String get personUpdated => 'Personne mise à jour.';

  @override
  String personDeleted(String name) {
    return '$name supprimé.';
  }

  @override
  String get detailsTitle => 'Détails de la personne';

  @override
  String get identity => 'Identité';

  @override
  String get meals => 'Repas';

  @override
  String get identifier => 'N° de carte';

  @override
  String get cinShortLabel => 'CIN';

  @override
  String lastMeal(String date) {
    return 'Dernier repas : $date';
  }

  @override
  String get mealToday => 'Ce soir';

  @override
  String get confirmMeal => 'Confirmer le repas';

  @override
  String get alreadyServedToday => 'Déjà servi aujourd’hui';

  @override
  String mealHistory(int count) {
    return 'Historique des repas ($count)';
  }

  @override
  String mealHistoryTitle(String name) {
    return 'Repas reçus par $name';
  }

  @override
  String get noMealsYet => 'Aucun repas reçu pour l’instant.';

  @override
  String get mealConfirmed => 'Repas confirmé.';

  @override
  String get alreadyCollected => 'Déjà retiré aujourd’hui.';

  @override
  String alreadyCollectedAt(String time) {
    return 'Déjà retiré aujourd’hui à $time.';
  }

  @override
  String get editContact => 'Modifier le téléphone et le commentaire';

  @override
  String get contactTitle => 'Téléphone et commentaire';

  @override
  String get comment => 'Commentaire';

  @override
  String get scanTitle => 'Scanner la carte';

  @override
  String servedTonight(int count) {
    return '$count servis ce soir';
  }

  @override
  String get torchOn => 'Allumer la lampe';

  @override
  String get torchOff => 'Éteindre la lampe';

  @override
  String get closeScanner => 'Fermer le scanner';

  @override
  String get scanHint => 'Placez la carte dans l’arche';

  @override
  String get findNoCard => 'Trouver une personne sans carte';

  @override
  String get findNoCardSubtitle => 'Par nom, CIN ou téléphone';

  @override
  String get checkingStatus => 'Vérification du statut de ce soir…';

  @override
  String lookingUp(int id) {
    return 'Recherche du n° $id…';
  }

  @override
  String get notServedTonight => 'Pas encore servi ce soir';

  @override
  String get handOver => 'À remettre';

  @override
  String get none => 'aucun';

  @override
  String get confirmHandOver => 'Confirmer la remise';

  @override
  String get confirming => 'Confirmation…';

  @override
  String get sendingSlow => 'Envoi… connexion lente';

  @override
  String get skip => 'Passer';

  @override
  String get details => 'Détails';

  @override
  String noCardCheck(String digits) {
    return 'Sans carte : demandez la CIN finissant par $digits';
  }

  @override
  String get noCinOnFile =>
      'Aucun numéro de CIN enregistré — vérifiez une autre pièce.';

  @override
  String servedLine(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portions',
      one: '$count portion',
    );
    return 'Servi : $name · $_temp0';
  }

  @override
  String get alreadyServedTonight => 'Déjà servi ce soir';

  @override
  String get cantCheckTonight => 'Impossible de vérifier ce soir';

  @override
  String lastSyncNotServed(String time) {
    return 'Dernière synchro $time : pas encore servi';
  }

  @override
  String asOfTime(String time) {
    return '(à $time)';
  }

  @override
  String notOnPhoneTitle(int id) {
    return 'La carte n°$id n’est pas sur ce téléphone';
  }

  @override
  String get notOnPhoneMessage =>
      'Pas de connexion, et cette carte n’est pas dans la liste enregistrée sur ce téléphone.';

  @override
  String alreadyServedNote(String time) {
    return 'Rien à remettre. Indiquez-lui avec douceur que le repas a été retiré à $time.';
  }

  @override
  String get alreadyServedNoteNoTime =>
      'Rien à remettre. Indiquez-lui avec douceur que le repas a déjà été retiré ce soir.';

  @override
  String undoCountdown(int seconds) {
    return 'Annuler · $seconds';
  }

  @override
  String undone(String name) {
    return 'Annulé. $name n’est plus marqué comme servi.';
  }

  @override
  String get undoFailed =>
      'Impossible d’annuler. Réessayez depuis l’historique.';

  @override
  String get undoTooLate =>
      'Il est trop tard pour annuler. Demandez à un administrateur.';

  @override
  String get undoNeedsConnection =>
      'L’annulation nécessite une connexion. Réessayez depuis l’historique.';

  @override
  String servedAtBy(String time, String name) {
    return 'Servi à $time par $name';
  }

  @override
  String get undoTonightsMeal => 'Annuler le repas de ce soir';

  @override
  String servedBy(String name) {
    return 'par $name';
  }

  @override
  String get scanNextCard => 'Carte suivante';

  @override
  String get history => 'Historique';

  @override
  String unknownCardTitle(int id) {
    return 'La carte n° $id n’est pas inscrite';
  }

  @override
  String unknownCardMessage(String region) {
    return 'Personne n’a cette carte à $region.';
  }

  @override
  String get registerThisCard => 'Inscrire cette carte';

  @override
  String get scanAgain => 'Scanner à nouveau';

  @override
  String get invalidCodeTitle => 'Ce code est illisible';

  @override
  String get invalidCodeMessage =>
      'Ce n’est pas une carte Iftar Saem, ou elle est abîmée.';

  @override
  String get notConfirmedYet => 'Pas encore confirmé';

  @override
  String get dontHandOverYet => 'Ne remettez rien avant la confirmation';

  @override
  String get notConfirmedExplanation =>
      'Le repas n’est confirmé que lorsque le serveur répond. Réessayez, et ne servez pas deux fois.';

  @override
  String get cameraOffTitle => 'L’accès à la caméra est désactivé';

  @override
  String get cameraOffMessage =>
      'Autorisez l’accès à la caméra dans les réglages du téléphone pour scanner les cartes. Vous pouvez toujours trouver une personne sans carte.';

  @override
  String get cameraOpenSettings => 'Ouvrir les paramètres';

  @override
  String get cameraUnavailableTitle => 'Caméra indisponible';

  @override
  String get cameraUnavailableMessage =>
      'La caméra n’a pas pu démarrer. Vous pouvez toujours trouver une personne sans carte.';

  @override
  String get sealServe => 'Peut être servi';

  @override
  String get sealServed => 'Déjà servi';

  @override
  String get sealChecking => 'Vérification';

  @override
  String get sealProblem => 'À vérifier';

  @override
  String get sealDone => 'Servi';

  @override
  String get findTitle => 'Sans carte';

  @override
  String get findSearchHint => 'Nom, CIN, n° ou téléphone';

  @override
  String get findMinChars =>
      'Tapez 2 lettres ou un numéro. Les résultats viennent du téléphone.';

  @override
  String findLookUpId(int id) {
    return 'Chercher la carte n° $id';
  }

  @override
  String get summaryKicker => 'Ce soir';

  @override
  String get summaryServedByYou => 'iftars servis par vous';

  @override
  String summaryDetail(int family, int single, int portions) {
    return '$family famille · $single individuel · $portions portions';
  }

  @override
  String get backToPeople => 'Retour à la liste';

  @override
  String get keepScanning => 'Continuer à scanner';

  @override
  String get statsTitle => 'Statistiques';

  @override
  String get presetTonight => 'Ce soir';

  @override
  String get presetWeek => 'Cette semaine';

  @override
  String get presetRamadan => 'Ramadan';

  @override
  String get presetCustom => 'Personnalisé';

  @override
  String ofPeopleServed(int count) {
    return 'sur $count personnes servies';
  }

  @override
  String get peopleServed => 'personnes servies';

  @override
  String get figPortions => 'portions';

  @override
  String get figSingle => 'individuels';

  @override
  String get figFamily => 'portions famille';

  @override
  String get customDates => 'Dates personnalisées';

  @override
  String get fromDate => 'Du';

  @override
  String get toDate => 'Au';

  @override
  String get apply => 'Appliquer';

  @override
  String get rangeInvalid =>
      'La date de début doit précéder ou égaler la date de fin.';

  @override
  String get rangeInFuture => 'Choisissez des dates jusqu’à aujourd’hui.';

  @override
  String get byDay => 'Par jour';

  @override
  String get noStats => 'Aucun repas enregistré sur cette période.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get ramadanKareem => 'Ramadan Kareem';

  @override
  String get noRegion => 'Aucune région';

  @override
  String get settings => 'Réglages';

  @override
  String get language => 'Langue';

  @override
  String get appearance => 'Apparence';

  @override
  String get appearanceSystem => 'Système';

  @override
  String get appearanceDay => 'Jour';

  @override
  String get appearanceNight => 'Nuit';

  @override
  String get dataSection => 'Données';

  @override
  String get exportList => 'Exporter la liste des personnes';

  @override
  String get exportFailed => 'Impossible de créer le fichier.';

  @override
  String get logout => 'Se déconnecter';

  @override
  String get logoutTitle => 'Se déconnecter ?';

  @override
  String get logoutBody =>
      'Vous devrez vous reconnecter pour scanner les cartes.';

  @override
  String get updateAvailableTitle => 'Une nouvelle version est disponible';

  @override
  String updateAvailableBody(String version) {
    return 'La version $version est disponible. Vous pouvez continuer et mettre à jour plus tard.';
  }

  @override
  String get updateNow => 'Mettre à jour';

  @override
  String get updateLater => 'Plus tard';

  @override
  String get updateRequiredTitle => 'Mise à jour requise';

  @override
  String get updateRequiredBody =>
      'Votre version de l\'application n\'est plus prise en charge. Installez la dernière version pour continuer.';

  @override
  String get updateOpenFailed => 'Impossible d\'ouvrir le navigateur.';

  @override
  String appVersion(String version) {
    return 'Version $version';
  }

  @override
  String offlineUsingList(String time) {
    return 'Hors ligne · liste enregistrée à $time';
  }

  @override
  String lastUpdatedAt(String time) {
    return 'Mis à jour à $time';
  }

  @override
  String get offlineIndicator => 'Hors ligne';
}
