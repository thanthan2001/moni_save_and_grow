import 'package:my_clean_app/features/ai_assistant/domain/entities/ai_transaction_parse_entity.dart';
import 'package:my_clean_app/features/category/domain/entities/category_entity.dart';

class FinancialMessageParserService {
  List<AiTransactionParseEntity> parse(
    String message,
    List<CategoryEntity> categories,
  ) {
    final text = message.trim();
    if (text.isEmpty) return [];

    final chunks = _splitIntoChunks(text);
    final results = <AiTransactionParseEntity>[];

    for (final chunk in chunks) {
      final parsed = _parseSingleChunk(chunk, categories);
      if (parsed != null) {
        results.add(parsed);
      }
    }

    if (results.isEmpty) {
      final fallback = _parseSingleChunk(text, categories);
      if (fallback != null) {
        return [fallback];
      }
    }

    return results;
  }

  List<String> _splitIntoChunks(String message) {
    final segments = message
        .split(
          RegExp(r'\n|;|,\s+|\s+rồi\s+|\s+sau đó\s+|\s+tiếp theo\s+'),
        )
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return segments.isEmpty ? [message] : segments;
  }

  AiTransactionParseEntity? _parseSingleChunk(
    String chunk,
    List<CategoryEntity> categories,
  ) {
    final amount = _extractAmount(chunk);
    final detectedType = _detectType(chunk);
    final matchedCategory =
        _matchCategory(chunk, categories, preferredType: detectedType);

    final resolvedType = _resolveType(
      detectedType: detectedType,
      matchedCategory: matchedCategory,
    );

    final finalCategory = _ensureCategoryCompatibility(
      categories: categories,
      resolvedType: resolvedType,
      currentCategory: matchedCategory,
    );

    if (finalCategory == null) return null;

    return AiTransactionParseEntity(
      type: resolvedType == TransactionCategoryType.income
          ? 'thu nhập'
          : 'chi phí',
      amount: amount,
      categoryId: finalCategory.id,
      categoryName: finalCategory.name,
      description: _cleanDescription(chunk),
      datetime: _extractDateTime(chunk),
    );
  }

  int? _extractAmount(String text) {
    final amountRegex = RegExp(
      r'(-?\d[\d\.,\s]*)(?:\s*(k|nghìn|nghin|ngàn|ngan|tr|triệu|trieu|m|đ|vnd|dong))?',
      caseSensitive: false,
    );

    final matches = amountRegex.allMatches(text);
    int? bestValue;
    var bestScore = -1;

    for (final match in matches) {
      if (_isDatePart(text, match.start, match.end)) {
        continue;
      }

      final rawNumber = (match.group(1) ?? '').trim();
      if (rawNumber.isEmpty) continue;

      final unit = (match.group(2) ?? '').toLowerCase();
      final digits = rawNumber.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.isEmpty) continue;

      var value = int.tryParse(digits);
      if (value == null) continue;

      var score = 1;

      if (unit == 'k' ||
          unit == 'nghìn' ||
          unit == 'nghin' ||
          unit == 'ngàn' ||
          unit == 'ngan') {
        value *= 1000;
        score = 3;
      } else if (unit == 'tr' ||
          unit == 'triệu' ||
          unit == 'trieu' ||
          unit == 'm') {
        value *= 1000000;
        score = 4;
      } else {
        // Heuristic for Vietnamese chat: "50" usually means 50k VND.
        if (value > 0 && value < 1000) {
          value *= 1000;
        }
      }

      if (rawNumber.contains('.') || rawNumber.contains(',')) {
        score += 1;
      }

      if (score > bestScore ||
          (score == bestScore && value > (bestValue ?? 0))) {
        bestScore = score;
        bestValue = value;
      }
    }

    return bestValue;
  }

  bool _isDatePart(String text, int start, int end) {
    final hasSlashBefore = start > 0 && text[start - 1] == '/';
    final hasSlashAfter = end < text.length && text[end] == '/';
    return hasSlashBefore || hasSlashAfter;
  }

  int estimateTransactionCount(String message) {
    final chunks = _splitIntoChunks(message);
    final meaningfulChunks = chunks.where((chunk) {
      final normalized = _normalize(chunk);
      final hasAmount = _extractAmount(chunk) != null;
      final hasAction = _detectType(chunk) != null ||
          normalized.contains('an') ||
          normalized.contains('uong') ||
          normalized.contains('nhan') ||
          normalized.contains('luong') ||
          normalized.contains('mua') ||
          normalized.contains('chi');
      return hasAmount || hasAction;
    }).length;

    return meaningfulChunks == 0 ? 1 : meaningfulChunks;
  }

  TransactionCategoryType? _detectType(String text) {
    final normalized = _normalize(text);

    const incomeKeywords = [
      'thu',
      'nhan',
      'duoc cho',
      'luong',
      'thuong',
      'ban',
      'co tuc',
      'hoan tien',
      'lai',
      'tien vao',
    ];

    const expenseKeywords = [
      'chi',
      'mua',
      'tra',
      'thanh toan',
      'dong',
      'an',
      'uong',
      'xang',
      'tien ra',
      'rut tien',
      'mat tien',
      'nop',
      'chuyen khoan',
    ];

    final hasIncome = incomeKeywords.any(normalized.contains);
    final hasExpense = expenseKeywords.any(normalized.contains);

    if (hasIncome && !hasExpense) return TransactionCategoryType.income;
    if (hasExpense && !hasIncome) return TransactionCategoryType.expense;
    return null;
  }

  CategoryEntity? _matchCategory(
    String text,
    List<CategoryEntity> categories, {
    TransactionCategoryType? preferredType,
  }) {
    if (categories.isEmpty) return null;

    final normalizedText = _normalize(text);
    final typedCandidates = categories.where((category) {
      if (preferredType == null) return true;
      if (category.type == TransactionCategoryType.both) return true;
      return category.type == preferredType;
    }).toList();

    final candidates = typedCandidates.isEmpty ? categories : typedCandidates;

    CategoryEntity? best;
    var bestScore = -1;

    for (final category in candidates) {
      var score = 0;
      final name = _normalize(category.name);

      if (normalizedText.contains(name)) {
        score += 5;
      }

      for (final keyword in _keywordsForCategory(category)) {
        if (normalizedText.contains(keyword)) {
          score += 2;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = category;
      }
    }

    if (bestScore <= 0) {
      return _fallbackCategory(candidates, preferredType);
    }

    return best;
  }

  CategoryEntity? _ensureCategoryCompatibility({
    required List<CategoryEntity> categories,
    required TransactionCategoryType resolvedType,
    required CategoryEntity? currentCategory,
  }) {
    if (currentCategory != null) {
      final ok = currentCategory.type == TransactionCategoryType.both ||
          currentCategory.type == resolvedType;
      if (ok) return currentCategory;
    }

    return _fallbackCategory(categories, resolvedType);
  }

  CategoryEntity? _fallbackCategory(
    List<CategoryEntity> categories,
    TransactionCategoryType? preferredType,
  ) {
    if (categories.isEmpty) return null;

    final typeMatches = categories.where((c) {
      if (preferredType == null) return true;
      return c.type == preferredType || c.type == TransactionCategoryType.both;
    }).toList();

    if (typeMatches.isEmpty) return categories.first;

    final other =
        typeMatches.where((c) => _normalize(c.name) == 'khac').toList();
    if (other.isNotEmpty) return other.first;

    return typeMatches.first;
  }

  TransactionCategoryType _resolveType({
    required TransactionCategoryType? detectedType,
    required CategoryEntity? matchedCategory,
  }) {
    if (detectedType != null) return detectedType;

    if (matchedCategory != null &&
        matchedCategory.type != TransactionCategoryType.both) {
      return matchedCategory.type;
    }

    return TransactionCategoryType.expense;
  }

  List<String> _keywordsForCategory(CategoryEntity category) {
    final normalizedName = _normalize(category.name);
    final baseKeywords = [normalizedName];

    const idKeywords = {
      'food': ['an', 'uong', 'com', 'pho', 'ca phe', 'tra sua'],
      'transport': ['xang', 'grab', 'taxi', 'gui xe', 'di chuyen'],
      'shopping': ['mua sam', 'quan ao', 'giay', 'shopping', 'shop'],
      'entertainment': ['giai tri', 'xem phim', 'game', 'karaoke'],
      'health': ['suc khoe', 'thuoc', 'benh vien', 'kham'],
      'education': ['hoc phi', 'khoa hoc', 'sach', 'giao duc'],
      'salary': ['luong', 'salary'],
      'bonus': ['thuong', 'bonus'],
      'investment': ['dau tu', 'co tuc', 'chung khoan', 'lai'],
      'other': ['khac', 'linh tinh'],
    };

    return [
      ...baseKeywords,
      ...(idKeywords[category.id] ?? const []),
    ];
  }

  String _extractDateTime(String text) {
    final now = DateTime.now();
    final normalized = _normalize(text);

    DateTime? date;

    if (normalized.contains('hom qua')) {
      date = now.subtract(const Duration(days: 1));
    } else if (normalized.contains('hom kia')) {
      date = now.subtract(const Duration(days: 2));
    } else if (normalized.contains('ngay mai') || normalized.contains('mai')) {
      date = now.add(const Duration(days: 1));
    } else if (normalized.contains('hom nay')) {
      date = now;
    }

    final fullDateTimeRegex = RegExp(
      r'(\d{4})-(\d{1,2})-(\d{1,2})(?:[ t](\d{1,2})[:h](\d{1,2}))?',
    );
    final slashDateRegex = RegExp(r'(\d{1,2})[/-](\d{1,2})(?:[/-](\d{2,4}))?');
    final timeRegex = RegExp(r'(\d{1,2})[:h](\d{1,2})');

    final isoMatch = fullDateTimeRegex.firstMatch(text);
    if (isoMatch != null) {
      final year = int.parse(isoMatch.group(1)!);
      final month = int.parse(isoMatch.group(2)!);
      final day = int.parse(isoMatch.group(3)!);
      final hour = int.tryParse(isoMatch.group(4) ?? '') ?? 0;
      final minute = int.tryParse(isoMatch.group(5) ?? '') ?? 0;
      return DateTime(year, month, day, hour, minute).toIso8601String();
    }

    final slashMatch = slashDateRegex.firstMatch(text);
    if (slashMatch != null) {
      final day = int.parse(slashMatch.group(1)!);
      final month = int.parse(slashMatch.group(2)!);
      final yearText = slashMatch.group(3);
      final year = yearText == null
          ? now.year
          : (yearText.length == 2
              ? 2000 + int.parse(yearText)
              : int.parse(yearText));
      date = DateTime(year, month, day);
    }

    final timeMatch = timeRegex.firstMatch(text);
    if (timeMatch != null) {
      final hour = int.parse(timeMatch.group(1)!);
      final minute = int.parse(timeMatch.group(2)!);
      final base = date ?? now;
      return DateTime(base.year, base.month, base.day, hour, minute)
          .toIso8601String();
    }

    if (date != null) {
      return date.toIso8601String();
    }

    return 'now';
  }

  String _cleanDescription(String text) {
    var cleaned = text;

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

    if (cleaned.isEmpty) {
      return 'Giao dịch - AI';
    }

    if (cleaned.toLowerCase().endsWith('- ai')) {
      return cleaned;
    }

    return '$cleaned - AI';
  }

  String _normalize(String input) {
    return _removeVietnameseDiacritics(input.toLowerCase())
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _removeVietnameseDiacritics(String str) {
    final withDia = 'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệ'
        'íìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđ';
    final withoutDia = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiii'
        'ooooooooooooooooouuuuuuuuuuuyyyyyd';

    var output = str;
    for (var i = 0; i < withDia.length; i++) {
      output = output.replaceAll(withDia[i], withoutDia[i]);
    }
    return output;
  }
}
