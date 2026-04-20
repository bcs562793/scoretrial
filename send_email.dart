import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final String? apiKey = Platform.environment['SENDGRID_API_KEY'];
  final String? mailTo  = Platform.environment['MAIL_TO'];
  final String? mailFrom = Platform.environment['MAIL_FROM']; // SendGrid'de doğrulanmış adres

  if (apiKey == null || mailTo == null || mailFrom == null) {
    print('Hata: Gerekli çevresel değişkenler eksik.');
    exit(1);
  }

  final body = jsonEncode({
    "personalizations": [
      {
        "to": [{"email": mailTo}]
      }
    ],
    "from": {"email": mailFrom, "name": "Otomasyon Botu"},
    "subject": "Sistem Bildirimi: Başarılı 🎉",
    "content": [
      {
        "type": "text/html",
        "value": "<h3>Tebrikler! 🚀</h3><p>GitHub Actions üzerinden sorunsuz ulaştı!</p>"
      }
    ]
  });

  try {
    print('SendGrid API\'ye istek gönderiliyor...');
    final response = await http.post(
      Uri.parse('https://api.sendgrid.com/v3/mail/send'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 202) {
      print('E-posta BAŞARIYLA gönderildi! (HTTP 202)');
    } else {
      print('Hata: ${response.statusCode} - ${response.body}');
      exit(1);
    }
  } catch (e) {
    print('GÖNDERILEMEDI: $e');
    exit(1);
  }
}
