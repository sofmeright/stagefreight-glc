# StageFreight

> A reusable GitLab CI component for managing and publishing release artifacts and metadata in a consistent, automated way.  
> It focuses on orchestrating the release lifecycle: generating release notes, creating GitLab releases, documenting component inputs, and updating release status badges.  
> StageFreight is **not** responsible for building the artifacts themselves but provides a foundation to integrate various build/release targets like Docker images, Windows builds, and Linux packages.

StageFreight is developed by SoFMeRight of PrecisionPlanIT as part of his Ant Parade philosophy.

---

Notice: We are in BETA. Currently migrating many items from other repositories to consolidate them into one workflow herein. As its said we have strong ambitions, however we may not achieve all intended features on initial release.

---

## Overview

StageFreight enables your GitLab projects to:

- **Generate release notes** automatically from Git tags and commit history.
- **Create GitLab releases** with changelogs and attach catalog links.
- **Automatically update README documentation** by injecting a Markdown table listing component inputs.
- **Generate and update a dynamic SVG badge** reflecting the current release pipeline status.
- **Provide a consistent, reusable release pipeline** that can be extended to support multiple artifact types (Docker, Windows binaries, Linux packages, etc.).
- **Maintain unified versioning and release metadata across multiple platforms**, ensuring consistent tagging, changelog history, and documentation for every release target.

---

## Usage

Include StageFreight as a component in your `.gitlab-ci.yml`:

```yaml
include:
  - component: $CI_SERVER_FQDN/components/stagefreight/gl-component-release@main
    inputs:
      gitlab_domain: "https://gitlab.prplanit.com"
      component_spec_file: "templates/run.yml"
      readme_file: "README.md"
      output_md_file: "artifacts/component_inputs.md"
      badge_template: "assets/badge-release-generic.svg"
      badge_output: "assets/badge-release-status.svg"
      branch_name: "main"

stages:
  - release