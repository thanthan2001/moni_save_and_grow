import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:my_clean_app/core/error/failures.dart';
import 'package:my_clean_app/core/usecases/usecase.dart';
import 'package:my_clean_app/features/ai_assistant/domain/entities/ai_transaction_parse_entity.dart';
import 'package:my_clean_app/features/ai_assistant/domain/repositories/ai_transaction_parser_repository.dart';
import 'package:my_clean_app/features/category/domain/entities/category_entity.dart';

class ParseFinancialMessageUseCase
    implements
        UseCase<List<AiTransactionParseEntity>, ParseFinancialMessageParams> {
  final AiTransactionParserRepository repository;

  ParseFinancialMessageUseCase(this.repository);

  @override
  Future<Either<Failure, List<AiTransactionParseEntity>>> call(
    ParseFinancialMessageParams params,
  ) {
    return repository.parseMessage(
      message: params.message,
      categories: params.categories,
    );
  }
}

class ParseFinancialMessageParams extends Equatable {
  final String message;
  final List<CategoryEntity> categories;

  const ParseFinancialMessageParams({
    required this.message,
    required this.categories,
  });

  @override
  List<Object?> get props => [message, categories];
}
