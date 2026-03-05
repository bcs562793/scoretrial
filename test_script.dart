import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Örnek ID'ler (Bir önceki eşleştirmeden bulduğumuz Lanus - Boca Juniors veya başka bir maç)
  int apiFootballId = 1491915; 
  int mackolikId = 4432754; // Sizin verdiğiniz örnek ID'leri de buraya koyabiliriz (örn: 4296370)
  
  String apiFootballKey = "API_KEYINIZI_BURAYA_YAZIN"; 

  print("ScorePop Ultra-Hızlı Detay Motoru Başlatıldı...\n");

  try {
    // 1. İSTEKLERİ HAZIRLA
    // Tarayıcı gibi davranmak için standart Headers
    Map<String, String> macHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'application/json, text/javascript, */*; q=0.01',
    };

    // API-Football: Canlı Skor İstegi
    var apiRequest = http.get(
      Uri.parse('https://v3.football.api-sports.io/fixtures?id=$apiFootballId'),
      headers: {'x-apisports-key': apiFootballKey},
    );

    // Maçkolik: Kadro ve Olaylar (MatchData)
    var macDataRequest = http.get(
      Uri.parse('https://arsiv.mackolik.com/Match/MatchData.aspx?t=dtl&id=$mackolikId&s=0'),
      headers: macHeaders,
    );

    // Maçkolik: Geçmiş Maçlar (H2H)
    var macH2HRequest = http.get(
      Uri.parse('https://arsiv.mackolik.com/Match/Head2Head.aspx?id=$mackolikId&s=1'),
      headers: macHeaders,
    );

    // Maçkolik: Puan Durumu (Standings)
    var macStandingRequest = http.get(
      Uri.parse('https://arsiv.mackolik.com/AjaxHandlers/StandingHandler.aspx?command=matchStanding&id=$mackolikId&sv=1'),
      headers: macHeaders,
    );

    // 2. PARALEL İŞLEME (4 İsteği aynı anda fırlat ve bekle)
    print("🚀 4 Farklı kaynaktan veriler paralel olarak çekiliyor...");
    var results = await Future.wait([
      apiRequest, 
      macDataRequest, 
      macH2HRequest, 
      macStandingRequest
    ]);

    var apiRes = results[0];
    var dataRes = results[1];
    var h2hRes = results[2];
    var standingRes = results[3];

    print("✅ Tüm veriler başarıyla indi!\n");

    // 3. YANITLARI KONTROL ET
    print("--- DURUM RAPORU ---");
    
    if (apiRes.statusCode == 200) {
       // var apiJson = json.decode(apiRes.body);
       print("⚽ API-Football (Skor): BAŞARILI");
    }

    if (dataRes.statusCode == 200) {
       print("📋 Maçkolik (Kadro & Olaylar): BAŞARILI (${dataRes.body.length} byte)");
       // Önizleme: İlk 100 karakteri görelim ki JSON mu yoksa HTML mi anlarız
       print("   Önizleme: ${dataRes.body.substring(0, 80).replaceAll('\n', '')}...");
    }

    if (h2hRes.statusCode == 200) {
       print("⚔️ Maçkolik (H2H): BAŞARILI (${h2hRes.body.length} byte)");
    }

    if (standingRes.statusCode == 200) {
       print("📊 Maçkolik (Puan Durumu): BAŞARILI (${standingRes.body.length} byte)");
    }

  } catch (e) {
    print("❌ Sistem Hatası: $e");
  }
}
