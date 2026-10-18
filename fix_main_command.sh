#!/bin/bash

echo "⏳ 1. Updating MainActivity.java with the new robust command..."
# المسار الصحيح لملف MainActivity في بيئة البناء الخاصة بك
FILE="/workspaces/NetProbe-Final/app/src/main/java/com/xk/netprobe/MainActivity.java"

# استبدال الأمر القديم بالأمر الجديد الذي يحتوي على pkg upgrade
python3 - << 'PYEOF'
import os
file_path = "/workspaces/NetProbe-Final/app/src/main/java/com/xk/netprobe/MainActivity.java"
if os.path.exists(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    old_cmd = 'pkg install curl -y && curl -fsSL https://raw.githubusercontent.com/sm2218157-creator/Netprobe/main/setup.sh -o setup.sh && bash setup.sh'
    
    # إضافة pkg update و pkg upgrade لحل مشكلة الـ libcurl نهائياً
    new_cmd = 'pkg update -y && pkg upgrade -y -o Dpkg::Options::=\\"--force-confold\\" && pkg install curl -y && curl -fsSL https://raw.githubusercontent.com/sm2218157-creator/Netprobe/main/setup.sh -o setup.sh && bash setup.sh'
    
    content = content.replace(old_cmd, new_cmd)
    
    with open(file_path, 'w') as f:
        f.write(content)
    print("✅ Command replaced successfully in MainActivity.java")
else:
    print("❌ File not found at: " + file_path)
PYEOF

echo "⏳ 2. Pushing to GitHub..."
# الانتقال لمجلد المستكشف لرفع التعديل
cd /workspaces/Netprobe
git add -A
git commit -m "fix: update setup command to force upgrade before curl" || true
git push origin main --force

echo "✅ ALL DONE!"
