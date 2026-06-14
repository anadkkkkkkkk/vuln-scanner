#!/bin/bash
# Orchestrator - يشغل جميع السكربتات التجريبية

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

if command -v /data/data/com.termux/files/usr/bin/python3 &>/dev/null; then
    PYTHON="/data/data/com.termux/files/usr/bin/python3"
else
    PYTHON="python3"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  إطار الاختبار التجريبي لمنصات Meta  ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}استخدام بايثون: $PYTHON${NC}"

RESULTS_DIR="results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"
LOG="$RESULTS_DIR/execution.log"
SUMMARY="$RESULTS_DIR/summary.txt"

echo "[+] بدء التشغيل: $(date)" | tee -a "$LOG"

SCRIPTS=(
    "meta_full_pentest.sh"
    "meta_pentest_framework.sh"
    "bypass_techniques.sh"
    "meta_bug_hunting.sh"
    "whatsapp_mitm_proxy.py"
    "whatsapp_protocol_analysis.py"
    "oauth_bypass.py"
    "facebook_graphql_exploits.py"
    "instagram_exploit.py"
    "instagram_api_exploit.py"
    "meta_web_exploits.py"
    "advanced_data_extraction.py"
    "final_report.py"
)

run_script() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}[-] مفقود: $file${NC}"
        echo "MISSING: $file" >> "$SUMMARY"
        return 1
    fi
    echo -e "${YELLOW}[*] تشغيل $file ...${NC}"
    echo "--- START $file ---" >> "$LOG"
    if [[ "$file" == *.sh ]]; then
        bash "$file" >> "$LOG" 2>&1
    elif [[ "$file" == *.py ]]; then
        $PYTHON "$file" >> "$LOG" 2>&1
    fi
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}[✓] نجاح: $file${NC}"
        echo "PASS: $file" >> "$SUMMARY"
    else
        echo -e "${RED}[✗] فشل: $file${NC}"
        echo "FAIL: $file" >> "$SUMMARY"
    fi
    echo "--- END $file ---" >> "$LOG"
}

for scr in "${SCRIPTS[@]}"; do
    run_script "$scr"
done

echo "" | tee -a "$SUMMARY"
echo "========================================" | tee -a "$SUMMARY"
echo "  الملخص النهائي" | tee -a "$SUMMARY"
echo "========================================" | tee -a "$SUMMARY"
cat "$SUMMARY"
echo -e "${GREEN}[+] انتهى. النتائج في: $RESULTS_DIR/${NC}"
