# NetProbe (Java Edition)

أداة أمن شبكات أندرويد (Nmap + Termux Bridge).
هذا المستودع يحتوي على الكود المصدري الكامل بلغة Java.

## المكونات
- `app/src/main/java/com/xk/netprobe/`: أكواد الجافا (MainActivity, LocalNetworkActivity, TermuxBridge, إلخ).
- `setup.sh`: السكربت الذي يتم تنفيذه في Termux لتجهيز الأدوات.
- `app/src/main/res/layout/`: واجهات المستخدم.

## كيف يعمل؟
1. المستخدم يضغط على "Setup" لنسخ أمر جلب `setup.sh` وتنفيذه في Termux.
2. بعد التجهيز، يقرأ التطبيق حالة الجاهزية.
3. عند فحص الشبكة، يستخدم التطبيق (Ping) لاكتشاف الأجهزة، ثم (Nmap) لفحص المنافذ.
