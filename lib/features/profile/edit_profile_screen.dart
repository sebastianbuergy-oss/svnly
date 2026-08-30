import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

import '../../app/providers.dart';
import '../../core/design/effects.dart';
import '../../core/design/tokens.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/security/username_validator.dart';

Uint8List prepareAvatarImage(Uint8List bytes) {
  var decoded = image.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image.');
  decoded = image.bakeOrientation(decoded);
  final side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final cropped = image.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final resized = image.copyResize(
    cropped,
    width: 768,
    height: 768,
    interpolation: image.Interpolation.cubic,
  );
  return Uint8List.fromList(image.encodeJpg(resized, quality: 88));
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController();
  final displayName = TextEditingController();
  final bio = TextEditingController();
  Uint8List? avatarBytes;
  String? avatarUrl;
  String country = 'CH';
  bool loading = true;
  bool saving = false;

  static const countries = {
    'CH': '🇨🇭 Switzerland',
    'DE': '🇩🇪 Germany',
    'AT': '🇦🇹 Austria',
    'FR': '🇫🇷 France',
    'IT': '🇮🇹 Italy',
    'GB': '🇬🇧 United Kingdom',
    'US': '🇺🇸 United States',
    'CA': '🇨🇦 Canada',
    'AU': '🇦🇺 Australia',
    'JP': '🇯🇵 Japan',
    'BR': '🇧🇷 Brazil',
    'IN': '🇮🇳 India',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await ref.read(appRepositoryProvider).loadMyProfile();
      username.text = value['username'] as String? ?? '';
      displayName.text = value['display_name'] as String? ?? '';
      bio.text = value['bio'] as String? ?? '';
      country = value['country_code'] as String? ?? 'CH';
      avatarUrl = value['avatar_url'] as String?;
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
  void dispose() {
    username.dispose();
    displayName.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 100,
    );
    if (picked == null) return;
    try {
      final processed = await compute(
        prepareAvatarImage,
        await picked.readAsBytes(),
      );
      if (mounted) setState(() => avatarBytes = processed);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorMapper.message(error))));
      }
    }
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final repository = ref.read(appRepositoryProvider);
      String? avatarPath;
      if (avatarBytes != null) {
        avatarPath = await repository.uploadAvatar(avatarBytes!);
      }
      await repository.updateProfile(
        username: username.text,
        displayName: displayName.text,
        bio: bio.text,
        countryCode: country,
        avatarPath: avatarPath,
      );
      ref.invalidate(myTakesProvider);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ErrorMapper.message(error))));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  ImageProvider<Object>? get avatarImage {
    if (avatarBytes != null) return MemoryImage(avatarBytes!);
    if (avatarUrl != null) return NetworkImage(avatarUrl!);
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('EDIT YOUR VIBE')),
    body: NeonBackdrop(
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: [
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 126,
                          height: 126,
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SvnlyGradients.heroPop,
                          ),
                          child: CircleAvatar(
                            key: const ValueKey('edit_profile_avatar'),
                            backgroundColor: SvnlyColors.elevated,
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? const Icon(
                                    Icons.person,
                                    size: 54,
                                    color: SvnlyColors.lime,
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          right: -8,
                          bottom: 0,
                          child: IconButton.filled(
                            key: const ValueKey('pick_profile_avatar'),
                            onPressed: _pickAvatar,
                            style: IconButton.styleFrom(
                              backgroundColor: SvnlyColors.hotPink,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.photo_library_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Centered, square and crisp. We resize it before upload.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SvnlyColors.secondaryText),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    key: const ValueKey('edit_profile_display_name'),
                    controller: displayName,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                    validator: (value) => (value?.trim().length ?? 0) >= 2
                        ? null
                        : 'Enter your display name.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('edit_profile_username'),
                    controller: username,
                    autocorrect: false,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixText: '@',
                    ),
                    validator: (value) =>
                        UsernameValidator.validate(value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('edit_profile_bio'),
                    controller: bio,
                    maxLength: 160,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Bio',
                      hintText: 'Tiny bio. Big energy.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('edit_profile_country'),
                    initialValue: country,
                    decoration: const InputDecoration(
                      labelText: 'Country / flag',
                    ),
                    items: countries.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) =>
                        setState(() => country = value ?? country),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    key: const ValueKey('save_profile_changes'),
                    onPressed: saving ? null : _save,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bolt),
                    label: const Text('SAVE THE GLOW-UP'),
                  ),
                ],
              ),
            ),
    ),
  );
}
