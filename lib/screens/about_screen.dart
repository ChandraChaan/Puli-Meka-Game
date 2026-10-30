import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../main.dart';
import '../theme.dart';
import '../widgets/board_view.dart';
import '../widgets/decorations.dart';

class AppLinks {
  AppLinks._();

  static const repo = 'https://github.com/ChandraChaan/Puli-Meka-Game';
  static const latestRelease = '$repo/releases/latest';
  static const issues = '$repo/issues';
}

/// The app version, e.g. "2.0.0 (14)", or null where it is unavailable.
Future<String?> loadAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty ? info.version : '${info.version} (${info.buildNumber})';
  } catch (_) {
    return null;
  }
}

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final Future<String?> _version = loadAppVersion();

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context).s;
    return Scaffold(
      appBar: AppBar(title: Text(s.aboutApp)),
      extendBodyBehindAppBar: true,
      body: MugguluBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: FutureBuilder<String?>(
                    future: _version,
                    builder: (context, snap) => _content(context, s, snap.data),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, S s, String? version) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(version: version),
        const SizedBox(height: 18),
        InfoSection(title: s.aboutThisApp, child: Text(s.appIntro, style: _body)),
        InfoSection(
          title: s.alsoKnownAs,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (name, region) in s.otherNames) _NameChip(name: name, region: region),
            ],
          ),
        ),
        InfoSection(
          title: s.featuresTitle,
          child: Column(
            children: [
              for (final f in s.features)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2, right: 10),
                        child:
                            Icon(Icons.check_circle_rounded, size: 20, color: AppColors.leafLight),
                      ),
                      Expanded(child: Text(f, style: _body)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        InfoSection(
          title: s.privacyTitle,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 10),
                child: Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.turmeric),
              ),
              Expanded(child: Text(s.privacy, style: _body)),
            ],
          ),
        ),
        InfoSection(
          title: s.linksTitle,
          // Its own Material so the tiles' ink shows above the card colour.
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                _LinkTile(
                  icon: Icons.share_rounded,
                  title: s.shareApp,
                  subtitle: s.shareAppSub,
                  onTap: () => _share(context, s),
                ),
                _LinkTile(
                  icon: Icons.system_update_rounded,
                  title: s.latestVersion,
                  subtitle: s.latestVersionSub,
                  onTap: () => _open(context, s, AppLinks.latestRelease),
                ),
                _LinkTile(
                  icon: Icons.bug_report_outlined,
                  title: s.reportProblem,
                  subtitle: s.reportProblemSub,
                  onTap: () => _open(context, s, AppLinks.issues),
                ),
                _LinkTile(
                  icon: Icons.code_rounded,
                  title: s.sourceCode,
                  subtitle: s.sourceCodeSub,
                  onTap: () => _open(context, s, AppLinks.repo),
                ),
                _LinkTile(
                  icon: Icons.description_outlined,
                  title: s.licenses,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: s.appName,
                    applicationVersion: version,
                    applicationIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 56, height: 56, child: PieceToken(isTiger: true)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        InfoSection(title: s.creditsTitle, child: Text(s.credits, style: _body)),
        const SizedBox(height: 6),
        Text(
          s.madeIn,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.6), fontSize: 13),
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context, S s, String url) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.linkFailed)));
    }
  }

  Future<void> _share(BuildContext context, S s) async {
    final text = s.shareMessage(AppLinks.latestRelease);
    try {
      await SharePlus.instance.share(ShareParams(text: text, subject: s.appName));
    } catch (_) {
      // No share sheet (e.g. some desktop browsers): copy the message instead.
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.linkCopied)));
      }
    }
  }
}

const _body = TextStyle(fontSize: 15, height: 1.5, color: AppColors.chalk);

class _Header extends StatelessWidget {
  final String? version;
  const _Header({required this.version});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context).s;
    final v = version;
    return Column(
      children: [
        const SizedBox(
          height: 84,
          width: 150,
          child: Stack(
            children: [
              Positioned(
                  left: 0, bottom: 0, width: 64, height: 64, child: PieceToken(isTiger: false)),
              Positioned(
                  right: 0, bottom: 0, width: 64, height: 64, child: PieceToken(isTiger: false)),
              Positioned(left: 37, top: 0, width: 76, height: 76, child: PieceToken(isTiger: true)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [AppColors.turmeric, AppColors.marigold],
          ).createShader(r),
          child: const Text(
            'పులి మేక',
            style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white),
          ),
        ),
        const Text(
          'PULI  MEKA',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 5,
            fontWeight: FontWeight.w800,
            color: AppColors.chalk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          s.tagline,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.8)),
        ),
        if (v != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.chalk.withValues(alpha: 0.3)),
            ),
            child: Text(
              s.version(v),
              style: TextStyle(fontSize: 12, color: AppColors.chalk.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ],
    );
  }
}

class _NameChip extends StatelessWidget {
  final String name;
  final String region;
  const _NameChip({required this.name, required this.region});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.turmeric.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.turmeric.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(
            region,
            style: TextStyle(fontSize: 12, color: AppColors.chalk.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _LinkTile({required this.icon, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.chalk.withValues(alpha: 0.1),
        foregroundColor: AppColors.turmeric,
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: sub == null
          ? null
          : Text(sub, style: TextStyle(color: AppColors.chalk.withValues(alpha: 0.7))),
      trailing: Icon(Icons.chevron_right_rounded, color: AppColors.chalk.withValues(alpha: 0.6)),
      onTap: onTap,
    );
  }
}
