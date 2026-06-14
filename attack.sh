#!/bin/bash
# السكربت الرئيسي - يشغل كل الأدوات على نطاق واحد

# طلب اسم النطاق من المستخدم
read -p "[+] أدخل النطاق المستهدف (مثال: testphp.vulnweb.com): " TARGET

# التحقق من أن المستخدم أدخل شيئاً
if [ -z "$TARGET" ]; then
    echo "[-] لم تقم بإدخال أي نطاق. سيتم استخدام localhost للتجربة."
    TARGET="localhost"
fi

echo "-------------------------------------"
echo "[+] بدء الاختبار الآلي على: $TARGET"
echo "-------------------------------------"

# إنشاء مجلد للنتائج
DATE=$(date +%Y%m%d_%H%M%S)
RESULTS_DIR="results_${TARGET}_${DATE}"
mkdir -p "$RESULTS_DIR"
LOG_FILE="$RESULTS_DIR/log.txt"

# تشغيل الملفات الموجودة في مشروعك (إذا كانت موجودة)
echo "[1] تشغيل meta_full_pentest.sh ..." | tee -a "$LOG_FILE"
if [ -f "meta_full_pentest.sh" ]; then
    # تعديل مؤقت داخل الملف نفسه لجعله يقبل المتغير TARGET
    sed -i "s/facebook.com/$TARGET/g" meta_full_pentest.sh
    bash meta_full_pentest.sh >> "$RESULTS_DIR/meta_full_pentest.txt" 2>&1
    # نعيد الملف كما كان (احتياطي)
    sed -i "s/$TARGET/facebook.com/g" meta_full_pentest.sh
else
    echo "[-] meta_full_pentest.sh غير موجود" | tee -a "$LOG_FILE"
fi

echo "[2] تشغيل meta_pentest_framework.sh ..." | tee -a "$LOG_FILE"
if [ -f "meta_pentest_framework.sh" ]; then
    bash meta_pentest_framework.sh >> "$RESULTS_DIR/meta_framework.txt" 2>&1
else
    echo "[-] meta_pentest_framework.sh غير موجود" | tee -a "$LOG_FILE"
fi

echo "[3] تشغيل bypass_techniques.sh ..." | tee -a "$LOG_FILE"
if [ -f "bypass_techniques.sh" ]; then
    bash bypass_techniques.sh >> "$RESULTS_DIR/bypass.txt" 2>&1
else
    echo "[-] bypass_techniques.sh غير موجود" | tee -a "$LOG_FILE"
fi

echo "[4] تشغيل سكربتات البايثون ..." | tee -a "$LOG_FILE"
for py_script in *.py; do
    if [ -f "$py_script" ] && [ "$py_script" != "attack.sh" ]; then
        echo "    تشغيل $py_script ..." >> "$LOG_FILE"
        python3 "$py_script" >> "$RESULTS_DIR/${py_script}.txt" 2>&1
    fi
done

echo "[5] فحص XSS سريع باستخدام طريقة بسيطة ..." | tee -a "$LOG_FILE"
# جمع بعض الروابط من النطاق (إن وجدت)
if command -v curl &> /dev/null; then
    curl -s "https://$TARGET" | grep -oP '(?<=href=")[^"]*' | grep "=" > "$RESULTS_DIR/links.txt"
    while read -r link; do
        test_link="http://$TARGET$link<script>alert(1)</script>"
        status=$(curl -s -o /dev/null -w "%{http_code}" "$test_link")
        echo "اختبار: $test_link -> $status" >> "$RESULTS_DIR/xss_test.txt"
    done < "$RESULTS_DIR/links.txt"
fi

echo "-------------------------------------"
echo "[✔] اكتمل الاختبار!"
echo "[+] النتائج محفوظة في المجلد: $RESULTS_DIR"
echo "-------------------------------------"
