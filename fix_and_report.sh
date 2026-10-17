#!/usr/bin/env bash
# ============================================================
# NetProbe — unified diagnose / fix / build / report script
# Output: ./_ALPHA_REPORT.txt
# ============================================================
set -u

# ---------- config ----------
GRADLE_TARGET="8.10.2"
JDK17_PATHS=(
  "/usr/lib/jvm/java-17-openjdk-amd64"
  "/usr/lib/jvm/java-17-openjdk"
  "/usr/lib/jvm/temurin-17-jdk-amd64"
  "/usr/lib/jvm/msopenjdk-17"
  "/opt/java/17"
  "/opt/java/openjdk-17"
)
REPORT="_ALPHA_REPORT.txt"
BUILD_LOG="_build_full.txt"
SEP="============================================================"
SUB="------------------------------------------------------------"

# ---------- locate project root ----------
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

# ---------- helpers ----------
hdr() {
  echo
  echo "$SEP"
  echo "## $*"
  echo "$SEP"
}
sec() { echo; echo "### $*"; echo "$SUB"; }
run() { echo "\$ $*"; "$@" 2>&1 || true; }

pick_java() {
  # prefer JDK 17, else 21, else current
  for p in "${JDK17_PATHS[@]}"; do
    if [ -x "$p/bin/java" ]; then echo "$p"; return; fi
  done
  for p in /usr/lib/jvm/*21* /opt/java/*21* /usr/lib/jvm/*-21-*; do
    [ -x "$p/bin/java" ] && { echo "$p"; return; }
  done
  echo "${JAVA_HOME:-}"
}

# ============================================================
# REPORT HEADER
# ============================================================
{
echo "$SEP"
echo "NetProbe — ALPHA REPORT"
echo "Date: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "Host: $(hostname 2>/dev/null)"
echo "Root: $ROOT"
echo "$SEP"
} | tee "$REPORT" >/dev/null

exec 3>&1

# ============================================================
# 1. ENVIRONMENT SNAPSHOT
# ============================================================
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
run ls -la /opt/java
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

# ============================================================
# 2. FIX — JDK & GRADLE
# ============================================================
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
  echo "Attempting install of openjdk-17..."
  if command -v apt-get >/dev/null 2>&1; then
    if sudo -n true 2>/dev/null; then
      sudo apt-get update -y >/dev/null 2>&1 || true
      sudo apt-get install -y openjdk-17-jdk >/dev/null 2>&1 || true
    else
      echo "sudo requires password — skipping auto-install"
    fi
    if [ -x /usr/lib/jvm/java-17-openjdk-amd64/bin/java ]; then
      export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
      export PATH="$JAVA_HOME/bin:$PATH"
      echo "Installed JAVA_HOME=$JAVA_HOME"
    fi
  fi
fi

sec "Upgrade Gradle wrapper -> $GRADLE_TARGET"
WP="gradle/wrapper/gradle-wrapper.properties"
if [ -f "$WP" ]; then
  cp "$WP" "${WP}.bak.$(date +%s)"
  # rewrite distributionUrl regardless of current version
  if grep -q '^distributionUrl=' "$WP"; then
    sed -i -E "s|^distributionUrl=.*|distributionUrl=https\\\\://services.gradle.org/distributions/gradle-${GRADLE_TARGET}-bin.zip|" "$WP"
  else
    echo "distributionUrl=https\\://services.gradle.org/distributions/gradle-${GRADLE_TARGET}-bin.zip" >> "$WP"
  fi
  run cat "$WP"
else
  echo "MISSING wrapper properties — cannot upgrade"
fi

sec "gradle.properties (ensure JVM args + JDK home)"
GP="gradle.properties"
if [ ! -f "$GP" ]; then
  : > "$GP"
fi
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
if [ -n "${JAVA_HOME:-}" ]; then
  ensure_prop "org.gradle.java.home" "$JAVA_HOME" "$GP"
fi
run cat "$GP"
} 2>&1 | tee -a "$REPORT" >&3

# ============================================================
# 3. CLEAN CACHES + STOP DAEMONS
# ============================================================
{
hdr "3. CLEAN"

sec "Stop gradle daemons"
./gradlew --stop 2>&1 || true

sec "Remove stale caches"
run rm -rf .gradle build app/build
run rm -rf "$HOME/.gradle/caches/8.2" "$HOME/.gradle/caches/8.0" "$HOME/.gradle/caches/8.1"
run rm -rf "$HOME/.gradle/caches/transforms-3" "$HOME/.gradle/caches/transforms-4"
run rm -rf "$HOME/.gradle/daemon"
run rm -rf "$HOME/.gradle/wrapper/dists/gradle-8.2-bin"
echo "done"
} 2>&1 | tee -a "$REPORT" >&3

# ============================================================
# 4. BUILD
# ============================================================
{
hdr "4. BUILD (assembleDebug --stacktrace)"

./gradlew assembleDebug --stacktrace --info \
  > "$BUILD_LOG" 2>&1
BUILD_RC=$?

sec "Exit code"
echo "$BUILD_RC"

sec "Tail 150 lines of build log"
tail -n 150 "$BUILD_LOG"

sec "Grep for critical errors"
grep -E "error:|FAILURE:|What went wrong|Unsupported class file|Could not resolve|Could not find|Execution failed|BUILD (FAILED|SUCCESSFUL)" \
  "$BUILD_LOG" | head -60

sec "Full build log path"
echo "$BUILD_LOG"
} 2>&1 | tee -a "$REPORT" >&3

# ============================================================
# 5. SOURCE & CONFIG FILES
# ============================================================
{
hdr "5. PROJECT STRUCTURE"

sec "Source tree (no build/git/cache artifacts)"
find . -type f \
  -not -path "*/.git/*" -not -path "*/build/*" \
  -not -path "*/.gradle/*" -not -path "*/.idea/*" \
  -not -name "*.apk" -not -name "*.zip" -not -name "*.jar" \
  -not -name "_build_full.txt" -not -name "_ALPHA_REPORT.txt" \
  | sort

sec "Gradle configuration files"
for f in settings.gradle settings.gradle.kts \
         build.gradle build.gradle.kts \
         gradle.properties \
         app/build.gradle app/build.gradle.kts \
         app/proguard-rules.pro \
         gradle/libs.versions.toml; do
  if [ -f "$f" ]; then
    echo
    echo "----- FILE: $f -----"
    cat "$f"
    echo "----- END: $f -----"
  fi
done

sec "AndroidManifest.xml"
for f in $(find . -name AndroidManifest.xml -not -path "*/build/*"); do
  echo "----- FILE: $f -----"
  cat "$f"
  echo "----- END: $f -----"
done

sec "Source files list"
find app/src -type f \( -name "*.java" -o -name "*.kt" -o -name "*.xml" \) 2>/dev/null | sort
} 2>&1 | tee -a "$REPORT" >/dev/null

# ============================================================
# 6. SOURCE CONTENTS (java/kt)
# ============================================================
{
hdr "6. SOURCE CONTENTS"

while IFS= read -r f; do
  [ -z "$f" ] && continue
  # skip huge generated files
  sz=$(wc -c < "$f" 2>/dev/null || echo 0)
  [ "$sz" -gt 200000 ] && { echo "----- SKIP (too large, ${sz}B): $f -----"; continue; }
  echo
  echo "----- FILE: $f -----"
  cat "$f"
  echo "----- END: $f -----"
done < <(find app/src -type f \( -name "*.java" -o -name "*.kt" \) 2>/dev/null | sort)
} 2>&1 | tee -a "$REPORT" >/dev/null

# ============================================================
# 7. RESOURCE XMLs (compact list, contents only for key ones)
# ============================================================
{
hdr "7. KEY RESOURCES"

for f in $(find app/src/main/res -type f -name "*.xml" 2>/dev/null | sort); do
  case "$f" in
    *values/strings.xml|*values/colors.xml|*values/themes.xml|*values/styles.xml|*xml/*.xml|*menu/*.xml|*layout/*.xml)
      echo
      echo "----- FILE: $f -----"
      cat "$f"
      echo "----- END: $f -----"
      ;;
  esac
done
} 2>&1 | tee -a "$REPORT" >/dev/null

# ============================================================
# 8. SUMMARY
# ============================================================
{
hdr "8. SUMMARY"
echo "Report file : $REPORT"
echo "Build log   : $BUILD_LOG"
echo "Lines       : $(wc -l < "$REPORT")"
echo "Size        : $(du -h "$REPORT" | cut -f1)"
echo
echo "NEXT STEP for ALPHA: paste contents of $REPORT"
echo "$SEP"
} 2>&1 | tee -a "$REPORT" >/dev/null

echo
echo "DONE. Report written to: $ROOT/$REPORT"
echo "Now run:  cat $REPORT"
