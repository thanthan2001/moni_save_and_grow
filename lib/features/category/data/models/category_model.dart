import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/icon_data_resolver.dart';
import '../../domain/entities/category_entity.dart';

part 'category_model.g.dart';

/// Model cho Category, dùng cho Hive
@HiveType(typeId: 1)
class CategoryModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int iconCodePoint; // Lưu icon dưới dạng codePoint

  @HiveField(3)
  final String iconFontFamily; // Font family của icon

  @HiveField(4)
  final int colorValue; // Lưu màu dưới dạng int value

  @HiveField(5)
  final String type; // 'income', 'expense', 'both'

  @HiveField(6)
  final String?
      iconFontPackage; // Font package của icon (nullable cho backward compatibility)

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.iconFontFamily,
    required this.colorValue,
    required this.type,
    this.iconFontPackage,
  });

  /// Convert từ Entity sang Model
  factory CategoryModel.fromEntity(CategoryEntity entity) {
    return CategoryModel(
      id: entity.id,
      name: entity.name,
      iconCodePoint: entity.icon.codePoint,
      iconFontFamily: entity.icon.fontFamily ?? 'MaterialIcons',
      iconFontPackage: entity.icon.fontPackage,
      colorValue: entity.color.value,
      type: entity.type == TransactionCategoryType.income
          ? 'income'
          : entity.type == TransactionCategoryType.expense
              ? 'expense'
              : 'both',
    );
  }

  /// Convert từ Model sang Entity
  CategoryEntity toEntity() {
    return CategoryEntity(
      id: id,
      name: name,
      icon: _createIconData(),
      color: Color(colorValue),
      type: type == 'income'
          ? TransactionCategoryType.income
          : type == 'expense'
              ? TransactionCategoryType.expense
              : TransactionCategoryType.both,
    );
  }

  /// Helper method để tạo IconData
  IconData _createIconData() {
    return AppIconResolver.resolve(
      codePoint: iconCodePoint,
      fontFamily: iconFontFamily,
      fontPackage: iconFontPackage,
    );
  }

  /// Convert từ JSON (nếu cần)
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      iconCodePoint: json['iconCodePoint'] as int,
      iconFontFamily: json['iconFontFamily'] as String,
      iconFontPackage: json['iconFontPackage'] as String?,
      colorValue: json['colorValue'] as int,
      type: json['type'] as String,
    );
  }

  /// Convert sang JSON (nếu cần)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconCodePoint': iconCodePoint,
      'iconFontFamily': iconFontFamily,
      'iconFontPackage': iconFontPackage,
      'colorValue': colorValue,
      'type': type,
    };
  }
}
