import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/context_t.dart';
import '../../../core/models/partner_user.dart';
import '../../../core/theme/xpert_tokens.dart';
import '../../auth/data/partner_auth_api.dart';
import '../../auth/presentation/auth_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  String? _gender;
  String? _photoPath;
  String? _existingPhoto;
  bool _saving = false;
  String? _error;

  static const _genders = ['Male', 'Female', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).valueOrNull?.profile;
    _nameCtrl.text = profile?.name ?? '';
    _gender = profile?.gender;
    _existingPhoto = profile?.photo;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  ImageProvider? get _avatarImage {
    if (_photoPath != null) return FileImage(File(_photoPath!));
    if (_existingPhoto != null && _existingPhoto!.isNotEmpty) {
      return NetworkImage(_existingPhoto!);
    }
    return null;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() => _photoPath = file.path);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = ref.t('profile.name_required'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(partnerAuthApiProvider).updateProfile(
            name: name,
            gender: _gender,
            photoPath: _photoPath,
          );
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.t('profile.saved'))),
      );
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _avatarImage;

    return Scaffold(
      backgroundColor: XpertColors.background,
      appBar: AppBar(title: Text(ref.t('profile.edit_title'))),
      body: ListView(
        padding: const EdgeInsets.all(XpertSpacing.lg),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: XpertColors.secondary,
                    backgroundImage: avatar,
                    child: avatar == null
                        ? const Icon(Icons.person, size: 48)
                        : null,
                  ),
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: XpertColors.primary,
                      child: Icon(Icons.camera_alt, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: XpertSpacing.xs),
          Text(
            ref.t('profile.change_photo'),
            textAlign: TextAlign.center,
            style: XpertTypography.caption,
          ),
          const SizedBox(height: XpertSpacing.xl),
          Text(ref.t('profile.name'), style: XpertTypography.caption),
          const SizedBox(height: XpertSpacing.xs),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: XpertTypography.body.copyWith(fontSize: 18),
            decoration: InputDecoration(
              hintText: ref.t('profile.name_hint'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(XpertRadius.md),
              ),
            ),
          ),
          const SizedBox(height: XpertSpacing.lg),
          Text(ref.t('profile.gender'), style: XpertTypography.caption),
          const SizedBox(height: XpertSpacing.xs),
          DropdownButtonFormField<String>(
            value: _genders.contains(_gender) ? _gender : null,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: ref.t('profile.gender_hint'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(XpertRadius.md),
              ),
            ),
            items: _genders
                .map(
                  (g) => DropdownMenuItem(
                    value: g,
                    child: Text(g, style: XpertTypography.body),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _gender = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: XpertSpacing.md),
            Text(
              _error!,
              style:
                  XpertTypography.caption.copyWith(color: XpertColors.danger),
            ),
          ],
          const SizedBox(height: XpertSpacing.xl),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      ref.t('profile.save'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
