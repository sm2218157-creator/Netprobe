#!/usr/bin/env bash
set -u
D="_NETPROBE_DUMP.txt"
B="_NETPROBE_BUILD.log"
L="_NETPROBE_BRIEF.txt"
SEP="=========="

{
echo "$SEP BUILD RESULT $SEP"
grep -E "BUILD (SUCCESSFUL|FAILED)|^Exit code" "$D" | tail -5
echo
echo "--- apk ---"
ls -la app/build/outputs/apk/debug/ 2>/dev/null || echo "no apk dir"

echo
echo "$SEP ERRORS (top 40) $SEP"
grep -E "error:|FAILURE:|What went wrong|Unsupported class file|Could not resolve|Could not find|Execution failed|Caused by|> Task .* FAILED" "$B" 2>/dev/null | head -40

echo
echo "$SEP TREE $SEP"
find . -type f \
  -not -path "*/.git/*" -not -path "*/build/*" \
  -not -path "*/.gradle/*" -not -path "*/.idea/*" \
  -not -name "*.apk" -not -name "*.zip" -not -name "*.jar" \
  -not -name "_*" -not -name "*.bak.*" \
  | sort

echo
echo "$SEP GRADLE FILES $SEP"
for f in settings.gradle settings.gradle.kts build.gradle build.gradle.kts \
         gradle.properties app/build.gradle app/build.gradle.kts \
         gradle/libs.versions.toml; do
  [ -f "$f" ] && { echo "--- $f ---"; cat "$f"; echo; }
done

echo
echo "$SEP MANIFEST $SEP"
for f in $(find . -name AndroidManifest.xml -not -path "*/build/*"); do
  echo "--- $f ---"; cat "$f"; echo
done

echo
echo "$SEP SOURCE FILES $SEP"
find app/src -type f \( -name "*.java" -o -name "*.kt" \) -printf "%s\t%p\n" 2>/dev/null | sort -k2

echo
echo "$SEP SOURCE CONTENTS $SEP"
find app/src -type f \( -name "*.java" -o -name "*.kt" \) 2>/dev/null | sort | while read -r f; do
  sz=$(wc -c < "$f")
  echo "--- $f (${sz}B) ---"
  if [ "$sz" -gt 8000 ]; then
    head -c 4000 "$f"
    echo
    echo "...[truncated $((sz-4000))B]..."
  else
    cat "$f"
  fi
  echo
done

echo
echo "$SEP LAYOUT/RES KEUXML $SEP"
find app/src/main/res -type f -name "*.xml" 2>/dev/null | sort | while read -r f; do
  case "$f" in
    */values/*|*/layout/*|*/xml/*|*/menu/*)
      sz=$(wc -c < "$f")
      echo "--- $f (${sz}B) ---"
      [ "$sz" -gt 4000 ] && { head -c 3000 "$f"; echo; echo "...[trunc]..."; } || cat "$f"
      echo ;;
  esac
done

echo
echo "$SEP SIZE $SEP"
wc -l "$L" 2>/dev/null; du -h "$L" 2>/dev/null
} > "$L" 2>&1

echo "written: $L"
wc -l "$L"
du -h "$L"
