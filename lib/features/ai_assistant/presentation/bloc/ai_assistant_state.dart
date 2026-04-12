import 'package:equatable/equatable.dart';
import 'package:my_clean_app/features/ai_assistant/domain/entities/ai_transaction_parse_entity.dart';
import 'package:my_clean_app/features/category/domain/entities/category_entity.dart';

class AiAssistantState extends Equatable {
  final bool isLoading;
  final bool isSaving;
  final int? savingIndex;
  final List<CategoryEntity> categories;
  final List<AiTransactionParseEntity> parsedTransactions;
  final String rawJson;
  final String? errorMessage;
  final String? successMessage;

  const AiAssistantState({
    this.isLoading = false,
    this.isSaving = false,
    this.savingIndex,
    this.categories = const [],
    this.parsedTransactions = const [],
    this.rawJson = '',
    this.errorMessage,
    this.successMessage,
  });

  AiAssistantState copyWith({
    bool? isLoading,
    bool? isSaving,
    int? savingIndex,
    List<CategoryEntity>? categories,
    List<AiTransactionParseEntity>? parsedTransactions,
    String? rawJson,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearSavingIndex = false,
  }) {
    return AiAssistantState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      savingIndex: clearSavingIndex ? null : (savingIndex ?? this.savingIndex),
      categories: categories ?? this.categories,
      parsedTransactions: parsedTransactions ?? this.parsedTransactions,
      rawJson: rawJson ?? this.rawJson,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        isSaving,
        savingIndex,
        categories,
        parsedTransactions,
        rawJson,
        errorMessage,
        successMessage,
      ];
}
