import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:my_clean_app/core/configs/app_env.dart';

class GeminiTransactionParserDataSource {
  GeminiTransactionParserDataSource();

  Future<String> parseFinancialMessage({
    required String message,
    required String categoriesJson,
  }) async {
    final apiKey = AppEnv.geminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception('Thiếu GEMINI_API_KEY trong .env');
    }

    final model = GenerativeModel(
      model: 'gemini-3.1-flash-lite-preview',
      apiKey: apiKey,
    );

    final prompt = _buildPrompt(
      message: message,
      categoriesJson: categoriesJson,
    );

    final response = await model.generateContent([
      Content.text(prompt),
    ]);

    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini không trả về nội dung hợp lệ');
    }

    return text.trim();
  }

  String _buildPrompt({
    required String message,
    required String categoriesJson,
  }) {
    return '''Bạn là Trợ lý tài chính AI. Nhiệm vụ của bạn là chuyển đổi tin nhắn trò chuyện của người dùng thành dữ liệu giao dịch tài chính có cấu trúc.

Từ tin nhắn, trích xuất:
- loại (thu nhập hoặc chi phí)
- số tiền (số tính bằng VNĐ)
- category_id (phải khớp với một trong các danh mục được cung cấp)
- category_name
- mô tả (văn bản ngắn gọn đã được làm sạch)
- ngày giờ (chuỗi ISO hoặc "now" nếu không được chỉ định)

CHỈ sử dụng các danh mục được cung cấp bên dưới và KHÔNG BAO GIỜ tạo danh mục mới; luôn chọn kết quả phù hợp nhất dựa trên từ khóa và ý nghĩa ngữ nghĩa, đồng thời đảm bảo loại danh mục khớp với loại giao dịch.

Danh mục:
$categoriesJson

Xác định loại là chi phí nếu tiền ra và thu nhập nếu tiền vào.
Chuẩn hóa các số tiền như "50k" -> 50000, "50" -> 50000, "2 triệu" -> 2000000, "2tr" -> 2000000, "100.000" -> 100000.
Quy tắc bắt buộc: nếu người dùng nhập số nguyên nhỏ (<1000) trong ngữ cảnh chi tiêu/thu nhập (ví dụ "ăn sáng 50"), hãy hiểu là đơn vị nghìn VND, tức nhân 1000.
Nếu ngày giờ không được đề cập, hãy sử dụng "now"; nếu các cụm từ như "hôm qua" xuất hiện, hãy chuyển đổi chúng nếu có thể.
Nếu thông báo chứa nhiều giao dịch, hãy trả về một mảng đối tượng.
Tuyệt đối KHÔNG gộp nhiều giao dịch thành một object; mỗi giao dịch phải là một object riêng với đúng số tiền và đúng category tương ứng.
Quy tắc mô tả bắt buộc: mô tả phải lấy từ nội dung người dùng, chỉ giữ phần hành động chi tiêu/thu nhập, bỏ số tiền và mốc thời gian. Ví dụ: "hôm qua ăn trưa 50" -> "ăn trưa - AI", "21/01/2026 nhận lương 20tr" -> "nhận lương - AI".

Luôn trả về CHỈ JSON hợp lệ mà không có lời giải thích, không đánh dấu và không có văn bản bổ sung.

Định dạng đầu ra (đơn):
{ "type": "thu nhập | chi phí", "số tiền": số, "category_id": string, "category_name": string, "description": string, "datetime": string }

hoặc (nhiều):
[ { ... }, { ... } ]

Nếu thiếu số tiền, hãy đặt "số tiền": null.
Luôn trả về kết quả tốt nhất có thể.

Tin nhắn người dùng:
$message''';
  }
}
