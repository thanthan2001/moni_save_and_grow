import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_clean_app/core/usecases/usecase.dart';
import 'package:my_clean_app/features/ai_assistant/domain/usecases/parse_financial_message_usecase.dart';
import 'package:my_clean_app/features/ai_assistant/presentation/bloc/ai_assistant_event.dart';
import 'package:my_clean_app/features/ai_assistant/presentation/bloc/ai_assistant_state.dart';
import 'package:my_clean_app/features/transaction/domain/entities/transaction_entity.dart';
import 'package:my_clean_app/features/transaction/domain/usecases/add_transaction_usecase.dart';
import 'package:my_clean_app/features/transaction/domain/usecases/get_all_categories_usecase.dart';

import '../../domain/entities/ai_transaction_parse_entity.dart';

class AiAssistantBloc extends Bloc<AiAssistantEvent, AiAssistantState> {
  final ParseFinancialMessageUseCase parseFinancialMessageUseCase;
  final GetAllCategoriesUseCase getAllCategoriesUseCase;
  final AddTransactionUseCase addTransactionUseCase;

  AiAssistantBloc({
    required this.parseFinancialMessageUseCase,
    required this.getAllCategoriesUseCase,
    required this.addTransactionUseCase,
  }) : super(const AiAssistantState()) {
    on<LoadAiAssistantContext>(_onLoadContext);
    on<ParseAiMessage>(_onParseMessage);
    on<SaveParsedTransactions>(_onSaveParsedTransactions);
    on<SaveParsedTransaction>(_onSaveParsedTransaction);
    on<UpdateParsedTransaction>(_onUpdateParsedTransaction);
    on<RemoveParsedTransaction>(_onRemoveParsedTransaction);
    on<ClearParsedTransactions>(_onClearParsedTransactions);
  }

  Future<void> _onLoadContext(
    LoadAiAssistantContext event,
    Emitter<AiAssistantState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));

    final result = await getAllCategoriesUseCase(NoParams());
    result.fold(
      (_) => emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể tải danh mục để phân tích AI',
      )),
      (categories) => emit(state.copyWith(
        isLoading: false,
        categories: categories,
      )),
    );
  }

  Future<void> _onParseMessage(
    ParseAiMessage event,
    Emitter<AiAssistantState> emit,
  ) async {
    if (state.isLoading) {
      return;
    }

    final message = event.message.trim();
    if (message.isEmpty) {
      emit(state.copyWith(errorMessage: 'Vui lòng nhập nội dung tin nhắn'));
      return;
    }

    var categories = state.categories;
    if (categories.isEmpty) {
      final categoriesResult = await getAllCategoriesUseCase(NoParams());
      categories = categoriesResult.getOrElse(() => []);
    }

    if (categories.isEmpty) {
      emit(state.copyWith(errorMessage: 'Không có danh mục để đối chiếu'));
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));

    final result = await parseFinancialMessageUseCase(
      ParseFinancialMessageParams(message: message, categories: categories),
    );

    result.fold(
      (_) => emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Không thể phân tích nội dung giao dịch',
      )),
      (parsedTransactions) {
        if (parsedTransactions.isEmpty) {
          emit(state.copyWith(
            isLoading: false,
            parsedTransactions: const [],
            rawJson: '[]',
            errorMessage: 'Không tìm thấy giao dịch hợp lệ trong tin nhắn',
          ));
          return;
        }

        final jsonResult = parsedTransactions.length == 1
            ? parsedTransactions.first.toRuleJson()
            : parsedTransactions.map((e) => e.toRuleJson()).toList();

        emit(state.copyWith(
          isLoading: false,
          parsedTransactions: parsedTransactions,
          rawJson: const JsonEncoder.withIndent('  ').convert(jsonResult),
          successMessage: 'Đã phân tích ${parsedTransactions.length} giao dịch',
        ));
      },
    );
  }

  Future<void> _onSaveParsedTransactions(
    SaveParsedTransactions event,
    Emitter<AiAssistantState> emit,
  ) async {
    final parsed = state.parsedTransactions;
    if (parsed.isEmpty) {
      emit(state.copyWith(errorMessage: 'Chưa có giao dịch để lưu'));
      return;
    }

    emit(state.copyWith(
      isSaving: true,
      clearError: true,
      clearSuccess: true,
      clearSavingIndex: true,
    ));

    var successCount = 0;
    var skippedCount = 0;

    for (var i = 0; i < parsed.length; i++) {
      final item = parsed[i];
      final amount = item.amount;

      if (amount == null || amount <= 0) {
        skippedCount++;
        continue;
      }

      final result = await _saveSingle(item, i);

      if (result.isRight()) {
        successCount++;
      }
    }

    emit(state.copyWith(
      isSaving: false,
      parsedTransactions: const [],
      rawJson: '[]',
      clearSavingIndex: true,
      successMessage:
          'Đã lưu $successCount giao dịch${skippedCount > 0 ? ', bỏ qua $skippedCount giao dịch thiếu số tiền' : ''}',
    ));
  }

  Future<void> _onSaveParsedTransaction(
    SaveParsedTransaction event,
    Emitter<AiAssistantState> emit,
  ) async {
    if (state.isSaving) return;
    if (event.index < 0 || event.index >= state.parsedTransactions.length) {
      emit(state.copyWith(errorMessage: 'Giao dịch không hợp lệ'));
      return;
    }

    final item = state.parsedTransactions[event.index];
    if (item.amount == null || item.amount! <= 0) {
      emit(state.copyWith(errorMessage: 'Số tiền phải lớn hơn 0'));
      return;
    }

    emit(state.copyWith(
      isSaving: true,
      savingIndex: event.index,
      clearError: true,
      clearSuccess: true,
    ));

    final result = await _saveSingle(item, event.index);
    result.fold(
      (_) => emit(state.copyWith(
        isSaving: false,
        clearSavingIndex: true,
        errorMessage: 'Không thể lưu giao dịch #${event.index + 1}',
      )),
      (_) {
        final remaining =
            List<AiTransactionParseEntity>.from(state.parsedTransactions)
              ..removeAt(event.index);

        emit(state.copyWith(
          isSaving: false,
          clearSavingIndex: true,
          parsedTransactions: remaining,
          rawJson: _toRawJson(remaining),
          successMessage: 'Đã lưu giao dịch #${event.index + 1}',
        ));
      },
    );
  }

  void _onUpdateParsedTransaction(
    UpdateParsedTransaction event,
    Emitter<AiAssistantState> emit,
  ) {
    if (event.index < 0 || event.index >= state.parsedTransactions.length) {
      return;
    }

    final updated =
        List<AiTransactionParseEntity>.from(state.parsedTransactions);
    updated[event.index] = event.transaction;

    final jsonResult = updated.length == 1
        ? updated.first.toRuleJson()
        : updated.map((e) => e.toRuleJson()).toList();

    emit(state.copyWith(
      parsedTransactions: updated,
      rawJson: const JsonEncoder.withIndent('  ').convert(jsonResult),
      clearError: true,
      clearSuccess: true,
    ));
  }

  void _onRemoveParsedTransaction(
    RemoveParsedTransaction event,
    Emitter<AiAssistantState> emit,
  ) {
    if (event.index < 0 || event.index >= state.parsedTransactions.length) {
      return;
    }

    final remaining =
        List<AiTransactionParseEntity>.from(state.parsedTransactions)
          ..removeAt(event.index);

    emit(state.copyWith(
      parsedTransactions: remaining,
      rawJson: _toRawJson(remaining),
      clearError: true,
      successMessage: 'Đã xóa giao dịch #${event.index + 1}',
    ));
  }

  String _toRawJson(List<AiTransactionParseEntity> transactions) {
    if (transactions.isEmpty) return '[]';
    final jsonResult = transactions.length == 1
        ? transactions.first.toRuleJson()
        : transactions.map((e) => e.toRuleJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonResult);
  }

  Future<dynamic> _saveSingle(AiTransactionParseEntity item, int index) {
    final type = item.type == 'thu nhập'
        ? TransactionType.income
        : TransactionType.expense;

    final date = item.datetime == 'now'
        ? DateTime.now()
        : (DateTime.tryParse(item.datetime) ?? DateTime.now());

    final transaction = TransactionEntity(
      id: '${DateTime.now().millisecondsSinceEpoch}_$index',
      amount: item.amount!.toDouble(),
      description: item.description,
      date: date,
      categoryId: item.categoryId,
      type: type,
    );

    return addTransactionUseCase(
      AddTransactionParams(transaction: transaction),
    );
  }

  void _onClearParsedTransactions(
    ClearParsedTransactions event,
    Emitter<AiAssistantState> emit,
  ) {
    emit(state.copyWith(
      parsedTransactions: const [],
      rawJson: '',
      clearSavingIndex: true,
      clearError: true,
      clearSuccess: true,
    ));
  }
}
