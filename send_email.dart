import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

void main() async {
  // Artık SMTP_HOST ve SMTP_PORT çekmemize gerek yok, gmail() fonksiyonu halledecek
  final String? smtpUser = Platform.environment['SMTP_USER'];
  final String? smtpPass = Platform.environment['SMTP_PASS'];
  final String? mailTo = Platform.environment['MAIL_TO'];

  if (smtpUser == null || smtpPass == null || mailTo == null) {
    print('Hata: Gerekli e-posta çevresel değişkenleri eksik. Lütfen GitHub Secrets\'ı kontrol edin.');
    exit(1);
  }

  // GMAIL İÇİN KESİN ÇÖZÜM 🚀
  // Arka planda güvenli SSL portunu (465) ve doğru host'u otomatik ayarlar
  final smtpServer = gmail(smtpUser, smtpPass);

  // Gönderilecek mesajın detayları
  final message = Message()
    ..from = Address(smtpUser, 'Otomasyon Botu')
    ..recipients.add(mailTo)
    ..subject = 'Sistem Bildirimi: Görev Tamamlandı 🚀'
    ..text = 'Merhaba,\n\nBu e-posta, GitHub Actions üzerinde çalışan Dart botunuz tarafından otomatik olarak gönderilmiştir.\n\nİyi çalışmalar!'
    ..html = '<h3>Merhaba,</h3><p>Bu e-posta, <strong>GitHub Actions</strong> üzerinde çalışan Dart botunuz tarafından otomatik olarak gönderilmiştir.</p><p>İyi çalışmalar!</p>';

  try {
    print('E-posta gönderiliyor...');
    final sendReport = await send(message, smtpServer);
    print('E-posta başarıyla gönderildi: ${sendReport.toString()}');
  } on MailerException catch (e) {
    print('E-posta gönderimi başarısız oldu.');
    for (var p in e.problems) {
      print('Problem: ${p.code}: ${p.msg}');
    }
    exit(1);
  }
}
