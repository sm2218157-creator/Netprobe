#!/usr/bin/env bash
# ============================================================
# NetProbe — unified dump script
# Output: ./_NETPROBE_DUMP.txt
# ============================================================
set -u

GRADLE_TARGET="8.10.2"
JDK17_PATHS=(
  "/usr/lib/jvm/java-17-openjdk-amd64"
  "/usr/lib/jvm/java-17-openjdk"
  "/usr/lib/jvm/temurin-17-jdk-amd64"
  "/usr/lib/jvm/msopenjdk-17"
  "/opt/java/17"
  "/opt/java/openjdk-17"
)
REPORT="_NETPROBE_DUMP.txt"
BUILD_LOG="_NETPROBE_BUILD.log"
SEP="============================================================"
SUB="------------------------------------------------------------"

find_root() {
  local d="$PWD"
  for _ in $(seq 1 8); do
    if [ -f "$d/settings.gradle" ] || [ -f "$d/settings.gradle.kts" ] \
       || [ -f "$d/build.gradle" ] || [ -f "$d/build.gradle.kts" ]; then
      echo "$d"; return
    fi
    d="$(dirname "$d")"
  done
  echo "$PWD"
}
ROOT="$(find_root)"
cd "$ROOT" || exit 1

hdr() { echo; echo "$SEP"; echo "## $*"; echo "$SEP"; }
sec() { echo; echo "### $*"; echo "$SUB"; }
run() { echo "\$ $*"; "$@" 2>&1 || true; }

pick_java() {
  for p in "${JDK17_PATHS[@]}"; do
    if [ -x "$p/bin/java" ]; then echo "$p"; return; fi
  done
  for p in /usr/lib/jvm/*21* /opt/java/*21* /usr/lib/jvm/*-21-*; do
    [ -x "$p/bin/java" ] && { echo "$p"; return; }
  done
  echo "${JAVA_HOME:-}"
}

{
echo "$SEP"
echo "NetProbe — DUMP"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "Host: $(hostname 2>/dev/null)"
echo "Root: $ROOT"
echo "$SEP"
} | tee "$REPORT" >/dev/null

exec 3>&1

{
hdr "1. ENVIRONMENT"
sec "OS / arch"
run uname -a
[ -f /etc/os-release ] && run cat /etc/os-release
sec "JAVA_HOME (before)"
echo "JAVA_HOME=${JAVA_HOME:-<unset>}"
echo "PATH contains java: $(command -v java || echo none)"
sec "java -version"
run java -version
sec "Available JDKs"
run ls -la /usr/lib/jvm
run update-alternatives --list java
sec "Gradle wrapper properties"
[ -f gradle/wrapper/gradle-wrapper.properties ] \
  && run cat gradle/wrapper/gradle-wrapper.properties \
  || echo "MISSING: gradle/wrapper/gradle-wrapper.properties"
sec "gradlew present?"
run ls -la gradlew gradlew.bat
sec "git state"
run git branch --show-current
run git log --oneline -20
run git status --short
run git remote -v
} 2>&1 | tee -a "$REPORT" >&3

{
hdr "2. FIX APPLIED"
JAVA_CHOSEN="$(pick_java)"
sec "Chosen JAVA_HOME"
echo "$JAVA_CHOSEN"
if [ -n "$JAVA_CHOSEN" ] && [ -x "$JAVA_CHOSEN/bin/java" ]; then
  export JAVA_HOME="$JAVA_CHOSEN"
  export PATH="$JAVA_HOME/bin:$PATH"
  sec "java -version (after fix)"
  run "$JAVA_HOME/bin/java" -version
else
  sec "No compatible JDK found in known paths"
fi
sec "Upgrade Gradle wrapper -> $GRADLE_TARGET"
WP="gradle/wrapper/gradle-wrapper.properties"
if [ -f "$WP" ]; then
  cp "$WP" "${WP}.bak.$(date +%s)"
  if grep -q '^distributionUrl=' "$WP"; then
    sed -i -E "s|^distributionUrl=.*|distributionUrl=https\\\\://services.gradle.org/distributions/gradle-${GRADLE_TARGET}-bin.zip|" "$WP"
  else
    echo "distributionUrl=https\\://services.gradle.org/distributions/gradle-${GRADLE_TARGET}-bin.zip" >> "$WP"
  fi
  run cat "$WP"
fi
sec "gradle.properties"
GP="gradle.properties"
[ -f "$GP" ] || : > "$GP"
cp "$GP" "${GP}.bak.$(date +%s)" 2>/dev/null || true
ensure_prop() {
  local key="$1" val="$2" file="$3"
  if grep -q "^${key}=" "$file"; then
    sed -i -E "s|^${key}=.*|${key}=${val//|/\\|}|" "$file"
  else
    echo "${key}=${val}" >> "$file"
  fi
}
ensure_prop "org.gradle.jvmargs" "-Xmx3g -Dfile.encoding=UTF-8 -XX:+UseParallelGC" "$GP"
ensure_prop "org.gradle.parallel" "true" "$GP"
ensure_prop "org.gradle.caching" "true" "$GP"
ensure_prop "android.useAndroidX" "true" "$GP"
ensure_prop "android.enableJetifier" "true" "$GP"
[ -n "${JAVA_HOME:-}" ] && ensure_prop "org.gradle.java.home" "$JAVA_HOME" "$GP"
run cat "$GP"
} 2>&1 | tee -a "$REPORT" >&3

{
hdr "3. CLEAN"
./gradlew --stop 2>&1 || true
run rm -rf .gradle build app/build
run rm -rf "$HOME/.gradle/caches/8.2" "$HOME/.gradle/caches/8.0" "$HOME/.gradle/caches/8.1"
run rm -rf "$HOME/.gradle/caches/transforms-3" "$HOME/.gradle/caches/transforms-4"
run rm -rf "$HOME/.gradle/daemon"
echo "done"
} 2>&1 | tee -a "$REPORT" >&3

{
hdr "4. BUILD (assembleDebug --stacktrace)"
./gradlew assembleDebug --stacktrace --info > "$BUILD_LOG" 2>&1
BUILD_RC=$?
sec "Exit code"
echo "$BUILD_RC"
sec "Build result"
grep -E "BUILD (SUCCESSFUL|FAILED)" "$BUILD_LOG" | tail -3
sec "APK outputs"
run ls -la app/build/outputs/apk/debug/
run ls -la app/build/outputs/apk/
sec "Tail 150 lines of build log"
tail -n 150 "$BUILD_LOG"
sec "Critical error grep"
grep -E "error:|FAILURE:|What went wrong|Unsupported class file|Could not resolve|Could not find|Execution failed|Caused by" "$BUILD_LOG" | head -80
} 2>&1 | tee -a "$REPORT" >&3

{
hdr "5. PROJECT STRUCTURE"
sec "Source tree"
find . -type f \
  -not -path "*/.git/*" -not -path "*/build/*" \
  -not -path "*/.gradle/*" -not -path "*/.idea/*" \
  -not -name "*.apk" -not -name "*.zip" -not -name "*.jar" \
  -not -name "_NETPROBE_DUMP.txt" -not -name "_NETPROBE_BUILD.log" \
  -not -name "_ALPHA_REPORT.txt" -not -name "_ALPHA_CONSOLE.txt" \
  -not -name "_build_full.txt" -not -name "_gitlog.txt" \
  -not -name "_gitstatus.txt" -not -name "_tree.txt" \
  | sort
sec "Gradle configuration files"
for f in settings.gradle settings.gradle.kts build.gradle build.gradle.kts gradle.properties app/build.gradle app/build.gradle.kts app/proguard-rules.pro gradle/libs.versions.toml; do
  if [ -f "$f" ]; then
    echo; echo "----- FILE: $f -----"; cat "$f"; echo "----- END: $f -----"
  fi
done
sec "AndroidManifest.xml"
for f in $(find . -name AndroidManifest.xml -not -path "*/build/*"); do
  echo "----- FILE: $f -----"; cat "$f"; echo "----- END: $f -----"
done
sec "Source files list"
find app/src -type f \( -name "*.java" -o -name "*.kt" -o -name "*.xml" \) 2>/dev/null | sort
} 2>&1 | tee -a "$REPORT" >/dev/null

{
hdr "6. SOURCE CONTENTS"
while IFS= read -r f; do
  [ -z "$f" ] && continue
  sz=$(wc -c < "$f" 2>/dev/null || echo 0)
  [ "$sz" -gt 200000 ] && { echo "----- SKIP (too large, ${sz}B): $f -----"; continue; }
  echo; echo "----- FILE: $f -----"; cat "$f"; echo "----- END: $f -----"
done < <(find app/src -type f \( -name "*.java" -o -name "*.kt" \) 2>/dev/null | sort)
} 2>&1 | tee -a "$REPORT" >/dev/null

{
hdr "7. KEY RESOURCES"
for f in $(find app/src/main/res -type f -name "*.xml" 2>/dev/null | sort); do
  case "$f" in
    *values/strings.xml|*values/colors.xml|*values/themes.xml|*values/styles.xml|*xml/*.xml|*menu/*.xml|*layout/*.xml)
      echo; echo "----- FILE: $f -----"; cat "$f"; echo "----- END: $f -----" ;;
  esac
done
} 2>&1 | tee -a "$REPORT" >/dev/null

{
hdr "8. SUMMARY"
echo "Report file : $REPORT"
echo "Build log   : $BUILD_LOG"
echo "Lines       : $(wc -l < "$REPORT")"
echo "Size        : $(du -h "$REPORT" | cut -f1)"
echo
echo "NEXT STEP: paste contents of $REPORT"
echo "$SEP"
} 2>&1 | tee -a "$REPORT" >/dev/null

echo
echo "DONE. Report written to: $ROOT/$REPORT"
echo "Now run:  cat $REPORT"
