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

FEATS="$(
  grab "$FEATURE_GREP" \
  | strip_bullet \
  | sed -E 's/^(\[[^]]+\][[:space:]]*)*(feat(ure)?s?|new[[:space:]]+feat(ure)?s?)[[:space:]]*([!]?[:.\-–—( ]\s*)?//I'
)"

FIXES="$(
  grab "$FIX_GREP" \
  | strip_bullet \
  | sed -E 's/^(\[[^]]+\][[:space:]]*)*(fix(es)?|hotfix|bugfix|patch|bug|resolv(e|ed|es)|repair)[[:space:]]*([!]?[:.\-–—( ]\s*)?//I'
)"

BREAKS="$(
  grab "$BREAK_GREP" \
  | strip_bullet \
  | sed -E '
      s/^[a-z]+(\([^)]+\))?![[:space:]]*[:.\-–—( ]\s*//I;           # drop "type(scope)!: "
      s/^breaking([ -]?changes?)?[[:space:]]*[:.\-–—( ]\s*//I;      # drop "breaking change(s)[…]"
      s/^backwards?[ -]?incompatib(le|ility)[[:space:]]*[:.\-–—( ]\s*//I
    ' \
  | awk '!seen[$0]++'   # de-dupe
)"

# Compose NOTABLE_CHANGES only when non-empty
NOTABLE_CHANGES=""
[ -n "$FEATS"  ] && NOTABLE_CHANGES="${NOTABLE_CHANGES}### Features
$FEATS

"
[ -n "$FIXES"  ] && NOTABLE_CHANGES="${NOTABLE_CHANGES}### Fixes
$FIXES

"
[ -n "$BREAKS" ] && NOTABLE_CHANGES="${NOTABLE_CHANGES}### Breaking changes
$BREAKS

"
NOTABLE_CHANGES=$(git tag -l --format='%(contents)' "$RELEASE" | sed '/-----BEGIN PGP SIGNATURE-----/,//d' | tail -n +6)
CHANGELOG=$(git log --no-merges --pretty=format:'- [%h] %s (%aN)' "${PREV_RELEASE}..${RELEASE}")

# Fallbacks for local runs
PROJECT_NAME="${CI_PROJECT_NAME:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo .)")}"
PROJECT_URL="${CI_PROJECT_URL:-$(git config --get remote.origin.url 2>/dev/null | sed 's/\.git$//')}"

# Optional status hints (set these in CI before calling the script if you want green ticks)
# BUILT_BINARIES=true
# BUILT_COMPONENTS=true
# BUILT_IMAGES=true
# BUILT_PACKAGES=true
# BUILT_HELM=true
# BUILT_SBOM=true

yn() { [ "$1" = "true" ] && printf "✅ " || printf ""; }

cat <<EOF
# AntParade GitOps 🐜 — ${PROJECT_NAME}:${RELEASE}

# Release Highlights
${TAG_MESSAGE:-}

# Noteable Changes
${NOTABLE_CHANGES}

# Images & Artifacts Availability

If **container images**, **binaries**, or other **artifacts** were produced for this release, you’ll find them in the **Assets** section of this Release (above).  
Links are added automatically for any configured registries (Docker Hub, Quay, JFrog, GHCR, GitLab Container Registry, or a generic OCI endpoint), as well as any uploaded files.

Typical assets you may see:
- $(yn "${BUILT_IMAGES:-}")Container images (registry links)
- $(yn "${BUILT_PACKAGES:-}")OS packages (\`.deb\`, \`.rpm\`, \`.apk\`, \`.msi\`)
- $(yn "${BUILT_BINARIES:-}")CLI binaries / archives (e.g., \`.tar.gz\`, \`.zip\`, \`.exe\`)
- $(yn "${BUILT_COMPONENTS:-}")GitLab CI/CD components (published to Catalog)
- $(yn "${BUILT_HELM:-}")Helm charts / Kubernetes manifests
- $(yn "${BUILT_SBOM:-}")SBOMs / attestations (e.g., SLSA provenance)

> Note: We intentionally keep release notes clean and defer to the **Assets** panel for direct download links.

## Installation

For installation and usage instructions, see the [README](${PROJECT_URL}/-/blob/${RELEASE}/README.md)

## Contributing

If you find this useful, you can help:

- Submit a Merge Request with new features or fixes
- Report bugs or issues on [Issues](${PROJECT_URL}/-/issues)

## Changelog

${CHANGELOG}
EOF