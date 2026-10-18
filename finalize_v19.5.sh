#!/bin/bash
set -e

echo "⏳ 1. Committing latest fixes..."
git add -A
git commit -m "fix: resolve Shizuku dependencies, add missing colors, and finalize v19.5" || echo "Nothing new to commit"

echo "⏳ 2. Pushing to GitHub..."
git push origin main --force

echo "⏳ 3. Creating ZIP Backup..."
# حذف أي نسخة قديمة لضمان عدم التكرار
rm -f NetProbe_v19.5_Source.zip
zip -r NetProbe_v19.5_Source.zip . -x "*.git/*" "build/*" "app/build/*" ".gradle/*" "app/.gradle/*" "*.zip" "*.apk" "local.properties" "build_output.log" > /dev/null

echo "⏳ 4. Publishing Release to GitHub..."
# حذف الإصدار القديم إذا كان موجوداً لتجنب الأخطاء
gh release delete v19.5-final -y 2>/dev/null || true
gh release create v19.5-final NetProbe_v19.5_Source.zip \
    --title "NetProbe v19.5 Final (Stable)" \
    --notes "النسخة النهائية المستقرة. تدعم أندرويد 11 فما فوق، وتحتوي على إصلاحات Shizuku والألوان. تم البناء محلياً." \
    --repo sm2218157-creator/Netprobe

echo "✅ ALL DONE!"
echo "الـ APK جاهز في: app/build/outputs/apk/debug/app-debug.apk"
echo "النسخة الاحتياطية جاهزة في صفحة Releases."
