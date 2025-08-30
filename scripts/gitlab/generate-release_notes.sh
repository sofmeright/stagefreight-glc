#!/usr/bin/env sh

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

PREV_RELEASE=$(git describe --tags --abbrev=0 "${RELEASE}^" 2>/dev/null) || \
PREV_RELEASE=$(git rev-list --max-parents=0 "${RELEASE}^")

NOTABLE_CHANGES=$(git tag -l --format='%(contents)' "$RELEASE" | sed '/-----BEGIN PGP SIGNATURE-----/,//d' | tail -n +6)
CHANGELOG=$(git log --no-merges --pretty=format:'- [%h] %s (%aN)' "${PREV_RELEASE}..${RELEASE}")

# Fallbacks for local runs
PROJECT_NAME="${CI_PROJECT_NAME:-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo .)")}"
PROJECT_URL="${CI_PROJECT_URL:-$(git config --get remote.origin.url 2>/dev/null | sed 's/\.git$//')}"

cat <<EOF
# AntParade GitOps 🐜 - ${PROJECT_NAME}:${RELEASE}

${NOTABLE_CHANGES}

# Image Availability

If container images were built and pushed for this release, the registry links are listed in the **Assets** section of this Release (above).  
Links are added automatically for any configured registries (Docker Hub, Quay, JFrog, GHCR, GitLab Container Registry, or generic OCI).

## Installation

For installation and usage instructions, please refer to the [README](${PROJECT_URL}/-/blob/${RELEASE}/README.md)

## Contributing

If you find this image useful, you can help:

- Submit a Merge Request with new features or fixes
- Report bugs or issues on [Issues](${PROJECT_URL}/-/issues)
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/T6T41IT163)

## Changelog

${CHANGELOG}
EOF