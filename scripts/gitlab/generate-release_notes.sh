#!/usr/bin/env sh
# scripts/release-notes.sh

RELEASE=${CI_COMMIT_TAG:-$1}

if [ -z "${RELEASE}" ]; then
  echo "Usage:"
  echo "./scripts/release-notes.sh v0.1.0"
  exit 1
fi

if ! git rev-list "${RELEASE}" >/dev/null 2>&1; then
  echo "Tag ${RELEASE} does not exist"
  exit 1
fi

# Get the tag message (annotation) if this is an annotated tag
# (GitLab UI creates an annotated tag when you fill "Set tag message")
TAG_MESSAGE="$(git for-each-ref "refs/tags/${RELEASE}" --format='%(contents)' \
  | sed -e '/^-----BEGIN PGP SIGNATURE-----/,$d' -e '1{/^[[:space:]]*$/d;}')"

# (optional) fallback to commit message if tag is lightweight/no message
# [ "${TAG_MESSAGE}" ] || TAG_MESSAGE="$(git show -s --format=%B "${RELEASE}")"

PREV_RELEASE=$(git describe --tags --abbrev=0 "${RELEASE}^" 2>/dev/null) || \
PREV_RELEASE=$(git rev-list --max-parents=0 "${RELEASE}^")

range="${PREV_RELEASE}..${RELEASE}"

# -------- Flexible, case-insensitive patterns --------
# Features: feat/feature/features/new feature(s) + loose separators
FEATURE_GREP='^[[:space:]]*(\[[^]]+\][[:space:]]*)*(feat(ure)?s?|new[[:space:]]+feat(ure)?s?)[[:space:]]*([!]?[:.\-–—( ]|$)'

# Fixes: fix/fixes/hotfix/bugfix/patch/bug/resolve(d|s)/repair + loose separators
FIX_GREP='^[[:space:]]*(\[[^]]+\][[:space:]]*)*(fix(es)?|hotfix|bugfix|patch|bug|resolv(e|ed|es)|repair)[[:space:]]*([!]?[:.\-–—( ]|$)'

# Breaking:
#  A) type(scope)!: subject   (subject marker)
#  B) "breaking change(s)" / "breaking-change(s)"   (footer/body or subject)
#  C) "backward(s) incompatible"/"incompatibility"  (optional extra signal)
BREAK_GREP='(^[^:\n]*![[:space:]]*[:.\-–—( ]|(^|[[:space:]])breaking([ -]?changes?)?([[:space:]]*[:.\-–—( ]|$)|(^|[[:space:]])backwards?[ -]?incompatib(le|ility)([[:space:]]*[:.\-–—( ]|$))'

grab() {
  git log --no-merges --regexp-ignore-case --extended-regexp \
    --pretty='- %s (%aN)' "$range" --grep "$1"
}

# Strip helpers:
#  1) drop leading "- " added by --pretty
#  2) remove section-specific keywords/prefixes
strip_bullet() { sed -E 's/^-[[:space:]]*//'; }
# Turn non-empty lines into "- ..." bullets (keeps one line per item)
format_bullets() { awk 'NF{print "- " $0}'; }

FEATS="$(
  grab "$FEATURE_GREP" \
  | strip_bullet \
  | sed -E 's/^(\[[^]]+\][[:space:]]*)*(feat(ure)?s?|new[[:space:]]+feat(ure)?s?)[[:space:]]*([!]?[:.\-–—( ]\s*)?//I' \
  | format_bullets
)"

FIXES="$(
  grab "$FIX_GREP" \
  | strip_bullet \
  | sed -E 's/^(\[[^]]+\][[:space:]]*)*(fix(es)?|hotfix|bugfix|patch|bug|resolv(e|ed|es)|repair)[[:space:]]*([!]?[:.\-–—( ]\s*)?//I' \
  | format_bullets
)"

BREAKS="$(
  grab "$BREAK_GREP" \
  | strip_bullet \
  | sed -E '
      s/^[a-z]+(\([^)]+\))?![[:space:]]*[:.\-–—( ]\s*//I;
      s/^breaking([ -]?changes?)?[[:space:]]*[:.\-–—( ]\s*//I;
      s/^backwards?[ -]?incompatib(le|ility)[[:space:]]*[:.\-–—( ]\s*//I
    ' \
  | awk '!seen[$0]++' \
  | format_bullets
)"

# Compose NOTABLE_CHANGES only when non-empty (no trailing padding)
NOTABLE_CHANGES=""
sep=""
if [ -n "$FEATS" ]; then
  NOTABLE_CHANGES="${NOTABLE_CHANGES}${sep}### Features
$FEATS"
  sep="

"
fi
if [ -n "$FIXES" ]; then
  NOTABLE_CHANGES="${NOTABLE_CHANGES}${sep}### Fixes
$FIXES"
  sep="

"
fi
if [ -n "$BREAKS" ]; then
  NOTABLE_CHANGES="${NOTABLE_CHANGES}${sep}### Breaking changes
$BREAKS"
fi

CHANGELOG=$(git log --no-merges --pretty=format:'- [%h] %s (%aN)' "${PREV_RELEASE}..${RELEASE}")

# Fallbacks for local runs
PROJECT_NAME="${CI_PROJECT_NAME:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo .)")}"
PROJECT_URL="${CI_PROJECT_URL:-$(git config --get remote.origin.url 2>/dev/null | sed 's/\.git$//')}"

# ---- Always-on compact Assets note (lists only confirmed items) ----
assets=""
add_asset() { [ "${1:-}" = "true" ] && assets="${assets:+$assets • }$2"; }

add_asset "${BUILT_IMAGES:-}"     "images"
add_asset "${BUILT_BINARIES:-}"   "binaries"
add_asset "${BUILT_PACKAGES:-}"   "packages"
add_asset "${BUILT_COMPONENTS:-}" "components"
add_asset "${BUILT_HELM:-}"       "helm"
add_asset "${BUILT_SBOM:-}"       "SBOM"

if [ -n "$assets" ]; then
  ASSETS_NOTE="> Assets available: $assets — see links in the **Assets** box at the top of this release."
else
  ASSETS_NOTE="> Tip: When assets (images, binaries, packages, components, helm, SBOM) are published, their links appear in the **Assets** box at the top."
fi
# -------------------------------------------------------------------

cat <<EOF
# AntParade GitOps 🐜 — ${PROJECT_NAME}:${RELEASE}

# Release Highlights
${TAG_MESSAGE:-}

# Notable Changes
${NOTABLE_CHANGES}

# Images & Artifacts Availability
${ASSETS_NOTE}

## Installation
- For installation and usage instructions, see the [README](${PROJECT_URL}/-/blob/${RELEASE}/README.md)

## Contributing
If you find this useful, you can help:
- Submit a Merge Request with new features or fixes
- Report bugs or issues on [Issues](${PROJECT_URL}/-/issues)
- You can donate funds to help with my operating cost.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/T6T41IT163)

## Changelog
${CHANGELOG}
EOF
