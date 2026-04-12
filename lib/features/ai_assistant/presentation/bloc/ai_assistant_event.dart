import 'package:equatable/equatable.dart';
import 'package:my_clean_app/features/ai_assistant/domain/entities/ai_transaction_parse_entity.dart';

abstract class AiAssistantEvent extends Equatable {
  const AiAssistantEvent();

  @override
  List<Object?> get props => [];
}

class LoadAiAssistantContext extends AiAssistantEvent {
  const LoadAiAssistantContext();
}

class ParseAiMessage extends AiAssistantEvent {
  final String message;

  const ParseAiMessage({required this.message});

  @override
  List<Object?> get props => [message];
}

class SaveParsedTransactions extends AiAssistantEvent {
  const SaveParsedTransactions();
}

class SaveParsedTransaction extends AiAssistantEvent {
  final int index;

  const SaveParsedTransaction({required this.index});

  @override
  List<Object?> get props => [index];
}

class UpdateParsedTransaction extends AiAssistantEvent {
  final int index;
  final AiTransactionParseEntity transaction;

  const UpdateParsedTransaction({
    required this.index,
    required this.transaction,
  });

  @override
  List<Object?> get props => [index, transaction];
}

class RemoveParsedTransaction extends AiAssistantEvent {
  final int index;

  const RemoveParsedTransaction({required this.index});

  @override
  List<Object?> get props => [index];
}

class ClearParsedTransactions extends AiAssistantEvent {
  const ClearParsedTransactions();
}
