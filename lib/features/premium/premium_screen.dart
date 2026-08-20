import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/config/app_config.dart';
import '../../core/design/tokens.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});
  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  Future<Offering?>? offering;
  bool configured = false;
  bool active = false;
  String? status;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  Future<void> _configure() async {
    final config = ref.read(appConfigProvider);
    if (!config.premiumEnabled) {
      setState(() => status = 'SVNLY Plus is not enabled for this build.');
      return;
    }
    final repository = ref.read(appRepositoryProvider);
    final purchasesConfig = PurchasesConfiguration(config.revenueCatIosApiKey)
      ..appUserID = repository.userId;
    await Purchases.configure(purchasesConfig);
    configured = true;
    final info = await Purchases.getCustomerInfo();
    active = info.entitlements.all['svnly_plus']?.isActive ?? false;
    offering = Purchases.getOfferings().then((value) => value.current);
    if (mounted) setState(() {});
  }

  Future<void> _buy(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      setState(() {
        active =
            result.customerInfo.entitlements.all['svnly_plus']?.isActive ??
            false;
        status = active
            ? 'SVNLY Plus is active.'
            : 'Purchase is pending confirmation.';
      });
    } catch (_) {
      if (mounted) setState(() => status = 'Purchase was not completed.');
    }
  }

  Future<void> _restore() async {
    if (!configured) return;
    final info = await Purchases.restorePurchases();
    setState(() {
      active = info.entitlements.all['svnly_plus']?.isActive ?? false;
      status = active
          ? 'Purchase restored.'
          : 'No active SVNLY Plus purchase found.';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SVNLY PLUS')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.bolt, size: 72, color: SvnlyColors.lime),
        const SizedBox(height: 16),
        Text(
          'More style. Still real.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 10),
        const Text(
          'Core participation, feeds, safety, rankings and six live looks always stay free.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 26),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                _Benefit('Premium live looks', Icons.filter_vintage_outlined),
                _Benefit(
                  'Personal statistics & ranking history',
                  Icons.insights_outlined,
                ),
                _Benefit('Throwbacks from your own takes', Icons.history),
                _Benefit('Cosmetic profile frames', Icons.account_box_outlined),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        if (active)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: SvnlyColors.success),
                  SizedBox(width: 12),
                  Text(
                    'SVNLY Plus is active',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          )
        else if (offering != null)
          FutureBuilder<Offering?>(
            future: offering,
            builder: (context, snapshot) {
              final packages =
                  snapshot.data?.availablePackages ?? const <Package>[];
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (packages.isEmpty) {
                return const Text(
                  'Purchases are temporarily unavailable. The free app remains fully usable.',
                  textAlign: TextAlign.center,
                );
              }
              return Column(
                children: packages
                    .map(
                      (package) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FilledButton(
                          onPressed: () => _buy(package),
                          child: Text(
                            '${package.storeProduct.title.toUpperCase()} · ${package.storeProduct.priceString}',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(status!, textAlign: TextAlign.center),
          ),
        TextButton(onPressed: _restore, child: const Text('RESTORE PURCHASES')),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://apps.apple.com/account/subscriptions'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('MANAGE SUBSCRIPTION'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. No purchase improves ranking or grants extra takes.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: SvnlyColors.secondaryText),
        ),
      ],
    ),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: SvnlyColors.lime),
    title: Text(label),
  );
}
