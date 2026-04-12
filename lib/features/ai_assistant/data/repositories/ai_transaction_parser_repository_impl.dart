import 'package:dartz/dartz.dart';
import 'dart:convert';

import 'package:my_clean_app/core/error/failures.dart';
import 'package:my_clean_app/features/ai_assistant/data/datasources/gemini_transaction_parser_data_source.dart';
import 'package:my_clean_app/features/ai_assistant/data/services/financial_message_parser_service.dart';
import 'package:my_clean_app/features/ai_assistant/domain/entities/ai_transaction_parse_entity.dart';
import 'package:my_clean_app/features/ai_assistant/domain/repositories/ai_transaction_parser_repository.dart';
import 'package:my_clean_app/features/category/domain/entities/category_entity.dart';

class AiTransactionParserRepositoryImpl
    implements AiTransactionParserRepository {
  final GeminiTransactionParserDataSource geminiDataSource;
  final FinancialMessageParserService parserService;

  AiTransactionParserRepositoryImpl({
    required this.geminiDataSource,
    required this.parserService,
  });

  @override
  Future<Either<Failure, List<AiTransactionParseEntity>>> parseMessage({
    required String message,
    required List<CategoryEntity> categories,
  }) async {
    try {
      final categoriesJson = jsonEncode(
        categories
            .map(
              (e) => {
                'id': e.id,
                'name': e.name,
                'type': _mapCategoryType(e.type),
              },
            )
            .toList(),
      );

      final raw = await geminiDataSource.parseFinancialMessage(
        message: message,
        categoriesJson: categoriesJson,
      );

      final parsed = _parseGeminiResult(raw, categories);
      final fallback = parserService.parse(message, categories);
      final expectedCount = parserService.estimateTransactionCount(message);

      final normalizedParsed =
          _applyRelativeDateCorrections(message, parsed, fallback);

      if (normalizedParsed.isEmpty) {
        return Right(fallback);
      }

      if (_shouldPreferFallback(
        message: message,
        parsed: normalizedParsed,
        fallback: fallback,
        expectedCount: expectedCount,
      )) {
        return Right(fallback);
      }

      return Right(normalizedParsed);
    } catch (_) {
      try {
        final fallback = parserService.parse(message, categories);
        return Right(fallback);
      } catch (_) {
        return const Left(
          CacheFailure(message: 'Không thể phân tích nội dung giao dịch'),
        );
      }
    }
  }

  List<AiTransactionParseEntity> _parseGeminiResult(
    String raw,
    List<CategoryEntity> categories,
  ) {
    final cleaned = _extractJson(raw);
    final decoded = jsonDecode(cleaned);

    final rawItems =
        decoded is List ? decoded.cast<dynamic>() : <dynamic>[decoded];

    final items = <AiTransactionParseEntity>[];
    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) continue;

      final normalizedType = _normalizeType(rawItem['type']);
      final amount = _parseAmount(rawItem['số tiền']);
      final resolvedCategory = _resolveCategory(
        categories: categories,
        type: normalizedType,
        categoryId: (rawItem['category_id'] ?? '').toString(),
        categoryName: (rawItem['category_name'] ?? '').toString(),
      );

      if (resolvedCategory == null) continue;

      final datetime = (rawItem['datetime'] ?? '').toString().trim();
      final rawDescription = (rawItem['description'] ?? '').toString();
      final description = _normalizeDescription(rawDescription);

      items.add(
        AiTransactionParseEntity(
          type: normalizedType,
          amount: amount,
          categoryId: resolvedCategory.id,
          categoryName: resolvedCategory.name,
          description: description,
          datetime: datetime.isEmpty ? 'now' : datetime,
        ),
      );
    }

    return items;
  }

  String _extractJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceAll('```json', '')
          .replaceAll('```JSON', '')
          .replaceAll('```', '')
          .trim();
    }
    return text;
  }

  String _mapCategoryType(TransactionCategoryType type) {
    switch (type) {
      case TransactionCategoryType.income:
        return 'thu nhập';
      case TransactionCategoryType.expense:
        return 'chi phí';
      case TransactionCategoryType.both:
        return 'cả hai';
    }
  }

  String _normalizeType(dynamic rawType) {
    final text = (rawType ?? '').toString().toLowerCase();
    if (text.contains('thu')) return 'thu nhập';
    return 'chi phí';
  }

  int? _parseAmount(dynamic rawAmount) {
    if (rawAmount == null) return null;
    if (rawAmount is int) return _normalizeAmount(rawAmount);
    if (rawAmount is double) return _normalizeAmount(rawAmount.round());

    final text = rawAmount.toString().trim().toLowerCase();
    if (text.isEmpty || text == 'null') return null;

    final hasThousandUnit = text.contains('k') ||
        text.contains('nghin') ||
        text.contains('ngàn') ||
        text.contains('ngan');
    final hasMillionUnit = text.contains('tr') ||
        text.contains('triệu') ||
        text.contains('trieu') ||
        text.contains('m');

    final digits = text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return null;
    final base = int.tryParse(digits);
    if (base == null) return null;

    if (hasMillionUnit) return base * 1000000;
    if (hasThousandUnit) return base * 1000;

    return _normalizeAmount(base);
  }

  int _normalizeAmount(int amount) {
    if (amount > 0 && amount < 1000) {
      return amount * 1000;
    }
    return amount;
  }

  CategoryEntity? _resolveCategory({
    required List<CategoryEntity> categories,
    required String type,
    required String categoryId,
    required String categoryName,
  }) {
    final expectedType = type == 'thu nhập'
        ? TransactionCategoryType.income
        : TransactionCategoryType.expense;

    final byId = categories.where((c) => c.id == categoryId).toList();
    final idMatch =
        byId.where((c) => _isTypeCompatible(c.type, expectedType)).toList();
    if (idMatch.isNotEmpty) return idMatch.first;

    final byName = categories
        .where((c) => c.name.toLowerCase() == categoryName.toLowerCase())
        .where((c) => _isTypeCompatible(c.type, expectedType))
        .toList();
    if (byName.isNotEmpty) return byName.first;

    final fallback = categories
        .where((c) => _isTypeCompatible(c.type, expectedType))
        .toList();
    if (fallback.isEmpty) return categories.isEmpty ? null : categories.first;

    final other =
        fallback.where((c) => c.name.toLowerCase() == 'khác').toList();
    if (other.isNotEmpty) return other.first;

    return fallback.first;
  }

  bool _isTypeCompatible(
    TransactionCategoryType categoryType,
    TransactionCategoryType txType,
  ) {
    return categoryType == TransactionCategoryType.both ||
        categoryType == txType;
  }

  bool _shouldPreferFallback({
    required String message,
    required List<AiTransactionParseEntity> parsed,
    required List<AiTransactionParseEntity> fallback,
    required int expectedCount,
  }) {
    final parsedHasMergedDescription = parsed.any(
        (e) => e.description.contains('//') || e.description.contains(','));

    final parsedHasGenericDescription = parsed.any((e) {
      final normalized = e.description.toLowerCase();
      return normalized == 'giao dịch - ai' ||
          normalized == 'giao dich - ai' ||
          normalized == 'giao dịch từ trợ lí ai - ai' ||
          normalized.contains('giao dịch từ trợ lí ai');
    });

    final parsedHasSuspiciousAmount = parsed.any((e) {
      final amount = e.amount;
      if (amount == null) return false;
      return amount >= 1000 && amount < 10000;
    });

    final parsedTooFew = parsed.length < expectedCount;
    final fallbackLooksBetter = fallback.isNotEmpty &&
        fallback.length >= parsed.length &&
        fallback.length >= expectedCount;

    final parsedHasInvalidRelativeDates = _hasRelativeDateKeywords(message) &&
        _hasSuspiciousRelativeDates(parsed);

    if ((parsedTooFew ||
            parsedHasMergedDescription ||
            parsedHasGenericDescription ||
            parsedHasInvalidRelativeDates ||
            parsedHasSuspiciousAmount) &&
        fallbackLooksBetter) {
      return true;
    }

    final messageLooksMulti = message.contains(',') ||
        message.contains(';') ||
        message.contains('\n');
    if (messageLooksMulti && parsed.length == 1 && fallback.length > 1) {
      return true;
    }

    return false;
  }

  List<AiTransactionParseEntity> _applyRelativeDateCorrections(
    String message,
    List<AiTransactionParseEntity> parsed,
    List<AiTransactionParseEntity> fallback,
  ) {
    if (!_hasRelativeDateKeywords(message)) {
      return parsed;
    }

    if (parsed.length != fallback.length) {
      return parsed;
    }

    final merged = <AiTransactionParseEntity>[];
    for (var i = 0; i < parsed.length; i++) {
      final candidateDate = fallback[i].datetime;
      if (candidateDate.isEmpty) {
        merged.add(parsed[i]);
        continue;
      }

      merged.add(parsed[i].copyWith(datetime: candidateDate));
    }

    return merged;
  }

  bool _hasRelativeDateKeywords(String message) {
    final text = message.toLowerCase();
    return text.contains('hôm qua') ||
        text.contains('hom qua') ||
        text.contains('hôm nay') ||
        text.contains('hom nay') ||
        text.contains('hôm kia') ||
        text.contains('hom kia') ||
        text.contains('ngày mai') ||
        text.contains('ngay mai');
  }

  bool _hasSuspiciousRelativeDates(List<AiTransactionParseEntity> parsed) {
    final now = DateTime.now();
    for (final item in parsed) {
      if (item.datetime == 'now') continue;
      final parsedDate = DateTime.tryParse(item.datetime);
      if (parsedDate == null) return true;

      // If Gemini returns dates too far from today for relative expressions,
      // prefer local fallback that resolves Vietnamese relative phrases.
      final diffInDays = parsedDate.difference(now).inDays.abs();
      if (diffInDays > 7 && parsedDate.year != now.year) {
        return true;
      }
    }
    return false;
  }

  String _normalizeDescription(String input) {
    var cleaned = input.trim();

    cleaned = cleaned.replaceAll(
      RegExp(
        r'(-?\d[\d\.,\s]*)(?:\s*(k|nghìn|nghin|ngàn|ngan|tr|triệu|trieu|m|đ|vnd|dong))?',
        caseSensitive: false,
      ),
      '',
    );

    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(hom nay|hôm nay|hom qua|hôm qua|hom kia|hôm kia|ngay mai|ngày mai|luc|lúc|vao|vào)\b',
        caseSensitive: false,
      ),
      '',
    );

    cleaned = cleaned.replaceAll('/', ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[,.:;\-\s]+|[,.:;\-\s]+$'), '');

    if (cleaned.isEmpty ||
        cleaned.toLowerCase().contains('giao dịch từ trợ lí')) {
      cleaned = 'Giao dịch';
    }

    if (cleaned.toLowerCase().endsWith('- ai')) {
      return cleaned;
    }

    return '$cleaned - AI';
  }
}
