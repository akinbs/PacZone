import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum EyeType { round, star, cool, happy }
enum AccessoryType { none, crown, headband, cap, glasses }

class AvatarModel {
  final Color primaryColor;
  final Color auraColor;
  final EyeType eyeType;
  final AccessoryType accessory;

  const AvatarModel({
    required this.primaryColor,
    required this.auraColor,
    required this.eyeType,
    required this.accessory,
  });

  factory AvatarModel.initial() => const AvatarModel(
        primaryColor: AppColors.primary,
        auraColor: AppColors.secondary,
        eyeType: EyeType.round,
        accessory: AccessoryType.none,
      );

  AvatarModel copyWith({
    Color? primaryColor,
    Color? auraColor,
    EyeType? eyeType,
    AccessoryType? accessory,
  }) {
    return AvatarModel(
      primaryColor: primaryColor ?? this.primaryColor,
      auraColor: auraColor ?? this.auraColor,
      eyeType: eyeType ?? this.eyeType,
      accessory: accessory ?? this.accessory,
    );
  }
}
