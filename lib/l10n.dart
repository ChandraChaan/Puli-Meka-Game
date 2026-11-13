/// English and Telugu text for the app.
library;

import 'game/ai.dart';
import 'game/puli_meka.dart';

class S {
  final bool te;
  const S(this.te);

  String _(String en, String telugu) => te ? telugu : en;

  String get appName => _('Puli Meka', 'పులి మేక');
  String get tagline =>
      _('Tiger & Goats · the board game of Rayalaseema', 'పులులు & మేకలు · రాయలసీమ సంప్రదాయ ఆట');

  String get playComputer => _('Play vs Computer', 'కంప్యూటర్‌తో ఆడండి');
  String get playFriend => _('2 Players', 'ఇద్దరు ఆటగాళ్ళు');
  String get playFriendSub => _('Pass & play on one phone', 'ఒకే ఫోన్‌లో మార్చుకుంటూ ఆడండి');
  String get playComputerSub => _('Three levels of challenge', 'మూడు స్థాయిల సవాలు');
  String get playOnline => _('Play Online', 'ఆన్‌లైన్‌లో ఆడండి');
  String get playOnlineSub =>
      _('Invite a friend or find a player', 'స్నేహితుడిని పిలవండి లేదా ఆటగాడిని వెతకండి');
  String get yourName => _('Your name', 'మీ పేరు');
  String get inviteFriend => _('Invite a friend', 'స్నేహితుడిని ఆహ్వానించండి');
  String get inviteFriendSub =>
      _('Create a room and send its code', 'గది సృష్టించి దాని కోడ్ పంపండి');
  String get createRoom => _('Create room', 'గది సృష్టించండి');
  String get playAs => _('Play as', 'ఇలా ఆడండి');
  String get randomSide => _('Random', 'ఏదైనా');
  String get joinFriend => _('Join a friend', 'స్నేహితుడితో చేరండి');
  String get joinFriendSub =>
      _('Enter the 6-letter room code', '6 అక్షరాల గది కోడ్ నమోదు చేయండి');
  String get roomCode => _('Room code', 'గది కోడ్');
  String get join => _('Join', 'చేరండి');
  String get quickMatch => _('Quick match', 'త్వరిత ఆట');
  String get quickMatchSub =>
      _('Play anyone who is online now', 'ఇప్పుడు ఆన్‌లైన్‌లో ఉన్న ఎవరితోనైనా ఆడండి');
  String get findPlayer => _('Find a player', 'ఆటగాడిని వెతకండి');
  String get connecting => _('Connecting…', 'కనెక్ట్ అవుతోంది…');
  String get waitingForFriend =>
      _('Waiting for your friend to join…', 'మీ స్నేహితుడు చేరే వరకు వేచి ఉన్నాం…');
  String get shareCodeHint => _(
      'Send this code to a friend. They open Puli Meka, tap Play Online, then Join a friend.',
      'ఈ కోడ్‌ను స్నేహితుడికి పంపండి. వారు పులి మేక తెరిచి, ఆన్‌లైన్‌లో ఆడండి → స్నేహితుడితో చేరండి నొక్కాలి.');
  String shareInvite(String code, String url) => _(
      'Play Puli Meka with me! Open the app, tap Play Online → Join a friend, and enter code $code\n\nGet the app: $url',
      'నాతో పులి మేక ఆడండి! యాప్ తెరిచి, ఆన్‌లైన్‌లో ఆడండి → స్నేహితుడితో చేరండి నొక్కి, కోడ్ $code నమోదు చేయండి\n\nయాప్: $url');
  String get shareCode => _('Share code', 'కోడ్ పంపండి');
  String get copyCode => _('Copy', 'కాపీ');
  String get codeCopied => _('Code copied', 'కోడ్ కాపీ అయింది');
  String get searching => _('Looking for a player…', 'ఆటగాడి కోసం వెతుకుతున్నాం…');
  String get nobodyOnline => _(
      'Nobody else is looking right now. Keep waiting, or invite a friend.',
      'ప్రస్తుతం ఎవరూ వెతకడం లేదు. వేచి ఉండండి, లేదా స్నేహితుడిని పిలవండి.');
  String get errOffline =>
      _('No internet connection. Check it and try again.', 'ఇంటర్నెట్ లేదు. చూసి మళ్ళీ ప్రయత్నించండి.');
  String get errNotFound => _('No room has that code. Check it and try again.',
      'ఆ కోడ్‌తో గది లేదు. చూసి మళ్ళీ ప్రయత్నించండి.');
  String get errFull =>
      _('That room already has two players.', 'ఆ గదిలో ఇప్పటికే ఇద్దరు ఆటగాళ్ళు ఉన్నారు.');
  String get errOwnRoom => _('That is your own room. Send the code to a friend.',
      'అది మీ గదే. కోడ్‌ను స్నేహితుడికి పంపండి.');
  String get errUnavailable => _(
      'Online play is not available on this device.', 'ఈ పరికరంలో ఆన్‌లైన్ ఆట అందుబాటులో లేదు.');
  String get errUnknown =>
      _('Something went wrong. Please try again.', 'ఏదో పొరపాటు జరిగింది. మళ్ళీ ప్రయత్నించండి.');
  String get tryAgain => _('Try again', 'మళ్ళీ ప్రయత్నించండి');
  String get roomClosed => _('This room was closed.', 'ఈ గది మూసివేయబడింది.');
  String onlineVs(String name) => _('Online · vs $name', 'ఆన్‌లైన్ · $name తో');
  String youAre(Side side) =>
      side == Side.goat ? _('You are the Goats', 'మీరు మేకలు') : _('You are the Tigers', 'మీరు పులులు');
  String theirTurn(String name) => _('Waiting for $name…', '$name కోసం వేచి ఉన్నాం…');
  String opponentAway(String name) =>
      _('$name lost connection. Waiting for them…', '$name కనెక్షన్ పోయింది. వేచి ఉన్నాం…');
  String get claimWin => _('Claim the win', 'విజయం తీసుకోండి');
  String get resign => _('Resign', 'ఓటమి ఒప్పుకోండి');
  String get resignConfirm => _('Resign this game? Your opponent wins.',
      'ఈ ఆటలో ఓటమి ఒప్పుకోవాలా? మీ ప్రత్యర్థి గెలుస్తారు.');
  String get rematch => _('Rematch', 'మళ్ళీ ఆడదాం');
  String rematchWaiting(String name) =>
      _('Waiting for $name to accept…', '$name ఒప్పుకునే వరకు వేచి ఉన్నాం…');
  String rematchAsked(String name) =>
      _('$name wants a rematch!', '$name మళ్ళీ ఆడాలనుకుంటున్నారు!');
  String get sidesSwap => _('You swap sides each game.', 'ప్రతి ఆటకు వైపులు మారతాయి.');
  String get syncProblem => _('Connection problem. Your last move may not have been sent.',
      'కనెక్షన్ సమస్య. మీ చివరి ఎత్తు పంపబడకపోవచ్చు.');

  String get howToPlay => _('How to Play', 'ఎలా ఆడాలి');
  String get stats => _('Statistics', 'గణాంకాలు');
  String get settings => _('Settings', 'సెట్టింగ్‌లు');
  String get language => _('Language', 'భాష');
  String get soundEffects => _('Sound effects', 'శబ్ద ప్రభావాలు');
  String get vibration => _('Vibration', 'వైబ్రేషన్');
  String get captureTargetTitle => _('Goats tigers must capture', 'పులులు పట్టాల్సిన మేకలు');
  String get captureTargetSub =>
      _('Fewer makes it easier for the tigers', 'తక్కువైతే పులులకు సులభం');

  String get chooseSide => _('Choose your side', 'మీ వైపు ఎంచుకోండి');
  String get difficulty => _('Difficulty', 'కష్టతరం');
  String get start => _('Start Game', 'ఆట ప్రారంభించండి');

  String difficultyName(Difficulty d) => switch (d) {
        Difficulty.easy => _('Easy', 'సులభం'),
        Difficulty.medium => _('Medium', 'మధ్యస్థం'),
        Difficulty.hard => _('Hard', 'కఠినం'),
      };

  String sideName(Side s) => s == Side.goat ? _('Goats', 'మేకలు') : _('Tigers', 'పులులు');
  String sideBlurb(Side s) => s == Side.goat
      ? _('15 goats. Trap all the tigers.', '15 మేకలు. పులులను బంధించండి.')
      : _('3 tigers. Hunt the goats.', '3 పులులు. మేకలను వేటాడండి.');

  String get you => _('You', 'మీరు');
  String get computer => _('Computer', 'కంప్యూటర్');
  String player(int n) => _('Player $n', 'ఆటగాడు $n');

  String inHand(int n) => _('$n in hand', 'చేతిలో $n');
  String captured(int n, int target) => _('Captured $n / $target', 'పట్టినవి $n / $target');
  String trapped(int n) => _('$n trapped', '$n బంధించబడ్డాయి');

  String get placeGoat => _('Place a goat on any empty point', 'ఏదైనా ఖాళీ బిందువుపై మేకను ఉంచండి');
  String get moveGoat => _('Move a goat along a line', 'గీత వెంబడి ఒక మేకను కదపండి');
  String get moveTiger =>
      _('Move a tiger, or jump a goat to capture', 'పులిని కదపండి, లేదా మేకపై దూకి పట్టండి');
  String get mustCapture => _('A tiger can capture! Watch out', 'పులి మేకను పట్టగలదు! జాగ్రత్త');
  String get thinking => _('Computer is thinking…', 'కంప్యూటర్ ఆలోచిస్తోంది…');
  String turnOf(String who) => _("$who's turn", '$who వంతు');
  String get yourTurn => _('Your turn', 'మీ వంతు');
  String get allGoatsPlaced =>
      _('All 15 goats are out!\nNow move them along the lines', 'మొత్తం 15 మేకలు బయటకొచ్చాయి!\nఇప్పుడు గీతల వెంబడి కదపండి');
  String get oneMoreCapture =>
      _('One more capture and the tigers win!', 'ఇంకొక్క మేకను పడితే పులులు గెలుస్తాయి!');

  String pointLabel(int point, int cell) {
    final what = switch (cell) {
      Cell.tiger => _('tiger', 'పులి'),
      Cell.goat => _('goat', 'మేక'),
      _ => _('empty', 'ఖాళీ'),
    };
    return _('Point ${point + 1}, $what', 'బిందువు ${point + 1}, $what');
  }

  String get undo => _('Undo', 'వెనక్కి');
  String get hint => _('Hint', 'సూచన');
  String get restart => _('Restart', 'మళ్ళీ');
  String get restartConfirm => _('Start a new game?', 'కొత్త ఆట ప్రారంభించాలా?');
  String get leaveGame => _('Leave this game?', 'ఈ ఆటను వదిలేయాలా?');
  String get leave => _('Leave', 'వదిలేయండి');
  String get cancel => _('Cancel', 'రద్దు');
  String get ok => _('Yes', 'అవును');

  String get youWin => _('You win!', 'మీరు గెలిచారు!');
  String get youLose => _('You lost', 'మీరు ఓడిపోయారు');
  String get draw => _("It's a draw", 'ఆట సమం');
  String winnerTitle(Side s) =>
      s == Side.tiger ? _('Tigers win!', 'పులులు గెలిచాయి!') : _('Goats win!', 'మేకలు గెలిచాయి!');
  String reason(OutcomeReason r, int target) => switch (r) {
        OutcomeReason.captures =>
          _('The tigers captured $target goats.', 'పులులు $target మేకలను పట్టాయి.'),
        OutcomeReason.tigersTrapped =>
          _('All three tigers are trapped.', 'మూడు పులులూ కదలలేకుండా బంధించబడ్డాయి.'),
        OutcomeReason.goatsTrapped => _('The goats have no move left.', 'మేకలకు కదలిక లేదు.'),
        OutcomeReason.repetition =>
          _('The same position came up three times.', 'ఒకే స్థితి మూడు సార్లు వచ్చింది.'),
        OutcomeReason.forfeit => _('A player left the game.', 'ఒక ఆటగాడు ఆట వదిలేశారు.'),
      };
  String get opponentLeftReason =>
      _('Your opponent left the game.', 'మీ ప్రత్యర్థి ఆట వదిలేశారు.');
  String get youResignedReason => _('You resigned.', 'మీరు ఓటమి ఒప్పుకున్నారు.');
  String movesPlayed(int n) => _('$n moves', '$n ఎత్తులు');
  String get playAgain => _('Play again', 'మళ్ళీ ఆడండి');
  String get home => _('Home', 'హోమ్');
  String get review => _('View board', 'బోర్డు చూడండి');

  String get statsVsComputer => _('Against the computer', 'కంప్యూటర్‌తో');
  String get played => _('Played', 'ఆడినవి');
  String get won => _('Won', 'గెలిచినవి');
  String get lost => _('Lost', 'ఓడినవి');
  String get drawn => _('Draws', 'సమం');
  String get asGoats => _('As goats', 'మేకలుగా');
  String get asTigers => _('As tigers', 'పులులుగా');
  String get streak => _('Best win streak', 'వరుస విజయాలు (ఉత్తమం)');
  String get resetStats => _('Reset statistics', 'గణాంకాలను తుడిచివేయండి');
  String get noGamesYet => _('No games yet. Go play!', 'ఇంకా ఆటలు లేవు. ఆడండి!');

  String get rulesTitle => _('Rules', 'నియమాలు');
  String get tipsTitle => _('Tips', 'చిట్కాలు');
  String get diagramStart => _('Starting position', 'ప్రారంభ స్థితి');
  String get diagramJump =>
      _('A tiger jumps a goat to capture it', 'పులి మేకపై దూకి పట్టుకుంటుంది');
  String get diagramTrap => _('Goats trap a tiger', 'మేకలు పులిని బంధిస్తాయి');
  String get aboutTitle => _('About the game', 'ఆట గురించి');

  List<String> rules(int target) => te
      ? [
          'బోర్డుపై 23 బిందువులు ఉంటాయి. 3 పులులు పై భాగంలో మొదలవుతాయి; 15 మేకలు బోర్డు బయట చేతిలో ఉంటాయి.',
          'మేకలు ముందుగా ఆడతాయి. ప్రతి వంతులో ఒక మేకను ఏదైనా ఖాళీ బిందువుపై ఉంచాలి. 15 మేకలూ ఉంచిన తర్వాతే మేకలను కదపవచ్చు.',
          'ఏ ముక్క అయినా గీత వెంబడి పక్కనే ఉన్న ఖాళీ బిందువుకు ఒక అడుగు కదలవచ్చు.',
          'పులి పక్కనే ఉన్న మేకపై నుండి సరళ రేఖలో దాని వెనుక ఉన్న ఖాళీ బిందువుకు దూకి ఆ మేకను పట్టుకుంటుంది. ఒక వంతులో ఒక్క దూకు మాత్రమే.',
          'మేకలు దూకలేవు, పులులను పట్టుకోలేవు.',
          'పులులు $target మేకలను పట్టుకుంటే గెలుస్తాయి. మూడు పులులూ కదలలేకుండా బంధిస్తే మేకలు గెలుస్తాయి.',
          'ఒకే స్థితి మూడు సార్లు వస్తే ఆట సమం (డ్రా) అవుతుంది.',
        ]
      : [
          'The board has 23 points. The 3 tigers start at the top; the 15 goats start in hand, off the board.',
          'Goats move first. Each turn the goat player places one goat on any empty point. Goats may only move once all 15 are placed.',
          'Any piece may step along a line to a neighbouring empty point.',
          'A tiger captures by jumping over an adjacent goat, in a straight line, onto the empty point right behind it. Only one jump per turn.',
          'Goats can never jump or capture.',
          'Tigers win by capturing $target goats. Goats win by trapping all three tigers so none can move.',
          'If the same position comes up three times, the game is a draw.',
        ];

  List<String> get tips => te
      ? [
          'మేకలు: ముందుగా అంచులు, కింది వరుసను నింపండి. అక్కడ మేకలు సురక్షితం.',
          'మేకలు: మేక వెనుక ఖాళీ బిందువు ఉంటే పులి దూకగలదు. ఎప్పుడూ వెనుక వైపు కాపు ఉంచండి.',
          'మేకలు: జంటలుగా, గుంపుగా కదలండి. ఒంటరి మేక పులికి ఆహారం.',
          'పులులు: మధ్యలో ఉండండి, ఎక్కువ గీతలు కలిసే చోట పులికి బలం.',
          'పులులు: ఒకేసారి రెండు మేకలను బెదిరించండి. మేకలు రెండింటినీ కాపాడలేవు.',
        ]
      : [
          'Goats: fill the edges and the bottom row first. Goats are safest there.',
          'Goats: a tiger can only jump into an empty point. Always guard the point behind your goats.',
          'Goats: move in pairs and blocks. A lonely goat is a tiger\'s lunch.',
          'Tigers: stay central. Points where many lines meet give a tiger the most options.',
          'Tigers: threaten two goats at once. The goats cannot cover both.',
        ];

  String get aboutApp => _('About', 'గురించి');
  String get aboutThisApp => _('About this app', 'ఈ యాప్ గురించి');
  String version(String v) => _('Version $v', 'వెర్షన్ $v');
  String get madeIn => _('Made with ❤️ in Kadapa', 'కడపలో ❤️ తో తయారైంది');
  String get appIntro => _(
      'A free, ad-free digital version of the game we grew up playing on village verandahs. '
          'No account needed: just open it and play, offline or online with a friend.',
      'అరుగులపై ఆడుకున్న మన ఆటకు ఉచిత, ప్రకటనలు లేని డిజిటల్ రూపం. '
          'ఖాతా అవసరం లేదు: తెరిచి ఆడండి, ఇంటర్నెట్ లేకుండా లేదా స్నేహితుడితో ఆన్‌లైన్‌లో.');
  String get alsoKnownAs => _('Also known as', 'ఇతర పేర్లు');
  List<(String, String)> get otherNames => [
        (_('Aadu Puli Aattam', 'ఆడు పులి ఆట్టం'), _('Tamil Nadu', 'తమిళనాడు')),
        (_('Aadu Huli', 'ఆడు హులి'), _('Karnataka', 'కర్ణాటక')),
        (_('Bagh-Chal (a cousin)', 'బాఘ్-చాల్ (బంధువు ఆట)'), _('Nepal', 'నేపాల్')),
      ];
  String get featuresTitle => _('What\'s inside', 'ఇందులో ఏముంది');
  List<String> get features => te
      ? [
          'కంప్యూటర్‌తో మూడు స్థాయిల్లో, మేకలుగా లేదా పులులుగా ఆడండి',
          'ఒకే ఫోన్‌లో ఇద్దరు ఆటగాళ్ళు',
          'గది కోడ్‌తో స్నేహితులతో, లేదా త్వరిత ఆటలో ఎవరితోనైనా ఆన్‌లైన్‌లో ఆడండి',
          'సూచనలు, అపరిమిత వెనక్కి, ప్రమాద హెచ్చరికలు',
          'పూర్తిగా తెలుగు, ఇంగ్లీష్‌లో',
          'గణాంకాలు, వరుస విజయాలు',
        ]
      : [
          'Play the computer as goats or tigers, at three levels',
          'Pass-and-play for two on one phone',
          'Play friends online with a room code, or anyone with quick match',
          'Hints, unlimited undo and danger warnings',
          'Fully in Telugu and English',
          'Statistics and win streaks',
        ];
  String get privacyTitle => _('Privacy', 'గోప్యత');
  String get privacy => _(
      'No ads, no tracking, no account. Your settings and statistics are stored only on this device. '
          'Online games use Google Firebase: you are signed in anonymously (no email or phone number), '
          'and the room code, the name you type and the moves are stored so both players can see them. '
          'Nothing is sent unless you play online.',
      'ప్రకటనలు లేవు, ట్రాకింగ్ లేదు, ఖాతా లేదు. మీ సెట్టింగ్‌లు, గణాంకాలు ఈ పరికరంలో మాత్రమే ఉంటాయి. '
          'ఆన్‌లైన్ ఆటలకు Google Firebase వాడతాం: పేరు లేకుండా (ఈమెయిల్, ఫోన్ నంబర్ లేకుండా) సైన్ ఇన్ అవుతారు, '
          'ఇద్దరూ చూడగలిగేలా గది కోడ్, మీరు టైప్ చేసిన పేరు, ఎత్తులు నిల్వ అవుతాయి. '
          'ఆన్‌లైన్‌లో ఆడితేనే ఏదైనా పంపబడుతుంది.');
  String get linksTitle => _('Share & support', 'పంచుకోండి & సహాయం');
  String get shareApp => _('Share with friends', 'స్నేహితులతో పంచుకోండి');
  String get shareAppSub => _('Challenge someone to a game', 'ఎవరినైనా ఆటకు సవాలు చేయండి');
  String shareMessage(String url) => _(
      'Play Puli Meka (Tiger & Goats), the board game of Rayalaseema! Download: $url',
      'రాయలసీమ ఆట పులి మేక ఆడండి! డౌన్‌లోడ్: $url');
  String get latestVersion => _('Get the latest version', 'తాజా వెర్షన్ పొందండి');
  String get latestVersionSub => _('Download the newest APK', 'కొత్త APK డౌన్‌లోడ్ చేయండి');
  String get reportProblem => _('Report a problem or idea', 'సమస్య లేదా ఆలోచన తెలపండి');
  String get reportProblemSub => _('Opens GitHub issues', 'GitHub issues తెరుస్తుంది');
  String get sourceCode => _('Source code', 'సోర్స్ కోడ్');
  String get sourceCodeSub => _('The whole app is open on GitHub', 'యాప్ మొత్తం GitHubలో ఉంది');
  String get licenses => _('Open-source licences', 'ఓపెన్-సోర్స్ లైసెన్సులు');
  String get creditsTitle => _('Credits', 'కృతజ్ఞతలు');
  String get credits => _(
      'Built with Flutter by ChandraChaan. Thanks to every grandparent who drew this board in chalk '
          'and taught the next generation to play.',
      'Flutterతో ChandraChaan రూపొందించారు. సుద్దతో ఈ బోర్డు గీసి తర్వాతి తరానికి ఆట నేర్పిన '
          'ప్రతి తాతయ్య, అమ్మమ్మకు కృతజ్ఞతలు.');
  String get linkFailed => _('Could not open the link', 'లింక్ తెరవలేకపోయాం');
  String get linkCopied =>
      _('Link copied. Paste it to a friend!', 'లింక్ కాపీ అయింది. స్నేహితులకు పంపండి!');

  String get about => te
      ? 'పులి మేక తరతరాలుగా రాయలసీమ, కడప గ్రామాల్లో ఆడే ఆట. అరుగులపై, నేలపై సుద్దతో లేదా పుల్లతో బోర్డు గీసి, రాళ్ళు, చింతగింజలతో ఆడతారు. ఇదే ఆటను తమిళనాడులో "ఆడు పులి ఆట్టం", కర్ణాటకలో "ఆడు హులి" అని పిలుస్తారు. ఇది ఓర్పు, ముందుచూపు నేర్పే ఆట.'
      : 'Puli Meka has been played for generations in the villages of Kadapa and Rayalaseema. The board is drawn with chalk or a stick on the floor or a stone verandah, and played with pebbles and tamarind seeds. The same game is called Aadu Puli Aattam in Tamil Nadu and Aadu Huli in Karnataka. It is a game of patience and foresight.';
}
