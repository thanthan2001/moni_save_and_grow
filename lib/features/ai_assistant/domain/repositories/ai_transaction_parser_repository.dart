import 'package:dartz/dartz.dart';
import 'package:my_clean_app/core/error/failures.dart';
import 'package:my_clean_app/features/ai_assistant/domain/entities/ai_transaction_parse_entity.dart';
import 'package:my_clean_app/features/category/domain/entities/category_entity.dart';

abstract class AiTransactionParserRepository {
  Future<Either<Failure, List<AiTransactionParseEntity>>> parseMessage({
    required String message,
    required List<CategoryEntity> categories,
  });
}
