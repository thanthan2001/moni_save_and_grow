import 'package:equatable/equatable.dart';

class AiTransactionParseEntity extends Equatable {
  final String type; // thu nhập | chi phí
  final int? amount; // số tiền chuẩn hóa VND
  final String categoryId;
  final String categoryName;
  final String description;
  final String datetime; // ISO string hoặc "now"

  const AiTransactionParseEntity({
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    required this.datetime,
  });

  AiTransactionParseEntity copyWith({
    String? type,
    int? amount,
    bool clearAmount = false,
    String? categoryId,
    String? categoryName,
    String? description,
    String? datetime,
  }) {
    return AiTransactionParseEntity(
      type: type ?? this.type,
      amount: clearAmount ? null : (amount ?? this.amount),
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      description: description ?? this.description,
      datetime: datetime ?? this.datetime,
    );
  }

  Map<String, dynamic> toRuleJson() {
    return {
      'type': type,
      'số tiền': amount,
      'category_id': categoryId,
      'category_name': categoryName,
      'description': description,
      'datetime': datetime,
    };
  }

  @override
  List<Object?> get props => [
        type,
        amount,
        categoryId,
        categoryName,
        description,
        datetime,
      ];
}
