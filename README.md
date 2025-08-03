# ![StageFreight](https://gitlab.prplanit.com/uploads/-/system/project/avatar/36/Screenshot_2025-08-01_214734.png?width=26) StageFreight

> A reusable GitLab CI component for managing and publishing release artifacts and metadata in a consistent, automated way.  
> It focuses on orchestrating the release lifecycle: generating release notes, creating GitLab releases, documenting component inputs, and updating release status badges.  
> StageFreight is **not** responsible for building the artifacts themselves but provides a foundation to integrate various build/release targets like Docker images, Windows builds, and Linux packages.

StageFreight is developed by SoFMeRight of PrecisionPlanIT as part of his Ant Parade philosophy.

---

Notice: We are not even in "BETA", this is early stages. We have strong ambitions, but this takes time.
> To release the base feature set we will migrate our release pipeline logic from other projects.

Progress:
- ✅ Docker - Working but some further optimization can be done. (Docker Hub is the only endpoint publishable currently.)
- 🤷🏽‍♀️ Components - We learned to execute scripts and assets alongside a component. 👍🏽 Unsure if generating a component inputs table setup will work like it did in external testing yet, got a syntax issue earlier but switched gears to Docker.
- 🚫 Binary (deb/exe/etc.) release management ~ We actually have a project this is done in we forgot about so there is code to be recycled. But we will need time to implement.

When will it be done?: I wish I knew. I wanted these three to have feature parity for what we have done in pipelines before I went to sleep but looks like a little more time.

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

## See Also:
- [Ansible (Gitlab Component)](https://gitlab.prplanit.com/components/ansible)
- [Ansible OCI](https://gitlab.prplanit.com/precisionplanit/ansible-oci) – Docker runtime image for Ansible workflows
- [StageFreight OCI (Docker Image)](https://gitlab.prplanit.com/precisionplanit/stagefreight-oci) – A general-purpose DevOps automation image built to accelerate CI/CD pipelines.

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
```

# Component Inputs

<!-- START_C_INPUTS_MAP -->
### Ungrouped



| Name | Required | Default | Description |
|------|----------|---------|-------------|
| badge_template | 🚫 | assets/badge-release-generic.svg | SVG template for badge generation |
| badge_output | 🚫 | assets/badge-release-status.svg | Final badge output path |
| component_spec_files | 🚫 | templates/gl-component-release.yml | Array of component spec files (for README input info) |
| readme_file | 🚫 | README.md | README file to inject Markdown input map into |
| branch_name | 🚫 | main | Branch to push badge/README changes to |
| gitlab_branch | 🚫 | main | Target Git branch for commits. |
| gitlab_domain | 🚫 | https://gitlab.prplanit.com | Base GitLab domain (used for badge & catalog links) |
| gitlab_job | 🚫 | run-ansible | The intended name of the CI job spawned by this component. |
| gitlab_stage | 🚫 | ansible | The intended name of the CI stage this job will run in. |
| gitlab_token | 🚫 |  | Token for authenticating GitLab API calls. |

<!-- END_C_INPUTS_MAP -->

---

# gl-component-release
> This is the component module that handles releases for GitLab components, it even manages its own release cycle using this module.

## gl-component-release: Pipeline Jobs

1. generate_release_notes
    - Trigger: Runs on Git tags (only: tags).
    - Purpose: Generates release notes from Git commit history between the previous and current tags.
    - Details: Uses generate-release_notes.sh which:
        - Verifies the provided tag exists.
        - Extracts notable changes from the tag message.
        - Collects changelog from commits between tags.
        - Output: Creates a release.md artifact with formatted release notes.
2. create-release
    - Trigger: Runs after generate_release_notes, on tags.
    - Purpose: Creates a GitLab Release using the notes from release.md.
    - Details:
        - Posts a release to the GitLab API with the tag and description.
        - Adds a link asset to the release pointing to the component catalog entry.
    - Notes: Handles "release already exists" case gracefully.
3. generate_readme_component_inputs
    - Trigger: Runs on tags.
    - Purpose: Parses the component spec YAML file to generate a Markdown table documenting all inputs, grouped by logical categories.
    - Details:
        - Extracts .spec.inputs from the component spec file using yq.
        - Uses a custom script generate-component_inputs_table.sh to convert inputs into a grouped Markdown table.
        - Injects the generated table into the README between markers <!-- START_C_INPUTS_MAP --> and <!-- END_C_INPUTS_MAP -->.
### Ungrouped



| Name | Required | Default | Description |
|------|----------|---------|-------------|
| badge_template | 🚫 | assets/badge-release-generic.svg | SVG template for badge generation |
| badge_output | 🚫 | assets/badge-release-status.svg | Final badge output path |
| component_spec_files | 🚫 | templates/gl-component-release.yml | Array of component spec files (for README input info) |
| readme_file | 🚫 | README.md | README file to inject Markdown input map into |
| branch_name | 🚫 | main | Branch to push badge/README changes to |
| gitlab_branch | 🚫 | main | Target Git branch for commits. |
| gitlab_domain | 🚫 | https://gitlab.prplanit.com | Base GitLab domain (used for badge & catalog links) |
| gitlab_job | 🚫 | run-ansible | The intended name of the CI job spawned by this component. |
| gitlab_stage | 🚫 | ansible | The intended name of the CI stage this job will run in. |
| gitlab_token | 🚫 |  | Token for authenticating GitLab API calls. |

