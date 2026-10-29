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
  String get howToPlay => _('How to Play', 'ఎలా ఆడాలి');
  String get stats => _('Statistics', 'గణాంకాలు');
  String get settings => _('Settings', 'సెట్టింగ్‌లు');
  String get language => _('Language', 'భాష');
  String get soundVibration => _('Sound & vibration', 'శబ్దం & వైబ్రేషన్');
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
      };
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

  String get about => te
      ? 'పులి మేక తరతరాలుగా రాయలసీమ, కడప గ్రామాల్లో ఆడే ఆట. అరుగులపై, నేలపై సుద్దతో లేదా పుల్లతో బోర్డు గీసి, రాళ్ళు, చింతగింజలతో ఆడతారు. ఇదే ఆటను తమిళనాడులో "ఆడు పులి ఆట్టం", కర్ణాటకలో "ఆడు హులి" అని పిలుస్తారు. ఇది ఓర్పు, ముందుచూపు నేర్పే ఆట.'
      : 'Puli Meka has been played for generations in the villages of Kadapa and Rayalaseema. The board is drawn with chalk or a stick on the floor or a stone verandah, and played with pebbles and tamarind seeds. The same game is called Aadu Puli Aattam in Tamil Nadu and Aadu Huli in Karnataka. It is a game of patience and foresight.';
}
