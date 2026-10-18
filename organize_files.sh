#!/bin/bash

echo "⏳ نسخ الـ APK إلى القائمة الرئيسية..."
cp app/build/outputs/apk/debug/app-debug.apk NetProbe-v19.5.apk

echo "⏳ إنشاء ملف الـ ZIP..."
rm -f NetProbe-v19.5.zip
zip -r NetProbe-v19.5.zip . -x "*.git/*" "build/*" "app/build/*" ".gradle/*" "app/.gradle/*" "*.zip" "*.apk" "local.properties" "*.log" > /dev/null

echo "✅ تم! ستجد الملفات الآن في المستكشف على اليسار."
