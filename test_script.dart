import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // --- AYARLAR ---
  // API-Football key'inizi buraya girin veya GitHub Secrets'tan alacak şekilde ayarlayın
  String apiFootballKey = "a0ba44abc06475107be5327c1ba2ae56"; 
  
  // Tarihler (Bugünün tarihi: 5 Mart 2026)
  String apiFootballDate = "2026-03-05"; 
  String mackolikDate = "05/03/2026";

  print("ScorePop Eşleştirme Motoru Çalışıyor...\n");

  try {
    // 1. API-FOOTBALL VERİSİNİ ÇEK
    print("1. API-Football verileri çekiliyor...");
    var apiResponse = await http.get(
      Uri.parse('https://v3.football.api-sports.io/fixtures?date=$apiFootballDate'),
      headers: {'x-apisports-key': apiFootballKey},
    );
    
    if (apiResponse.statusCode != 200) {
      print("API-Football hatası: ${apiResponse.statusCode}");
      return;
    }
    var apiJson = json.decode(apiResponse.body);
    List dynamicApiMatches = apiJson['response'] ?? [];


    // 2. MACKOLİK VERİSİNİ ÇEK
    print("2. Maçkolik verileri çekiliyor...");
    var macResponse = await http.get(
      Uri.parse('https://vd.mackolik.com/livedata?date=$mackolikDate'),
      // Maçkolik'in engellememesi için tarayıcı gibi davranıyoruz
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json, text/javascript, */*; q=0.01'
      }
    );

    if (macResponse.statusCode != 200) {
      print("Maçkolik hatası: ${macResponse.statusCode}");
      return;
    }
    
    var macJson = json.decode(macResponse.body);
    // Maçkolik genelde JSON içinde 'm' (matches) adlı bir dizi döner.
    List dynamicMacMatches = macJson['m'] ?? []; 


    // 3. EŞLEŞTİRME DÖNGÜSÜ
    print("3. Eşleştirme algoritması başlatıldı...\n");
    bool matchFound = false;

    for (var apiMatch in dynamicApiMatches) {
      int apiId = apiMatch['fixture']['id'];
      String apiHome = normalizeTeamName(apiMatch['teams']['home']['name']);
      String apiAway = normalizeTeamName(apiMatch['teams']['away']['name']);

      for (var macMatch in dynamicMacMatches) {
        // Maçkolik veri yapısı: [MacId, EvId, "Ev Adı", DepId, "Dep Adı", ...]
        // Eğer dizi yeterince uzun değilse bu satırı atla
        if (macMatch is! List || macMatch.length < 5) continue; 

        int macId = macMatch[0]; // İlk eleman maç ID'si
        String macHome = normalizeTeamName(macMatch[2].toString());
        String macAway = normalizeTeamName(macMatch[4].toString());

        bool isHomeMatch = macHome.contains(apiHome) || apiHome.contains(macHome);
        bool isAwayMatch = macAway.contains(apiAway) || apiAway.contains(macAway);

        if (isHomeMatch && isAwayMatch) {
          print("✅ İLK EŞLEŞME BAŞARIYLA BULUNDU!");
          print("API-Football -> ID: $apiId | ${apiMatch['teams']['home']['name']} vs ${apiMatch['teams']['away']['name']}");
          print("Maçkolik      -> ID: $macId | ${macMatch[2]} vs ${macMatch[4]}");
          
          matchFound = true;
          break; // İlk eşleşmeyi bulduğumuz için Maçkolik döngüsünden çık
        }
      }
      
      if (matchFound) break; // İlk eşleşmeyi bulduğumuz için ana döngüden de çık
    }

    if (!matchFound) {
      print("❌ Bugünün maçları arasında eşleşme bulunamadı. (Normalizasyon fonksiyonu geliştirilebilir)");
    }

  } catch (e) {
    print("Bir hata oluştu: $e");
  }
}

// --- İSİM TEMİZLEME FONKSİYONU ---
String normalizeTeamName(String name) {
  String cleaned = name.toLowerCase();

  const Map<String, String> turkishChars = {
    'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u'
  };
  turkishChars.forEach((key, value) {
    cleaned = cleaned.replaceAll(key, value);
  });

  List<String> stopWords = [
    ' a.s.', ' a.ş.', ' a.s', ' jk', ' fc', ' sk', ' spor', 
    ' kulubu', ' futbol', ' fk', ' united', ' rovers', ' city'
  ];
  
  for (var word in stopWords) {
    cleaned = cleaned.replaceAll(word, '');
  }

  cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9]'), '');
  return cleaned;
}
