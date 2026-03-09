import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

// ─── TEST EDİLECEK PROXY LİSTESİ ────────────────────────────────
// Format: 'ip:port:username:password'
final List<String> _proxies = [
  // Örnek:
  // '103.149.162.195:8080:user123:pass456',
  // '51.158.68.68:8811:myuser:mypass',
  //'31.59.20.176:6754:zgikyxni:85yrd6rhvn2y',
//'23.95.150.145:6114:zgikyxni:85yrd6rhvn2y',
//'198.23.239.134:6540:zgikyxni:85yrd6rhvn2y',
//'45.38.107.97:6014:zgikyxni:85yrd6rhvn2y',
//'107.172.163.27:6543:zgikyxni:85yrd6rhvn2y',
//'198.105.121.200:6462:zgikyxni:85yrd6rhvn2y',
//'64.137.96.74:6641:zgikyxni:85yrd6rhvn2y',
//'216.10.27.159:6837:zgikyxni:85yrd6rhvn2y',
//'142.111.67.146:5611:zgikyxni:85yrd6rhvn2y',
//'194.39.32.164:6461:zgikyxni:85yrd6rhvn2y',
///'94.176.3.43:7443',

 '123.54.197.21:23190',
'47.250.11.111:51',
'206.123.156.181:6472',
];

const _testUrl = 'https://vd.mackolik.com/livedata?date=09/03/2026';
const _timeout = Duration(seconds: 12);

final _headers = {
  'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  'Accept': 'application/json, text/javascript, */*; q=0.01',
  'Accept-Language': 'tr-TR,tr;q=0.9',
  'Referer': 'https://arsiv.mackolik.com/',
};

Future<void> main() async {
  print('🔍 Mackolik Proxy Test Aracı (Auth Destekli)');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('🎯 Hedef: $_testUrl\n');

  // Önce direkt test
  print('📡 Direkt bağlantı test ediliyor...');
  await _testDirect();
  print('');

  if (_proxies.isEmpty) {
    print('⚠️  _proxies listesi boş, proxy ekle ve tekrar çalıştır.');
    return;
  }

  final results = <Map<String, dynamic>>[];

  for (final proxy in _proxies) {
    final result = await _testProxy(proxy);
    results.add(result);
    final emoji = result['success'] == true ? '✅' : '❌';
    print('$emoji ${result['proxy_display']} — ${result['ms'] ?? '-'}ms — ${result['detail']}');
  }

  print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  final working = results.where((r) => r['success'] == true).toList();
  print('📊 Sonuç: ${working.length}/${results.length} proxy çalışıyor');

  if (working.isNotEmpty) {
    print('\n✅ ÇALIŞAN PROXY\'LER (worker\'a eklenebilir):');
    for (final r in working) {
      print("   '${r['raw']}', // ${r['ms']}ms");
    }
  }
}

Future<void> _testDirect() async {
  try {
    final sw = Stopwatch()..start();
    final res = await http.get(Uri.parse(_testUrl), headers: _headers).timeout(_timeout);
    sw.stop();
    final body = res.body.trim();
    final isBot = body.startsWith('<!DOCTYPE') || body.startsWith('<html');
    if (res.statusCode == 200 && !isBot) {
      final data = jsonDecode(body);
      final count = (data['m'] as List?)?.length ?? 0;
      print('✅ Direkt: HTTP 200 | ${sw.elapsedMilliseconds}ms | $count maç');
    } else if (isBot) {
      print('🚫 Direkt: BOT ENGEL — IP bloklu, proxy gerekli');
    } else {
      print('❌ Direkt: HTTP ${res.statusCode}');
    }
  } catch (e) {
    print('❌ Direkt hata: $e');
  }
}

Future<Map<String, dynamic>> _testProxy(String proxyStr) async {
  final parts = proxyStr.split(':');
  if (parts.length < 2) {
    return {'raw': proxyStr, 'proxy_display': proxyStr, 'success': false, 'detail': 'Geçersiz format'};
  }

  final host = parts[0];
  final port = int.tryParse(parts[1]);
  final username = parts.length >= 3 ? parts[2] : null;
  // şifrede ':' karakteri olabilir, geri kalanını birleştir
  final password = parts.length >= 4 ? parts.sublist(3).join(':') : null;
  final display = '$host:$port (${username ?? 'no-auth'})';

  if (port == null) {
    return {'raw': proxyStr, 'proxy_display': display, 'success': false, 'detail': 'Geçersiz port'};
  }

  try {
    final sw = Stopwatch()..start();

    final client = HttpClient();
    client.connectionTimeout = _timeout;
    client.findProxy = (uri) => 'PROXY $host:$port';

    if (username != null && password != null) {
      client.addProxyCredentials(
        host,
        port,
        'Basic',
        HttpClientBasicCredentials(username, password),
      );
    }

    final request = await client.getUrl(Uri.parse(_testUrl));
    _headers.forEach((k, v) => request.headers.set(k, v));

    final response = await request.close().timeout(_timeout);
    sw.stop();

    final body = await response.transform(utf8.decoder).join();
    client.close();

    final trimmed = body.trim();
    final isBot = trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html');

    if (response.statusCode == 200 && !isBot) {
      try {
        final data = jsonDecode(body);
        final count = (data['m'] as List?)?.length ?? 0;
        return {
          'raw': proxyStr,
          'proxy_display': display,
          'success': true,
          'ms': sw.elapsedMilliseconds,
          'detail': '$count maç bulundu 🎉',
        };
      } catch (_) {
        return {
          'raw': proxyStr,
          'proxy_display': display,
          'success': false,
          'ms': sw.elapsedMilliseconds,
          'detail': 'JSON parse hatası',
        };
      }
    } else if (isBot) {
      return {
        'raw': proxyStr,
        'proxy_display': display,
        'success': false,
        'ms': sw.elapsedMilliseconds,
        'detail': 'Bot engeli (proxy de bloklu)',
      };
    } else if (response.statusCode == 407) {
      return {
        'raw': proxyStr,
        'proxy_display': display,
        'success': false,
        'ms': sw.elapsedMilliseconds,
        'detail': 'HTTP 407 — Proxy auth başarısız, user/pass kontrol et',
      };
    } else {
      return {
        'raw': proxyStr,
        'proxy_display': display,
        'success': false,
        'ms': sw.elapsedMilliseconds,
        'detail': 'HTTP ${response.statusCode}',
      };
    }
  } on TimeoutException {
    return {'raw': proxyStr, 'proxy_display': display, 'success': false, 'detail': 'Timeout'};
  } catch (e) {
    final msg = e.toString();
    return {
      'raw': proxyStr,
      'proxy_display': display,
      'success': false,
      'detail': msg.substring(0, msg.length.clamp(0, 80)),
    };
  }
}
