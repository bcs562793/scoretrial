import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

void main() async {
  final String? rawUser = Platform.environment['SMTP_USER'];
  final String? rawPass = Platform.environment['SMTP_PASS'];
  final String? rawTo = Platform.environment['MAIL_TO'];

  if (rawUser == null || rawPass == null || rawTo == null) {
    print('Hata: Gerekli e-posta çevresel değişkenleri eksik.');
    exit(1);
  }

  // Verileri temizliyoruz
  final String smtpUser = rawUser.trim();
  final String smtpPass = rawPass.trim().replaceAll(' ', '');
  final String mailTo = rawTo.trim();

  // GITHUB ACTIONS İÇİN ÖZEL PORT 587 AYARI 🚀
  // (gmail() fonksiyonu yerine GitHub sunucularında takılmayan 587 portunu kullanıyoruz)
  final smtpServer = SmtpServer(
    'smtp.gmail.com',
    port: 587,
    username: smtpUser,
    password: smtpPass,
    ssl: false, // Bu ayarın 'false' olması, güvenliğin kapalı olduğu anlamına GELMEZ. 
                // 587 portunda STARTTLS (gelişmiş güvenlik) kullanılacağını sisteme bildirir.
    allowInsecure: false,
  );

  final message = Message()
    ..from = Address(smtpUser, 'Otomasyon Botu')
    ..recipients.add(mailTo)
    ..subject = 'Sistem Bildirimi: Görev Tamamlandı 🚀'
    ..text = 'Merhaba,\n\nBu e-posta, GitHub Actions üzerinden Port 587 kullanılarak sorunsuz bir şekilde ulaştı!';

  try {
    print('Google SMTP Sunucusuna (Port 587) bağlanılıyor...');
    final sendReport = await send(message, smtpServer).timeout(const Duration(seconds: 45));
    print('E-posta BAŞARIYLA gönderildi: ${sendReport.toString()}');
  } catch (e) {
    print('MAALESEF GÖNDERİLEMEDİ: $e');
    exit(1);
  }
}
