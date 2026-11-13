import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../game/puli_meka.dart';
import '../l10n.dart';
import '../main.dart';
import '../online/backend.dart';
import '../online/online_services.dart';
import '../online/online_session.dart';
import '../online/room.dart';
import '../theme.dart';
import '../widgets/board_view.dart';
import '../widgets/decorations.dart';
import 'about_screen.dart';
import 'game_screen.dart';

enum _Phase { connecting, menu, busy, waiting, searching, unavailable }

/// Where players set their name and create, join or find an online game.
class OnlineLobbyScreen extends StatefulWidget {
  const OnlineLobbyScreen({super.key});

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen> {
  _Phase _phase = _Phase.connecting;
  OnlineBackend? _backend;
  String? _uid;
  OnlineSession? _session;
  OnlineErrorKind? _error;

  late final TextEditingController _name;
  final _code = TextEditingController();

  /// null = random.
  Side? _side;

  Timer? _matchTimer;
  DateTime? _searchStarted;
  bool _handedOver = false;

  @override
  void initState() {
    super.initState();
    final settings = SettingsScope.read(context);
    var name = settings.onlineName;
    if (name.isEmpty) {
      name = settings.s.player(1000 + math.Random().nextInt(9000));
    }
    _name = TextEditingController(text: name);
    _connect();
  }

  Future<void> _connect() async {
    setState(() {
      _phase = _Phase.connecting;
      _error = null;
    });
    try {
      final backend = await OnlineServices.backend();
      final uid = await backend.signIn();
      if (!mounted) return;
      setState(() {
        _backend = backend;
        _uid = uid;
        _phase = _Phase.menu;
      });
    } on OnlineError catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = e.kind == OnlineErrorKind.unavailable ? _Phase.unavailable : _Phase.menu;
        _error = e.kind;
      });
    }
  }

  @override
  void dispose() {
    _matchTimer?.cancel();
    final session = _session;
    if (session != null && !_handedOver) {
      // Leaving the lobby cancels a room nobody has joined yet.
      session.removeListener(_onSession);
      unawaited(session.leave());
      session.dispose();
    }
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _playerName {
    final n = _name.text.trim();
    return n.isEmpty ? 'Player' : (n.length > 20 ? n.substring(0, 20) : n);
  }

  void _saveName() => SettingsScope.read(context).setOnlineName(_playerName);

  Future<void> _run(Future<void> Function(OnlineBackend backend) action) async {
    final backend = _backend;
    if (backend == null) {
      await _connect();
      return;
    }
    _saveName();
    FocusScope.of(context).unfocus();
    setState(() {
      _phase = _Phase.busy;
      _error = null;
    });
    try {
      await action(backend);
    } on OnlineError catch (e) {
      if (!mounted) return;
      _matchTimer?.cancel();
      setState(() {
        _phase = _Phase.menu;
        _error = e.kind;
      });
    }
  }

  void _attach(Room room) {
    final old = _session;
    if (old != null) {
      old.removeListener(_onSession);
      old.dispose();
    }
    final session = OnlineSession(backend: _backend!, uid: _uid!)..addListener(_onSession);
    _session = session;
    session.attach(room);
  }

  void _onSession() {
    final session = _session;
    if (session == null || !mounted || _handedOver) return;
    if (session.closed) {
      _matchTimer?.cancel();
      setState(() {
        _phase = _Phase.menu;
        _session = null;
        _error = null;
      });
      session.removeListener(_onSession);
      session.dispose();
      return;
    }
    final controller = session.controller;
    if (session.hasOpponent && controller != null) {
      _handedOver = true;
      _matchTimer?.cancel();
      session.removeListener(_onSession);
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => GameScreen(controller: controller, online: session),
      ));
    } else {
      setState(() {});
    }
  }

  Side _pickSide() => _side ?? (math.Random().nextBool() ? Side.goat : Side.tiger);

  Future<void> _createRoom() => _run((backend) async {
        final room = await backend.createRoom(
          name: _playerName,
          side: _pickSide(),
          captureTarget: SettingsScope.read(context).captureTarget,
          isPublic: false,
        );
        if (!mounted) return;
        _attach(room);
        setState(() => _phase = _Phase.waiting);
      });

  Future<void> _joinRoom() {
    final code = RoomCode.normalise(_code.text);
    if (!RoomCode.isValid(code)) {
      setState(() => _error = OnlineErrorKind.notFound);
      return Future.value();
    }
    return _run((backend) async {
      final room = await backend.joinRoom(code, _playerName);
      if (!mounted) return;
      _attach(room);
    });
  }

  /// Joins someone already waiting, or opens a public room and waits. While
  /// waiting, keeps looking, so two players who started at the same moment
  /// still find each other: the one with the larger room code moves over.
  Future<void> _quickMatch() => _run((backend) async {
        if (await _tryJoinPublic(backend, below: null)) return;
        final room = await backend.createRoom(
          name: _playerName,
          side: _pickSide(),
          captureTarget: PuliMekaGame.defaultCaptureTarget,
          isPublic: true,
        );
        if (!mounted) return;
        _attach(room);
        setState(() {
          _phase = _Phase.searching;
          _searchStarted = DateTime.now();
        });
        _matchTimer?.cancel();
        _matchTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
          final mine = _session?.room;
          if (mine == null || mine.isFull || _phase != _Phase.searching) return;
          try {
            if (await _tryJoinPublic(backend, below: mine.code)) {
              await backend.leave(mine.code);
            }
          } on OnlineError {
            // Try again on the next tick.
          }
          if (mounted) setState(() {});
        });
      });

  Future<bool> _tryJoinPublic(OnlineBackend backend, {required String? below}) async {
    final rooms = (await backend.openPublicRooms())
        .where((r) =>
            r.captureTarget == PuliMekaGame.defaultCaptureTarget &&
            (below == null || r.code.compareTo(below) < 0))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    for (final r in rooms) {
      try {
        final joined = await backend.joinRoom(r.code, _playerName);
        if (!mounted) return true;
        _matchTimer?.cancel();
        _attach(joined);
        return true;
      } on OnlineError catch (e) {
        if (e.kind != OnlineErrorKind.full && e.kind != OnlineErrorKind.notFound) rethrow;
      }
    }
    return false;
  }

  Future<void> _cancelWaiting() async {
    _matchTimer?.cancel();
    final session = _session;
    setState(() {
      _phase = _Phase.menu;
      _session = null;
    });
    if (session != null) {
      session.removeListener(_onSession);
      await session.leave();
      session.dispose();
    }
  }

  Future<void> _shareCode(S s, String code) async {
    final text = s.shareInvite(code, AppLinks.latestRelease);
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: s.appName));
    } catch (_) {
      await _copyCode(s, code);
    }
  }

  Future<void> _copyCode(S s, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.codeCopied)));
    }
  }

  String _errorText(S s, OnlineErrorKind kind) => switch (kind) {
        OnlineErrorKind.offline => s.errOffline,
        OnlineErrorKind.notFound => s.errNotFound,
        OnlineErrorKind.full => s.errFull,
        OnlineErrorKind.ownRoom => s.errOwnRoom,
        OnlineErrorKind.unavailable => s.errUnavailable,
        OnlineErrorKind.unknown => s.errUnknown,
      };

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context).s;
    return PopScope(
      canPop: _phase != _Phase.waiting && _phase != _Phase.searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelWaiting();
      },
      child: Scaffold(
        body: MugguluBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Text(
                          s.playOnline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: KeyedSubtree(
                            key: ValueKey(_phase),
                            child: switch (_phase) {
                              _Phase.connecting || _Phase.busy => _Busy(text: s.connecting),
                              _Phase.unavailable => _Message(text: s.errUnavailable),
                              _Phase.waiting => _waiting(s),
                              _Phase.searching => _searching(s),
                              _Phase.menu => _menu(s),
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menu(S s) {
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          _ErrorBox(
            text: _errorText(s, error),
            onRetry: _backend == null ? _connect : null,
            retryLabel: s.tryAgain,
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _name,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: s.yourName,
            prefixIcon: const Icon(Icons.person_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onSubmitted: (_) => _saveName(),
        ),
        const SizedBox(height: 8),
        _Section(
          emoji: '🤝',
          title: s.inviteFriend,
          subtitle: s.inviteFriendSub,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.playAs, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              SegmentedButton<Side?>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.turmeric,
                  selectedForegroundColor: AppColors.night,
                ),
                segments: [
                  ButtonSegment(value: Side.goat, label: Text('🐐 ${s.sideName(Side.goat)}')),
                  ButtonSegment(value: Side.tiger, label: Text('🐯 ${s.sideName(Side.tiger)}')),
                  ButtonSegment(value: null, label: Text('🎲 ${s.randomSide}')),
                ],
                selected: {_side},
                onSelectionChanged: (v) => setState(() => _side = v.first),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: Text(s.createRoom),
                onPressed: _createRoom,
              ),
            ],
          ),
        ),
        _Section(
          emoji: '🔑',
          title: s.joinFriend,
          subtitle: s.joinFriendSub,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  maxLength: RoomCode.length,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w800,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                    TextInputFormatter.withFunction(
                      (old, value) => value.copyWith(text: value.text.toUpperCase()),
                    ),
                  ],
                  decoration: InputDecoration(
                    hintText: 'ABC123',
                    counterText: '',
                    labelText: s.roomCode,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onSubmitted: (_) => _joinRoom(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: _joinRoom, child: Text(s.join)),
            ],
          ),
        ),
        _Section(
          emoji: '⚡',
          title: s.quickMatch,
          subtitle: s.quickMatchSub,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.travel_explore_rounded),
            label: Text(s.findPlayer),
            onPressed: _quickMatch,
          ),
        ),
      ],
    );
  }

  Widget _waiting(S s) {
    final room = _session?.room;
    if (room == null) return _Busy(text: s.connecting);
    final side = room.hostSide;
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(s.roomCode, style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.75))),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => _copyCode(s, room.code),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.chalk.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.turmeric, width: 2),
            ),
            child: SelectableText(
              room.code,
              style: const TextStyle(
                fontSize: 40,
                letterSpacing: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.turmeric,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.share_rounded),
              label: Text(s.shareCode),
              onPressed: () => _shareCode(s, room.code),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded),
              label: Text(s.copyCode),
              onPressed: () => _copyCode(s, room.code),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          s.shareCodeHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.8)),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 40, height: 40, child: PieceToken(isTiger: side == Side.tiger)),
            const SizedBox(width: 10),
            Text(s.youAre(side), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 24),
        _Busy(text: s.waitingForFriend),
        const SizedBox(height: 16),
        TextButton(onPressed: _cancelWaiting, child: Text(s.cancel)),
      ],
    );
  }

  Widget _searching(S s) {
    final started = _searchStarted;
    final long = started != null && DateTime.now().difference(started).inSeconds > 40;
    return Column(
      children: [
        const SizedBox(height: 40),
        _Busy(text: s.searching),
        if (long) ...[
          const SizedBox(height: 16),
          _Message(text: s.nobodyOnline),
        ],
        const SizedBox(height: 16),
        TextButton(onPressed: _cancelWaiting, child: Text(s.cancel)),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Widget child;

  const _Section({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.chalk.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.chalk.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(
                      subtitle,
                      style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.7), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  final String text;
  const _Busy({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.turmeric),
          ),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  const _Message({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.85)),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  final String retryLabel;
  const _ErrorBox({required this.text, required this.onRetry, required this.retryLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.kumkum.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.kumkum),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.turmeric),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          if (onRetry != null) TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
