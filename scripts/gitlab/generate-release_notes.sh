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

cat <<EOF
# AntParade GitOps 🐜 - ${CI_PROJECT_NAME}:${CI_COMMIT_TAG}

${NOTABLE_CHANGES}

# Image Availability:

- [Docker Hub (docker.io)](https://hub.docker.com/r/prplanit/ansible-oci/tags)

## Installation

For installation and usage instructions, please refer to the [README](https://gitlab.prplanit.com/precisionplanit/ansible-oci/-/blob/${RELEASE}/README.md)

## Contributing

If you find this image useful, you can help:

- Submit a Merge Request with new features or fixes
- Report bugs or issues on [GitLab Issues](https://gitlab.prplanit.com/precisionplanit/ansible-oci/-/issues)

## Changelog

${CHANGELOG}
EOF