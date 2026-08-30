import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design/tokens.dart';
import '../../core/design/effects.dart';
import '../../core/localization/app_strings.dart';
import '../../core/widgets/brand.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final controller = PageController();
  int page = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _finish(String route) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('onboarding_complete', true);
    if (mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final german = Localizations.localeOf(context).languageCode == 'de';
    final pages = [
      (
        '01',
        german ? 'Eine Challenge. Jeden Tag.' : 'One challenge. Every day.',
        german
            ? 'Eine globale Aufgabe für alle.'
            : 'One global prompt for everyone.',
        Icons.public,
      ),
      (
        '07',
        '7 seconds. One take.',
        german
            ? 'Keine Bearbeitung. Keine Uploads. Keine zweite Chance.'
            : 'No edits. No uploads. No second chances.',
        Icons.videocam_outlined,
      ),
      (
        '→',
        german
            ? 'Mach zuerst deinen Take.'
            : 'Take yours before you see theirs.',
        german
            ? 'Erst teilnehmen, danach den Tagesfeed sehen.'
            : 'Join today before the feed unlocks.',
        Icons.lock_outline,
      ),
      (
        '✓',
        german ? 'Sei echt.' : 'Be real.',
        AppStrings.of(context).claim,
        Icons.bolt,
      ),
    ];
    final accents = [
      SvnlyColors.electricBlue,
      SvnlyColors.lime,
      SvnlyColors.hotPink,
      SvnlyColors.orange,
    ];
    return Scaffold(
      body: NeonBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SvnlyWordmark(),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: controller,
                  onPageChanged: (value) => setState(() => page = value),
                  itemCount: pages.length,
                  itemBuilder: (context, index) {
                    final item = pages[index];
                    return Semantics(
                      label: '${item.$2}. ${item.$3}',
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Spacer(),
                            Container(
                              width: 82,
                              height: 82,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [accents[index], SvnlyColors.purple],
                                ),
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color: accents[index].withValues(
                                      alpha: .35,
                                    ),
                                    blurRadius: 34,
                                  ),
                                ],
                              ),
                              child: Icon(
                                item.$4,
                                size: 42,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            NeonBadge(label: item.$1, color: accents[index]),
                            const SizedBox(height: 10),
                            Text(
                              item.$2,
                              style: Theme.of(context).textTheme.displayLarge
                                  ?.copyWith(fontSize: 50, height: .95),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              item.$3,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: SvnlyColors.secondaryText,
                                    fontSize: 18,
                                  ),
                            ),
                            const Spacer(flex: 2),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.all(3),
                          width: index == page ? 24 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: index == page
                                ? SvnlyColors.lime
                                : SvnlyColors.mutedText,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (page < pages.length - 1)
                      FilledButton(
                        onPressed: () => controller.nextPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                        ),
                        child: Text(german ? 'WEITER' : 'CONTINUE'),
                      )
                    else ...[
                      FilledButton(
                        onPressed: () => _finish('/auth?mode=signup'),
                        child: Text(AppStrings.of(context).join),
                      ),
                      TextButton(
                        onPressed: () => _finish('/auth?mode=login'),
                        child: Text(
                          german
                              ? 'ICH HABE BEREITS EIN KONTO'
                              : 'I ALREADY HAVE AN ACCOUNT',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
