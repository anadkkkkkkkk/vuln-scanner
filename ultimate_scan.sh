#!/bin/bash
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
read -p "الهدف: " T
echo -e "${GREEN}فحص $T ...${NC}"
mkdir -p final_scan_${T}_$(date +%Y%m%d_%H%M%S)
# اختبارات سريعة...
curl -sI "http://$T" | grep -qi "X-Frame-Options" || echo "[!] Clickjacking محتمل"
curl -s "http://$T" | grep -qi "csrf_token" || echo "[!] CSRF محتمل"
echo "انتهى."
