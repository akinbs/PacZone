import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_state.dart';
import '../models/avatar_model.dart';
import '../theme/app_colors.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/chomp_widget.dart';
import 'location_permission_screen.dart';

class AvatarCreationScreen extends StatefulWidget {
  final bool editMode;
  const AvatarCreationScreen({super.key, this.editMode = false});

  @override
  State<AvatarCreationScreen> createState() => _AvatarCreationScreenState();
}

class _AvatarCreationScreenState extends State<AvatarCreationScreen>
    with SingleTickerProviderStateMixin {
  late AvatarModel _avatar;
  bool _showChomp = false;
  late AnimationController _previewCtrl;
  late Animation<double> _scaleAnim;

  static const List<String> _eyeLabels = ['Yuvarlak', 'Yıldız', 'Cool', 'Mutlu'];
  static const List<String> _accLabels = ['Yok', 'Taç', 'Bandana', 'Şapka', 'Gözlük'];

  @override
  void initState() {
    super.initState();
    _avatar = AppState.user.avatar;
    _previewCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0)
        .chain(CurveTween(curve: Curves.elasticOut))
        .animate(_previewCtrl);
    _previewCtrl.forward();
  }

  @override
  void dispose() {
    _previewCtrl.dispose();
    super.dispose();
  }

  void _updateAvatar(AvatarModel updated) {
    setState(() => _avatar = updated);
    _previewCtrl.forward(from: 0.0);
  }

  void _proceed() {
    AppState.updateAvatar(_avatar);
    if (widget.editMode) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LocationPermissionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildPreview(),
                    const SizedBox(height: 28),
                    _buildSection(
                      'Ana Renk',
                      _colorPicker(),
                    ),
                    _buildSection(
                      'Göz Tipi',
                      _eyePicker(),
                    ),
                    _buildSection(
                      'Aksesuar',
                      _accPicker(),
                    ),
                    _buildSection(
                      'Aura Rengi',
                      _auraPicker(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _proceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    widget.editMode ? 'Kaydet' : 'Devam',
                    style:
                        GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          if (widget.editMode)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: AppColors.textSecondary, size: 20),
            ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.editMode ? 'Avatarını Düzenle' : 'Karakterini Oluştur',
                style: GoogleFonts.nunito(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary),
              ),
              Text(
                'Chomp Mode\'da seninle oynasın',
                style: GoogleFonts.nunito(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => setState(() => _showChomp = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: !_showChomp ? AppColors.primary.withAlpha(30) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: !_showChomp ? AppColors.primary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Text('Normal',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          color: !_showChomp ? AppColors.primary : AppColors.textHint,
                          fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => setState(() => _showChomp = true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _showChomp ? AppColors.secondary.withAlpha(30) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _showChomp ? AppColors.secondary : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Text('Chomp Mode',
                      style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          color: _showChomp ? AppColors.secondary : AppColors.textHint,
                          fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _scaleAnim,
            builder: (_, __) => Transform.scale(
              scale: _scaleAnim.value,
              child: _showChomp
                  ? ChompWidget(
                      bodyColor: _avatar.primaryColor,
                      auraColor: _avatar.auraColor,
                      size: 110,
                      animated: true,
                    )
                  : AvatarWidget(
                      avatar: _avatar,
                      size: 110,
                      showAura: true,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        child,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _colorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AppColors.avatarPalette.map((c) {
        final sel = _avatar.primaryColor == c;
        return GestureDetector(
          onTap: () => _updateAvatar(_avatar.copyWith(primaryColor: c)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                color: sel ? Colors.white : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: sel
                  ? [BoxShadow(color: c.withAlpha(120), blurRadius: 12, spreadRadius: 2)]
                  : null,
            ),
            child: sel
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _eyePicker() {
    final eyes = EyeType.values;
    return Row(
      children: List.generate(eyes.length, (i) {
        final sel = _avatar.eyeType == eyes[i];
        return Expanded(
          child: GestureDetector(
            onTap: () => _updateAvatar(_avatar.copyWith(eyeType: eyes[i])),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary.withAlpha(25) : AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: sel ? AppColors.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  AvatarWidget(
                    avatar: _avatar.copyWith(eyeType: eyes[i]),
                    size: 36,
                    showAura: false,
                  ),
                  const SizedBox(height: 6),
                  Text(_eyeLabels[i],
                      style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: sel ? AppColors.primary : AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _accPicker() {
    final accs = AccessoryType.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(accs.length, (i) {
          final sel = _avatar.accessory == accs[i];
          return GestureDetector(
            onTap: () => _updateAvatar(_avatar.copyWith(accessory: accs[i])),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? AppColors.accent.withAlpha(25) : AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: sel ? AppColors.accent : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  AvatarWidget(
                    avatar: _avatar.copyWith(accessory: accs[i]),
                    size: 36,
                    showAura: false,
                  ),
                  const SizedBox(height: 6),
                  Text(_accLabels[i],
                      style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: sel ? AppColors.accent : AppColors.textSecondary)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _auraPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AppColors.auraPalette.map((c) {
        final sel = _avatar.auraColor == c;
        return GestureDetector(
          onTap: () => _updateAvatar(_avatar.copyWith(auraColor: c)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c, width: sel ? 3 : 1.5),
              boxShadow: sel
                  ? [BoxShadow(color: c.withAlpha(100), blurRadius: 10, spreadRadius: 2)]
                  : null,
            ),
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: c.withAlpha(sel ? 180 : 80),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
