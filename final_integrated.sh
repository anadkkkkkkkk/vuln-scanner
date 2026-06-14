#!/bin/bash
# ======================================================
# التشغيل المتكامل لمشروعك + فحص 9 ثغرات
# ======================================================

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   التشغيل الكامل للمشروع + فحص 9 ثغرات${NC}"
echo -e "${BLUE}════════════════════════════════════════════════${NC}"

read -p "أدخل الهدف (مثل: testphp.vulnweb.com): " TARGET
DATE=$(date +%Y%m%d_%H%M%S)
OUT="full_scan_${TARGET}_${DATE}"
mkdir -p "$OUT"
LOG="$OUT/00_summary.txt"

echo "[+] بدء المسح على $TARGET" | tee "$LOG"

# ================= 1. تشغيل مشروعك الأصلي =================
echo -e "\n${YELLOW}[1] تشغيل سكربتات مشروعك:${NC}" | tee -a "$LOG"
for f in *.sh *.py; do
    [ -f "$f" ] && [ "$f" != "final_integrated.sh" ] && {
        echo "  -> تنفيذ $f" >> "$LOG"
        (bash "$f" 2>&1 | head -50) > "$OUT/${f}.log" 2>&1
    }
done

# ================= 2. فحص الثغرات التسع =================
echo -e "\n${YELLOW}[2] فحص الثغرات التسع:${NC}" | tee -a "$LOG"
VULN="$OUT/vulns.txt"
echo "----- XSS -----" > "$VULN"
curl -s "http://$TARGET/?q=<script>alert(1)</script>" | grep -q "alert" && echo "[!] محتمل" || echo "[+] غير واضح" >> "$VULN"
echo "----- IDOR -----" >> "$VULN"
curl -s "http://$TARGET" | grep -oE '(id|user|profile)=[0-9]+' | head -2 >> "$VULN"
echo "----- SSRF -----" >> "$VULN"
curl -s -o /dev/null -w "%{http_code}" "http://$TARGET/fetch?url=127.0.0.1" | grep -q 200 && echo "[!] محتمل" >> "$VULN"
echo "----- GraphQL -----" >> "$VULN"
curl -s -X POST -H "Content-Type: app/json" -d '{"query":"{__schema{types{name}}}"}' "http://$TARGET/graphql" | grep -q __schema && echo "[!] Introspection مكشوف" >> "$VULN"
echo "----- OAuth Redirect -----" >> "$VULN"
curl -sI "http://$TARGET/oauth/callback?redirect_uri=https://evil.com" | grep -q "evil.com" && echo "[!] Open Redirect" >> "$VULN"
echo "----- DOM Clobbering -----" >> "$VULN"
echo "يتطلب فحص يدوي" >> "$VULN"
echo "----- Clickjacking -----" >> "$VULN"
curl -sI "http://$TARGET" | grep -qi "X-Frame-Options" || echo "[!] قد يكون عرضة" >> "$VULN"
echo "----- SQLi -----" >> "$VULN"
curl -s "http://$TARGET/?id=1' OR '1'='1" | grep -qi "sql" && echo "[!] محتمل" || echo "[+] غير واضح" >> "$VULN"
echo "----- CSRF -----" >> "$VULN"
curl -s "http://$TARGET" | grep -qi "csrf_token" || echo "[!] قد يكون عرضة" >> "$VULN"

# ================= 3. تقرير HTML =================
HTML="$OUT/final_report.html"
cat > "$HTML" << EOF
<html><head><meta charset="UTF-8"><title>تقرير $TARGET</title>
<style>body{font-family:sans-serif;padding:20px} pre{background:#eee}</style>
</head><body>
<h1>التقرير النهائي - $TARGET</h1>
<p>التاريخ: $(date)</p>
<h2>ملخص الفحوصات</h2>
<pre>$(cat "$VULN")</pre>
<h2>مخرجات مشروعك</h2>
<pre>$(cat "$LOG")</pre>
<hr><p style="color:gray">تم بواسطة مشروعك + فحص الثغرات (تجريبي تعليمي)</p>
</body></html>
EOF

echo -e "\n${GREEN}✅ اكتمل العمل!${NC}"
echo "📂 النتائج في: $OUT"
echo "🌐 التقرير: $OUT/final_report.html"
echo "يمكنك فتحه بالمتصفح (مثال: firefox $OUT/final_report.html)"
