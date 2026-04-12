/**
 * SCOREPOP — Mackolik Haber Çekici
 * GitHub Actions tarafından saatte bir çalıştırılır.
 *
 * Ortam değişkenleri (GitHub Secrets):
 *   SUPABASE_URL          → https://xxxx.supabase.co
 *   SUPABASE_SERVICE_KEY  → sb_... (service_role key — Supabase Dashboard > API)
 */

const https = require('https');
const http  = require('http');

// ── Ayarlar ────────────────────────────────────────────────────────────────
const SUPABASE_URL         = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const MACKOLIK_URL         = 'https://arsiv.mackolik.com/futbol-haberleri';
const MAX_SAYFA            = 3;   // kaç sayfa kontrol edilsin (her sayfada ~20 haber)
const TABLE                = 'haberler';

// Kategori eşlemesi — Mackolik sekme tipinden
const KATEGORI_MAP = {
  '1': 'Süper Lig',
  '2': 'Avrupa',
  '3': 'Milli Takım',
  '4': 'Transfer',
  '5': 'Dünya',
};

// ── Yardımcı: HTTP GET ──────────────────────────────────────────────────────
function get(url) {
  return new Promise((resolve, reject) => {
    const mod = url.startsWith('https') ? https : http;
    const req = mod.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; ScorePop-Bot/1.0)',
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'tr-TR,tr;q=0.9',
      },
      timeout: 15000,
    }, res => {
      // Yönlendirme takibi
      if ([301, 302, 303, 307, 308].includes(res.statusCode) && res.headers.location) {
        return resolve(get(res.headers.location));
      }
      let data = '';
      res.setEncoding('utf8');
      res.on('data', c => data += c);
      res.on('end', () => resolve(data));
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout: ' + url)); });
  });
}

// ── Yardımcı: Supabase REST ────────────────────────────────────────────────
async function supabaseRequest(method, path, body) {
  const url = `${SUPABASE_URL}/rest/v1/${path}`;
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const urlObj  = new URL(url);

    const options = {
      hostname: urlObj.hostname,
      path:     urlObj.pathname + urlObj.search,
      method,
      headers: {
        'apikey':        SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
        'Content-Type':  'application/json',
        'Prefer':        method === 'POST' ? 'return=minimal,resolution=ignore-duplicates' : '',
      },
    };
    if (payload) options.headers['Content-Length'] = Buffer.byteLength(payload);

    const req = https.request(options, res => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        if (res.statusCode >= 400) {
          reject(new Error(`Supabase ${res.statusCode}: ${data}`));
        } else {
          resolve(data ? JSON.parse(data) : null);
        }
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

// ── Yardımcı: Türkçe slug ─────────────────────────────────────────────────
function slugify(text) {
  return text
    .toLowerCase()
    .replace(/ğ/g,'g').replace(/ü/g,'u').replace(/ş/g,'s')
    .replace(/ı/g,'i').replace(/ö/g,'o').replace(/ç/g,'c')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 80);
}

// ── Yardımcı: Tarih parse ─────────────────────────────────────────────────
function parseDate(str) {
  // "12.04.2026 12:48" formatı
  const m = str.trim().match(/(\d{2})\.(\d{2})\.(\d{4})\s+(\d{2}):(\d{2})/);
  if (!m) return new Date().toISOString();
  return new Date(`${m[3]}-${m[2]}-${m[1]}T${m[4]}:${m[5]}:00+03:00`).toISOString();
}

// ── HTML parse: haber listesi ──────────────────────────────────────────────
function parseHaberler(html) {
  const haberler = [];

  // Her news-coll-temp bloğunu yakala
  const blockRe = /<div class="news-coll-temp">([\s\S]*?)<div class="clr"><\/div>\s*<\/div>/g;
  let block;

  while ((block = blockRe.exec(html)) !== null) {
    const content = block[1];

    // Haber linki ve ID
    const linkM = content.match(/href="[^"]*\/Haber\/(\d+)\/([^"?]+)"/);
    if (!linkM) continue;
    const mackolik_id = parseInt(linkM[1], 10);
    const urlSlug     = linkM[2];

    // Kapak görseli
    const imgM = content.match(/src="(\/\/hm\.mackolik\.com\/img\/haberbuyuk\/[^"?]+)/);
    const kapak_url = imgM ? 'https:' + imgM[1] : null;

    // Başlık (img alt veya news-img-transp içi)
    const altM    = content.match(/alt="([^"]+)"/);
    const transpM = content.match(/<div class="news-img-transp">\s*([\s\S]*?)\s*<\/div>/);
    const baslik  = (altM?.[1] || transpM?.[1] || '').trim();
    if (!baslik) continue;

    // Özet
    const ozetM = content.match(/<div class="news-coll-text">([\s\S]*?)<\/div>/);
    const ozet  = ozetM ? ozetM[1].trim() : '';

    // Tarih
    const dateM = content.match(/<div class="news-coll-date">([^<]+)<\/div>/);
    const yayin_tarihi = dateM ? parseDate(dateM[1]) : new Date().toISOString();

    // Kaynak URL
    const kaynak_url = `https://arsiv.mackolik.com/Haber/${mackolik_id}/${urlSlug}`;

    // Slug — mackolik_id ekleyerek benzersiz yap
    const slug = slugify(baslik) + '-' + mackolik_id;

    haberler.push({
      mackolik_id,
      slug,
      baslik,
      ozet,
      icerik: ozet, // Basit başlangıç; detay sayfası ileride eklenebilir
      kapak_url,
      kaynak_url,
      kategori: 'Genel',
      yazar:    'Mackolik',
      yayin_tarihi,
      aktif:    true,
    });
  }

  return haberler;
}

// ── Mevcut mackolik_id'leri Supabase'den çek ──────────────────────────────
async function getMevcutIdler() {
  // Son 500 haberin ID'sini çek (saatte ~20 haber geliyor, 500 yeterli)
  const data = await supabaseRequest(
    'GET',
    `${TABLE}?select=mackolik_id&order=mackolik_id.desc&limit=500`
  );
  const idler = new Set((data || []).map(r => r.mackolik_id).filter(Boolean));
  console.log(`Veritabanında ${idler.size} haber ID'si mevcut.`);
  return idler;
}

// ── NewsHandler AJAX sayfası çek ──────────────────────────────────────────
async function fetchSayfa(page = 0) {
  if (page === 0) {
    return get(MACKOLIK_URL);
  }
  // Sayfa 1+ için AJAX endpoint
  const url = `https://arsiv.mackolik.com/AjaxHandlers/NewsHandler.aspx?command=homeNews&page=${page}`;
  return get(url);
}

// ── Ana işlev ──────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n🕐 ${new Date().toISOString()} — Mackolik haber çekme başladı`);

  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    console.error('❌ SUPABASE_URL veya SUPABASE_SERVICE_KEY eksik!');
    process.exit(1);
  }

  // Mevcut ID'leri al
  const mevcutIdler = await getMevcutIdler();

  let toplamYeni = 0;
  let toplamHaber = 0;

  for (let sayfa = 0; sayfa < MAX_SAYFA; sayfa++) {
    console.log(`\n📄 Sayfa ${sayfa} çekiliyor...`);

    let html;
    try {
      html = await fetchSayfa(sayfa);
    } catch (err) {
      console.error(`  ⚠️  Sayfa ${sayfa} alınamadı:`, err.message);
      break;
    }

    const haberler = parseHaberler(html);
    console.log(`  → ${haberler.length} haber parse edildi`);
    toplamHaber += haberler.length;

    if (haberler.length === 0) {
      console.log('  → Haber bulunamadı, duruyorum.');
      break;
    }

    // Yeni olanları filtrele
    const yeniHaberler = haberler.filter(h => !mevcutIdler.has(h.mackolik_id));
    console.log(`  → ${yeniHaberler.length} yeni haber bulundu`);

    if (yeniHaberler.length === 0) {
      // Bu sayfada yeni haber yok — eski haberler başladı, dur
      console.log('  → Yeni haber yok, daha eski sayfalara bakmıyorum.');
      break;
    }

    // Supabase'e ekle (toplu - resolution=ignore-duplicates ile güvenli)
    try {
      await supabaseRequest('POST', TABLE, yeniHaberler);
      toplamYeni += yeniHaberler.length;
      yeniHaberler.forEach(h => {
        console.log(`  ✅ Eklendi: [${h.mackolik_id}] ${h.baslik.slice(0, 60)}`);
        mevcutIdler.add(h.mackolik_id); // Sonraki sayfa için önbelleği güncelle
      });
    } catch (err) {
      console.error('  ❌ Supabase insert hatası:', err.message);
    }

    // Mackolik'e saygı aralığı
    await new Promise(r => setTimeout(r, 2000));
  }

  console.log(`\n✨ Tamamlandı: ${toplamHaber} haber tarandı, ${toplamYeni} yeni haber eklendi.`);
}

main().catch(err => {
  console.error('💥 Kritik hata:', err);
  process.exit(1);
});
