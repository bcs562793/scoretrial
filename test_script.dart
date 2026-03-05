import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Örnek ID'ler
  int apiFootballId = 1491915; 
  int mackolikId = 4432754; // Sizin bulduğunuz 4296370 ID'sini de deneyebilirsiniz
  
  String apiFootballKey = "API_KEYINIZI_BURAYA_YAZIN"; 

  print("ScorePop Veri İnceleme (X-Ray) Modu Başlatıldı...\n");

  try {
    Map<String, String> macHeaders = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': '*/*',
    };

    var apiRequest = http.get(
      Uri.parse('https://v3.football.api-sports.io/fixtures?id=$apiFootballId'),
      headers: {'x-apisports-key': apiFootballKey},
    );

    var macDataRequest = http.get(
      Uri.parse('https://arsiv.mackolik.com/Match/MatchData.aspx?t=dtl&id=$mackolikId&s=0'),
      headers: macHeaders,
    );

    var macH2HRequest = http.get(
      Uri.parse('https://arsiv.mackolik.com/Match/Head2Head.aspx?id=$mackolikId&s=1'),
      headers: macHeaders,
    );

    var macStandingRequest = http.get(
      Uri.parse('https://arsiv.mackolik.com/AjaxHandlers/StandingHandler.aspx?command=matchStanding&id=$mackolikId&sv=1'),
      headers: macHeaders,
    );

    print("Veriler çekiliyor, lütfen bekleyin...\n");
    var results = await Future.wait([
      apiRequest, 
      macDataRequest, 
      macH2HRequest, 
      macStandingRequest
    ]);

    // Çıktıları ekrana basma fonksiyonu
    void printDataPreview(String title, http.Response res) {
      print("==================================================");
      print("📌 $title (Durum: ${res.statusCode})");
      print("==================================================");
      
      if (res.statusCode == 200) {
        String body = res.body.trim();
        if (body.isEmpty) {
          print("[ BOŞ YANIT DÖNDÜ ]\n");
          return;
        }
        
        // Çok uzunsa terminali boğmamak için ilk 800 karakteri alıyoruz
        int limit = body.length > 800 ? 800 : body.length;
        print(body.substring(0, limit));
        
        if (body.length > limit) {
          print("\n... [DEVAMI VAR - Toplam Uzunluk: ${body.length} karakter]");
        }
      } else {
        print("HATA: İstek başarısız oldu.");
      }
      print("\n");
    }

    // Gelen ham verileri terminale basalım
    printDataPreview("1. API-FOOTBALL (CANLI SKOR & DAKİKA)", results[0]);
    printDataPreview("2. MACKOLİK: MATCH DATA (KADROLAR VE OLAYLAR)", results[1]);
    printDataPreview("3. MACKOLİK: H2H (GEÇMİŞ MAÇLAR)", results[2]);
    printDataPreview("4. MACKOLİK: STANDINGS (PUAN DURUMU)", results[3]);

  } catch (e) {
    print("❌ Sistem Hatası: $e");
  }
}
