import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/security/username_validator.dart';
import '../../core/widgets/brand.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends ConsumerState<ProfileSetupScreen> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController();
  final displayName = TextEditingController();
  DateTime? birthDate;
  String country = 'CH';
  bool privateProfile = false;
  bool terms = false;
  bool privacy = false;
  bool guidelines = false;
  bool loading = false;

  bool get oldEnough {
    final date = birthDate;
    if (date == null) return false;
    final cutoff = DateTime.now();
    final sixteenthBirthday = DateTime(date.year + 16, date.month, date.day);
    return !sixteenthBirthday.isAfter(cutoff);
  }

  @override
  void dispose() {
    username.dispose();
    displayName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    if (!oldEnough || !terms || !privacy || !guidelines) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be 16+ and accept all policies.'),
        ),
      );
      return;
    }
    setState(() => loading = true);
    try {
      await ref
          .read(appRepositoryProvider)
          .saveProfile(
            username: username.text,
            displayName: displayName.text,
            countryCode: country,
            languageCode: Localizations.localeOf(context).languageCode,
            timezone: DateTime.now().timeZoneName,
            dateOfBirth: birthDate!,
            isPrivate: privateProfile,
          );
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorMapper.message(error))));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const SvnlyWordmark()),
    body: SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Form(
        key: form,
        child: ListView(
          children: [
            Text(
              'Make it yours.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your birth date is private and is used only for age eligibility.',
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: username,
              autocorrect: false,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixText: '@',
              ),
              validator: (value) => UsernameValidator.validate(value ?? ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: displayName,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: (value) => (value?.trim().length ?? 0) >= 2
                  ? null
                  : 'Enter your display name.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: country,
              decoration: const InputDecoration(labelText: 'Country'),
              items:
                  const {
                        'CH': 'Switzerland',
                        'DE': 'Germany',
                        'AT': 'Austria',
                        'FR': 'France',
                        'IT': 'Italy',
                        'GB': 'United Kingdom',
                        'US': 'United States',
                        'CA': 'Canada',
                        'AU': 'Australia',
                        'JP': 'Japan',
                        'BR': 'Brazil',
                        'IN': 'India',
                      }.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
              onChanged: (value) => setState(() => country = value ?? country),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: DateTime(DateTime.now().year - 18),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  helpText: 'Confirm you are 16 or older',
                );
                if (selected != null) setState(() => birthDate = selected);
              },
              icon: const Icon(Icons.cake_outlined),
              label: Text(
                birthDate == null
                    ? 'DATE OF BIRTH'
                    : '${birthDate!.day}.${birthDate!.month}.${birthDate!.year}',
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Private profile'),
              subtitle: const Text('Only approved followers see your takes.'),
              value: privateProfile,
              onChanged: (value) => setState(() => privateProfile = value),
            ),
            _ConsentTile(
              value: terms,
              label: 'I accept the Terms of Use.',
              onChanged: (value) => setState(() => terms = value),
            ),
            _ConsentTile(
              value: privacy,
              label: 'I accept the Privacy Policy.',
              onChanged: (value) => setState(() => privacy = value),
            ),
            _ConsentTile(
              value: guidelines,
              label: 'I accept the Community Guidelines.',
              onChanged: (value) => setState(() => guidelines = value),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: loading ? null : _save,
              child: loading
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : const Text('ENTER SVNLY'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.label,
    required this.onChanged,
  });
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    value: value,
    title: Text(label),
    onChanged: (next) => onChanged(next ?? false),
  );
}
