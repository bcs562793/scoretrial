import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

void main() async {
  // Değişkenleri alıyoruz
  final String? rawUser = Platform.environment['SMTP_USER'];
  final String? rawPass = Platform.environment['SMTP_PASS'];
  final String? rawTo = Platform.environment['MAIL_TO'];

  if (rawUser == null || rawPass == null || rawTo == null) {
    print('Hata: Gerekli e-posta çevresel değişkenleri eksik.');
    exit(1);
  }

  // 1. HAYAT KURTARAN DOKUNUŞ: Trim ve ReplaceAll
  // trim() -> Başındaki ve sonundaki görünmez boşlukları/enterları siler
  // replaceAll(' ', '') -> Şifrenin ortasındaki boşlukları (abcd efgh -> abcdefgh) siler
  final String smtpUser = rawUser.trim();
  final String smtpPass = rawPass.trim().replaceAll(' ', '');
  final String mailTo = rawTo.trim();

  // 2. Sunucu Ayarı
  final smtpServer = gmail(smtpUser, smtpPass);

  // 3. Mesaj
  final message = Message()
    ..from = Address(smtpUser, 'Otomasyon Botu')
    ..recipients.add(mailTo)
    ..subject = 'Sistem Bildirimi: Görev Tamamlandı 🚀'
    ..text = 'Merhaba,\n\nBu e-posta, GitHub Actions üzerinden sorunsuz bir şekilde ulaştı!'
    ..html = '<h3>Tebrikler!</h3><p>Botunuz artık boşluk hatalarına takılmadan çalışıyor.</p>';

  // 4. Gönderim
  try {
    print('E-posta gönderiliyor... (Kullanıcı: $smtpUser)');
    // Timeout süresini manuel 30 saniyeye çekiyoruz ki boşuna 1 dakika beklemesin
    final sendReport = await send(message, smtpServer).timeout(const Duration(seconds: 30));
    print('E-posta BAŞARIYLA gönderildi: ${sendReport.toString()}');
  } catch (e) {
    print('MAALESEF GÖNDERİLEMEDİ: $e');
    exit(1);
  }
}
