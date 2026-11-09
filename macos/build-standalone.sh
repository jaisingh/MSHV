#!/usr/bin/env bash
#
# Make MSHV.app self-contained — embed Qt frameworks + all third-party
# dylibs into the bundle, rewrite load paths, ad-hoc sign. After this, the
# .app runs on a Mac without Homebrew.
#
# Run after a clean `make`:
#   ./macos/build-standalone.sh
#
# Or via the .pro target:
#   make standalone
#
# Prereqs: same as a regular build (qt@5, portaudio, fftw via Homebrew).
# Output: bin/MSHV.app — movable, redistributable to other Macs.
#
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP="$REPO/release/macos/MSHV-OSX.app"
BIN="$APP/Contents/MacOS/MSHV-OSX"
FW="$APP/Contents/Frameworks"

if [[ ! -x "$BIN" ]]; then
    echo "error: $BIN not found — run 'make' first." >&2
    exit 1
fi

# Pick the Qt installation matching the binary's architecture, NOT what
# `brew --prefix qt@5` returns — that's whichever brew is first in PATH
# (the brew binary is universal2 and ignores the calling arch). For an
# x86_64 binary built against /usr/local Intel-Qt, we MUST use the Intel
# macdeployqt, otherwise it copies arm64 plugins into our Intel bundle
# and the Qt platform plugin fails to load at runtime ("no Qt platform
# plugin could be initialized" → abort()).
BIN_ARCH="$(lipo -info "$BIN" 2>/dev/null | awk -F': ' '{print $NF}')"
case "$BIN_ARCH" in
    arm64)  QT_ROOT="${QT_ROOT:-/opt/homebrew/opt/qt@5}" ;;
    x86_64) QT_ROOT="${QT_ROOT:-/usr/local/opt/qt@5}" ;;
    *)
        echo "error: could not determine binary arch ($BIN_ARCH) — set QT_ROOT manually" >&2
        exit 1
        ;;
esac
MACDEPLOYQT="$QT_ROOT/bin/macdeployqt"
if [[ ! -x "$MACDEPLOYQT" ]]; then
    echo "error: macdeployqt not found at $MACDEPLOYQT" >&2
    echo "       (binary is $BIN_ARCH; expected Qt at $QT_ROOT)" >&2
    exit 1
fi
echo "==> using $QT_ROOT for $BIN_ARCH bundle"

# 1. macdeployqt walks the dependency tree, copies Qt frameworks, all the
#    third-party dylibs (libportaudio, libfftw3, libpng, etc.), and rewrites
#    install names to @executable_path/../Frameworks/. So this is most of
#    the work in one step.
#
#    macdeployqt refuses to run on an already-deployed bundle. Detect that
#    and skip — leaving an already-deployed bundle alone is fine.
if [[ -d "$FW" && -d "$FW/QtCore.framework" ]]; then
    echo "==> macdeployqt: already deployed (skipping)"
else
    echo "==> macdeployqt"
    "$MACDEPLOYQT" "$APP" -verbose=1 2>&1 | tail -5
fi

# 2. Belt-and-braces: if anything still points at Homebrew (some dylibs slip
#    through if their dep graph is unusual), embed them manually now.
#
#    Two flavours of Homebrew refs to handle:
#
#    a) Qt frameworks (*.framework/Versions/N/QtX). macdeployqt has already
#       copied these into $FW/QtX.framework/... on the first run; on
#       subsequent runs (after `make` rebuilds the binary), macdeployqt
#       refuses to re-deploy. We just need to rewrite the load path on the
#       target back to @executable_path/../Frameworks/QtX.framework/.../QtX.
#       DO NOT flat-copy framework binaries to $FW/QtX — the flat copy lacks
#       macdeployqt's install_name rewrites for sub-deps (libpcre2, libzstd,
#       libglib, libpng, etc.) and silently pulls them from /opt/homebrew at
#       runtime, defeating the standalone bundle.
#
#    b) Plain dylibs (libportaudio, libfftw3, …). Flat copy + rewrite is fine
#       because they don't have a framework dir for macdeployqt to populate.
embed_remaining() {
    local target="$1"
    local rewrote_any=0
    while read -r DEP; do
        case "$DEP" in
            /opt/homebrew/* | /usr/local/Cellar/* | /usr/local/opt/* )
                # Qt-style framework? Path looks like .../QtX.framework/Versions/N/QtX
                local FW_REL
                FW_REL="$(printf '%s\n' "$DEP" | sed -nE 's|.*/([^/]+\.framework/.*)$|\1|p')"
                if [[ -n "$FW_REL" ]]; then
                    if [[ -f "$FW/$FW_REL" ]]; then
                        echo "    rewriting framework ref: $FW_REL (was $DEP)"
                        install_name_tool -change "$DEP" \
                            "@executable_path/../Frameworks/$FW_REL" "$target"
                    else
                        # Should not happen if macdeployqt ran first.
                        echo "    WARN: framework ref to $DEP but $FW/$FW_REL missing — skipping"
                    fi
                else
                    local NAME
                    NAME="$(basename "$DEP")"
                    echo "    embedding nested dep: $NAME (was $DEP)"
                    if [[ ! -f "$FW/$NAME" ]]; then
                        cp "$DEP" "$FW/$NAME"
                        chmod u+w "$FW/$NAME"
                        install_name_tool -id "@executable_path/../Frameworks/$NAME" "$FW/$NAME"
                    fi
                    install_name_tool -change "$DEP" \
                        "@executable_path/../Frameworks/$NAME" "$target"
                fi
                rewrote_any=1
                ;;
        esac
    done < <(otool -L "$target" | awk 'NR>1 {print $1}')
    return $rewrote_any
}

# Repair any "flat Qt ref" left behind by an earlier run of this script —
# load paths like @executable_path/../Frameworks/QtCore that point at a
# flat-copied framework binary instead of the proper
# QtCore.framework/Versions/5/QtCore. Rewrite them to the framework path
# while we still have the existing references to install_name_tool -change.
fix_flat_qt_refs() {
    local target="$1"
    while read -r DEP; do
        case "$DEP" in
            @executable_path/../Frameworks/Qt*)
                local rest="${DEP#@executable_path/../Frameworks/}"
                # flat refs have no further slash; framework refs do.
                if [[ "$rest" != */* ]] && [[ -d "$FW/$rest.framework" ]]; then
                    local TARGET_REL="$rest.framework/Versions/5/$rest"
                    if [[ -f "$FW/$TARGET_REL" ]]; then
                        echo "    fixing flat Qt ref: $rest -> $TARGET_REL"
                        install_name_tool -change "$DEP" \
                            "@executable_path/../Frameworks/$TARGET_REL" "$target"
                    fi
                fi
                ;;
        esac
    done < <(otool -L "$target" | awk 'NR>1 {print $1}')
}

echo "==> repair any flat Qt refs from prior runs"
fix_flat_qt_refs "$BIN"
for LIB_PATH in "$FW"/*.dylib; do
    [[ -f "$LIB_PATH" ]] || continue
    fix_flat_qt_refs "$LIB_PATH"
done
for FW_BIN in "$FW"/*.framework/Versions/*/[A-Z]*; do
    [[ -f "$FW_BIN" ]] || continue
    fix_flat_qt_refs "$FW_BIN"
done

# Now-unreferenced flat Qt copies can be removed. Detect by: file in $FW
# with a Qt name AND a sibling .framework dir with the same Qt name.
echo "==> remove any stale flat Qt copies"
for FLAT in "$FW"/Qt*; do
    [[ -f "$FLAT" ]] || continue
    base="$(basename "$FLAT")"
    if [[ -d "$FW/$base.framework" ]]; then
        echo "    removing stale flat copy: $base"
        rm -f "$FLAT"
    fi
done

echo "==> sweep for any leftover Homebrew references"
embed_remaining "$BIN" || true
for LIB_PATH in "$FW"/*.dylib; do
    [[ -f "$LIB_PATH" ]] || continue
    embed_remaining "$LIB_PATH" || true
done
for FW_BIN in "$FW"/*.framework/Versions/*/[A-Z]*; do
    [[ -f "$FW_BIN" ]] || continue
    embed_remaining "$FW_BIN" || true
done

# 2b. @rpath deps. Homebrew dylibs reference siblings as @rpath/libX.dylib
#     (libbrotlidec -> libbrotlicommon, libwebp -> libsharpyuv, gcc's
#     libstdc++ -> libgcc_s). The sweep above only matches absolute
#     /opt/homebrew paths, so these were never embedded: they resolved only
#     via the hardcoded /opt/homebrew/Cellar/gcc/<ver> LC_RPATHs the linker
#     put in the binary, or not at all. A missing libbrotlicommon breaks
#     libfreetype -> libqcocoa, and Qt abort()s with "no Qt platform plugin".
#     Embed every @rpath dep, rewrite it to @executable_path, then strip all
#     absolute LC_RPATHs so nothing can silently resolve into Homebrew.
BREW_PREFIX="${QT_ROOT%/opt/qt@5}"
RPATH_SEARCH=("$BREW_PREFIX/lib" "$BREW_PREFIX/opt/gcc/lib/gcc/current")

bundle_machos() {
    find "$APP/Contents/MacOS" "$FW" "$APP/Contents/PlugIns" -type f 2>/dev/null |
        while read -r f; do
            file "$f" | grep -q 'Mach-O' && printf '%s\n' "$f"
        done
}

embed_rpath_deps() {
    local target="$1" own_id dep name src d changed=0
    own_id="$(otool -D "$target" | awk 'NR>1')"
    while read -r dep; do
        [[ "$dep" == @rpath/* && "$dep" != "$own_id" ]] || continue
        name="${dep#@rpath/}"
        if [[ ! -f "$FW/$name" ]]; then
            src=""
            for d in "${RPATH_SEARCH[@]}"; do
                [[ -f "$d/$name" ]] && { src="$d/$name"; break; }
            done
            if [[ -z "$src" ]]; then
                echo "    ERROR: $(basename "$target") needs $dep, not found in ${RPATH_SEARCH[*]}" >&2
                exit 1
            fi
            echo "    embedding @rpath dep: $name (from $src)"
            cp -L "$src" "$FW/$name"
            chmod u+w "$FW/$name"
            install_name_tool -id "@executable_path/../Frameworks/$name" "$FW/$name" 2>/dev/null
            changed=1
        fi
        install_name_tool -change "$dep" "@executable_path/../Frameworks/$name" "$target" 2>/dev/null
    done < <(otool -L "$target" | awk 'NR>1 {print $1}')
    return $changed
}

echo "==> embed @rpath deps"
# Newly embedded libs can have @rpath / Homebrew deps of their own, so loop
# until a full pass embeds nothing new.
while :; do
    more=0
    while read -r f; do
        embed_rpath_deps "$f" || more=1
    done < <(bundle_machos)
    for LIB_PATH in "$FW"/*.dylib; do
        embed_remaining "$LIB_PATH" || more=1
    done
    [[ $more -eq 0 ]] && break
done

echo "==> strip absolute LC_RPATHs"
while read -r f; do
    otool -l "$f" | awk '/cmd LC_RPATH/ {getline; getline; print $2}' |
        while read -r rp; do
            [[ "$rp" == @* ]] && continue
            echo "    $(basename "$f"): -rpath $rp"
            install_name_tool -delete_rpath "$rp" "$f" 2>/dev/null
        done
done < <(bundle_machos)

# 3. Ad-hoc codesign (required after install_name_tool mutates the binary).
#    codesign rejects bundle members with com.apple.{FinderInfo,provenance,
#    quarantine} xattrs ("resource fork, Finder information, or similar
#    detritus not allowed"). com.apple.provenance specifically is OS-
#    managed and resists `xattr -d`. Bypass by ditto-copying to a clean
#    sibling with --noextattr/--norsrc/--noacl, then swapping in place.
echo "==> strip xattrs (clean ditto copy)"
CLEAN="$APP.clean"
rm -rf "$CLEAN"
ditto --noextattr --norsrc --noacl "$APP" "$CLEAN"
rm -rf "$APP"
mv "$CLEAN" "$APP"

# Codesign — pick a Developer ID Application certificate from the keychain
# if one is available (allows notarisation later), otherwise fall back to
# ad-hoc signing. The DEVELOPER_ID_APPLICATION env var lets the operator
# override the auto-detected identity if they have multiple certs.
SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
fi
ENTITLEMENTS="$REPO/macos/entitlements.plist"
# No `| tail -N` here — codesign emits one error line per failing nested
# item, and trimming the tail can hide the actual offender. Output is
# short anyway. If codesign fails, the unfiltered errors point at the file.
if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "==> codesign with Developer ID + hardened runtime"
    echo "    identity: $SIGN_IDENTITY"
    # Strip remaining xattrs immediately before codesign. Even after the
    # ditto-strip above, macOS / iCloud / file-provider daemons can re-
    # apply com.apple.FinderInfo and com.apple.fileprovider.fpfs#P (e.g.
    # if the build tree lives under an indexed path like ~/Documents).
    # codesign with hardened runtime rejects non-zero FinderInfo as
    # "resource fork, Finder information, or similar detritus". Doing
    # the strip + sign back-to-back narrows the window for re-application.
    xattr -cr "$APP" 2>/dev/null || true
    # --options runtime  : enable the hardened runtime (required for
    #                      notarisation).
    # --timestamp        : embed an Apple-trusted timestamp (required for
    #                      notarisation; needs network access at sign time).
    # --entitlements ... : the disable-library-validation entitlement (for
    #                      our bundled Qt frameworks) and audio-input.
    # --deep             : sign all nested binaries with the same identity.
    codesign --force --deep \
        --sign "$SIGN_IDENTITY" \
        --options runtime \
        --timestamp \
        --entitlements "$ENTITLEMENTS" \
        "$APP"
else
    echo "==> ad-hoc codesign (no Developer ID Application cert in keychain)"
    echo "    bundle will work locally but cannot be notarised."
    xattr -cr "$APP" 2>/dev/null || true
    codesign --force --deep --sign - "$APP"
fi

# Bump the .app directory's mtime so Finder/ls show "when this build
# happened" instead of the ditto-preserved mtime from the original
# bundle. Important for the operator who reads the .app mtime to know
# whether to re-drag to /Applications.
touch "$APP"

# 4. Verify
echo "==> verify"
EXTERNAL="$(otool -L "$BIN" | awk 'NR>1 {print $1}' | grep -E '^(/opt/homebrew|/usr/local/Cellar|/usr/local/opt)' || true)"
if [[ -n "$EXTERNAL" ]]; then
    echo "WARN: main binary still links Homebrew paths:"
    echo "$EXTERNAL" | sed 's/^/    /'
else
    echo "  main binary: clean (no Homebrew paths)"
fi

LIB_LEAKS=0
for LIB_PATH in "$FW"/*.dylib "$FW"/*.framework/Versions/*/[A-Z]*; do
    [[ -f "$LIB_PATH" ]] || continue
    EXTERNAL="$(otool -L "$LIB_PATH" 2>/dev/null | awk 'NR>1 {print $1}' \
                | grep -E '^(/opt/homebrew|/usr/local/Cellar|/usr/local/opt)' || true)"
    if [[ -n "$EXTERNAL" ]]; then
        LIB_LEAKS=$((LIB_LEAKS + 1))
        echo "WARN: $(basename "$LIB_PATH") still links Homebrew:"
        echo "$EXTERNAL" | sed 's/^/    /'
    fi
done
[[ $LIB_LEAKS -eq 0 ]] && echo "  embedded libs: all clean"

# Every non-system dep of every Mach-O (incl. plugins) must resolve inside
# the bundle, and nothing may still use @rpath. Otherwise the app breaks
# the moment Homebrew upgrades or removes the original — fail the build.
UNRESOLVED=0
while read -r f; do
    own_id="$(otool -D "$f" | awk 'NR>1')"
    while read -r dep; do
        [[ "$dep" == "$own_id" ]] && continue
        case "$dep" in
            /System/* | /usr/lib/*) continue ;;
            @executable_path/*)
                [[ -e "$APP/Contents/MacOS/${dep#@executable_path/}" ]] && continue ;;
        esac
        echo "ERROR: $(basename "$f") -> $dep does not resolve inside the bundle"
        UNRESOLVED=$((UNRESOLVED + 1))
    done < <(otool -L "$f" | awk 'NR>1 {print $1}')
done < <(bundle_machos)
if [[ $UNRESOLVED -gt 0 ]]; then
    echo "==> FAILED: $UNRESOLVED unresolved deps" >&2
    exit 1
fi
echo "  all deps resolve inside the bundle"

SIZE="$(du -sh "$APP" | cut -f1)"
echo "==> done. $APP ($SIZE) is now self-contained."
