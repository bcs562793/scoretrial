import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

void main() async {
  // GitHub Secrets üzerinden gelecek çevresel değişkenleri al
  final String? smtpHost = Platform.environment['SMTP_HOST'];
  final String? smtpPortStr = Platform.environment['SMTP_PORT'];
  final String? smtpUser = Platform.environment['SMTP_USER'];
  final String? smtpPass = Platform.environment['SMTP_PASS'];
  final String? mailTo = Platform.environment['MAIL_TO'];

  if (smtpHost == null || smtpPortStr == null || smtpUser == null || smtpPass == null || mailTo == null) {
    print('Hata: Gerekli SMTP çevresel değişkenleri eksik. Lütfen GitHub Secrets\'ı kontrol edin.');
    exit(1);
  }

  final int smtpPort = int.tryParse(smtpPortStr) ?? 465;

  // SMTP Sunucu yapılandırması
  final smtpServer = SmtpServer(
    smtpHost,
    port: smtpPort,
    username: smtpUser,
    password: smtpPass,
    ssl: smtpPort == 465, // 465 genelde SSL içindir, 587 kullanıyorsan ignoreBadCertificate vb. ayarlar gerekebilir
  );

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
