#!/usr/bin/env bash
set +e

OUT="ci-diagnostics"
mkdir -p "$OUT"

{
  echo "date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "runner=${RUNNER_OS:-unknown}"
  echo "repo=${GITHUB_REPOSITORY:-unknown}"
  echo "sha=${GITHUB_SHA:-unknown}"
  echo "ref=${GITHUB_REF:-unknown}"
  echo "run_id=${GITHUB_RUN_ID:-unknown}"
  echo "run_number=${GITHUB_RUN_NUMBER:-unknown}"
} > "$OUT/context.txt" 2>&1 || true

git status --short > "$OUT/root-git-status-short.txt" 2>&1 || true
git status > "$OUT/root-git-status.txt" 2>&1 || true
git log -1 --decorate --stat > "$OUT/root-last-commit.txt" 2>&1 || true
git ls-files -s > "$OUT/root-ls-files-s.txt" 2>&1 || true
find . -maxdepth 3 -type f | sort > "$OUT/root-file-list-depth3.txt" 2>&1 || true

# Copy workflow and relevant project scripts.
mkdir -p "$OUT/root-files"
cp -a .github "$OUT/root-files/github" 2>/dev/null || true
cp -a scripts "$OUT/root-files/scripts" 2>/dev/null || true
cp -a panda "$OUT/root-files/panda" 2>/dev/null || true
cp -a patches "$OUT/root-files/patches" 2>/dev/null || true

# Capture failed server repository state if it exists.
if [ -d PandaSpigot-Server ]; then
  mkdir -p "$OUT/PandaSpigot-Server"

  (
    cd PandaSpigot-Server || exit 0
    git status --short > "../$OUT/PandaSpigot-Server/git-status-short.txt" 2>&1 || true
    git status > "../$OUT/PandaSpigot-Server/git-status.txt" 2>&1 || true
    git log --oneline --decorate -20 > "../$OUT/PandaSpigot-Server/git-log-20.txt" 2>&1 || true
    git rev-parse HEAD > "../$OUT/PandaSpigot-Server/HEAD.txt" 2>&1 || true
    git ls-files -s > "../$OUT/PandaSpigot-Server/ls-files-s.txt" 2>&1 || true
    git diff -- src/main/java/net/minecraft/server/EntityHuman.java \
      src/main/java/net/minecraft/server/EntityArrow.java \
      src/main/java/net/minecraft/server/EntityProjectile.java \
      src/main/java/net/minecraft/server/EntityFishingHook.java \
      src/main/java/net/minecraft/server/Explosion.java \
      > "../$OUT/PandaSpigot-Server/failed-files-diff.txt" 2>&1 || true
    git am --show-current-patch=diff > "../$OUT/PandaSpigot-Server/current-am-patch.diff" 2>&1 || true
    git am --show-current-patch=raw > "../$OUT/PandaSpigot-Server/current-am-patch.raw" 2>&1 || true
  ) || true

  if [ -d PandaSpigot-Server/.git/rebase-apply ]; then
    cp -a PandaSpigot-Server/.git/rebase-apply "$OUT/PandaSpigot-Server/rebase-apply" 2>/dev/null || true
  fi

  mkdir -p "$OUT/PandaSpigot-Server/source-files/net/minecraft/server"
  for f in \
    EntityHuman.java \
    EntityLiving.java \
    EntityArrow.java \
    EntityProjectile.java \
    EntityFishingHook.java \
    Explosion.java \
    Entity.java \
    EntityPlayer.java; do
    if [ -f "PandaSpigot-Server/src/main/java/net/minecraft/server/$f" ]; then
      cp "PandaSpigot-Server/src/main/java/net/minecraft/server/$f" \
        "$OUT/PandaSpigot-Server/source-files/net/minecraft/server/$f" || true
      nl -ba "PandaSpigot-Server/src/main/java/net/minecraft/server/$f" \
        > "$OUT/PandaSpigot-Server/source-files/net/minecraft/server/$f.numbered.txt" 2>&1 || true
    fi
  done

  mkdir -p "$OUT/PandaSpigot-Server/source-files/com/hpfxd/pandaspigot"
  if [ -d PandaSpigot-Server/src/main/java/com/hpfxd/pandaspigot ]; then
    cp -a PandaSpigot-Server/src/main/java/com/hpfxd/pandaspigot \
      "$OUT/PandaSpigot-Server/source-files/com/hpfxd/" 2>/dev/null || true
  fi

  tar -czf "$OUT/PandaSpigot-Server-full.tar.gz" PandaSpigot-Server 2> "$OUT/tar-PandaSpigot-Server-full.stderr.txt" || true
fi

# Capture API state if it exists.
if [ -d PandaSpigot-API ]; then
  (
    cd PandaSpigot-API || exit 0
    mkdir -p "../$OUT/PandaSpigot-API"
    git status --short > "../$OUT/PandaSpigot-API/git-status-short.txt" 2>&1 || true
    git log --oneline --decorate -20 > "../$OUT/PandaSpigot-API/git-log-20.txt" 2>&1 || true
    git ls-files -s > "../$OUT/PandaSpigot-API/ls-files-s.txt" 2>&1 || true
  ) || true
  tar -czf "$OUT/PandaSpigot-API-full.tar.gz" PandaSpigot-API 2> "$OUT/tar-PandaSpigot-API-full.stderr.txt" || true
fi

# Include base metadata, not full base tree unless present and needed.
if [ -d base/Paper/PaperSpigot-Server ]; then
  mkdir -p "$OUT/base-PaperSpigot-Server"
  (
    cd base/Paper/PaperSpigot-Server || exit 0
    git status --short > "../../../$OUT/base-PaperSpigot-Server/git-status-short.txt" 2>&1 || true
    git log --oneline --decorate -20 > "../../../$OUT/base-PaperSpigot-Server/git-log-20.txt" 2>&1 || true
    git rev-parse HEAD > "../../../$OUT/base-PaperSpigot-Server/HEAD.txt" 2>&1 || true
  ) || true
fi

# A compact archive of all diagnostics.
tar -czf ci-diagnostics.tar.gz "$OUT" 2> "$OUT/tar-ci-diagnostics.stderr.txt" || true

echo "Diagnostic collection finished. Files:"
find "$OUT" -maxdepth 3 -type f | sort | sed -n '1,200p' || true
