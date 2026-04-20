import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

void main() async {
  // GitHub Secrets üzerinden gelen şifreleri alıyoruz
  final String? rawUser = Platform.environment['SMTP_USER'];
  final String? rawPass = Platform.environment['SMTP_PASS'];
  final String? rawTo = Platform.environment['MAIL_TO'];

  if (rawUser == null || rawPass == null || rawTo == null) {
    print('Hata: Gerekli e-posta çevresel değişkenleri eksik.');
    exit(1);
  }

  // GÜVENLİK VE TEMİZLİK FİLTRESİ
  // Kopyala-yapıştır yaparken araya sızan boşluk, tırnak veya enter işaretlerini yok eder.
  final String smtpUser = rawUser.replaceAll(RegExp(r'[^a-zA-Z0-9@.\-_]'), '');
  final String smtpPass = rawPass.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''); 
  final String mailTo = rawTo.replaceAll(RegExp(r'[^a-zA-Z0-9@.\-_]'), '');

  // SUNUCU AYARLARI (Port 465 ve Güvenlik Duvarı Aşma)
  final smtpServer = SmtpServer(
    'smtp.gmail.com',
    port: 465,
    username: smtpUser,
    password: smtpPass,
    ssl: true,
    ignoreBadCertificate: true, // GitHub sunucularındaki SSL el sıkışma hatalarını engeller
  );

  // E-POSTA İÇERİĞİ
  final message = Message()
    ..from = Address(smtpUser, 'Otomasyon Botu')
    ..recipients.add(mailTo)
    ..subject = 'Sistem Bildirimi: Başarılı 🎉'
    ..text = 'Merhaba,\n\nBu e-posta, GitHub Actions üzerinden tüm engelleri aşarak sorunsuz bir şekilde ulaştı!\n\nİyi çalışmalar.'
    ..html = '<h3>Tebrikler! 🚀</h3><p>Bu e-posta, <strong>GitHub Actions</strong> üzerinden tüm engelleri aşarak sorunsuz bir şekilde ulaştı!</p><p>İyi çalışmalar.</p>';

  // GÖNDERİM İŞLEMİ
  try {
    print('Google Sunucusuna (Port 465) bağlanılıyor...');
    final sendReport = await send(message, smtpServer).timeout(const Duration(seconds: 30));
    print('E-posta BAŞARIYLA gönderildi: ${sendReport.toString()}');
  } catch (e) {
    print('MAALESEF GÖNDERİLEMEDİ: $e');
    exit(1);
  }
}
