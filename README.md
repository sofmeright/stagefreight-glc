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
- ✅ Components - Component inputs table docs are generated for 1 spec file only, need to implement it as an array.
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
        - Injects the generated table into the README between markers <!-- START_C_INPUTS_(...) --> and <!-- END_C_(...)_MAP -->.
        - Pushes the updated README back to the repository via GitLab API.
    - Artifacts: Outputs the generated Markdown table as an artifact for debugging/inspection.
4. update_release_pipeline_status_badge
    - Trigger: Runs after create-release, on tags.
    - Purpose: Creates or updates an SVG badge reflecting the current pipeline status (passed, failed, running).
    - Details:
        - Queries all jobs in the current pipeline.
        - Determines overall status based on job statuses.
        - Replaces color and status placeholders in the SVG template.
        - Commits the updated badge SVG back to the repository.
    - Artifacts: Stores the badge SVG temporarily.

## gl-component-release: Scripts

1. `generate-release_notes.sh`
- Shell script to generate release notes by:
    - Validating the release tag.
    - Determining the previous tag.
    - Extracting tag message and commit log between tags.
    - Outputs formatted Markdown release notes.

2. `generate-component_inputs_table.sh`
- Bash script that:
    - Converts the component inputs YAML to JSON.
    - Uses jq to group inputs by _input_group_name and format a Markdown table with columns: Name, Required, Default, Description.
    - Converts boolean required flags to checkmark/emoji.
    - Outputs Markdown for injection into README.

## How to Build Your Own Component for Use with StageFreight

1. Define your component inputs clearly in a YAML spec file (e.g. templates/run.yml) under .spec.inputs.
2. Use metadata fields _input_group_name and _input_group_desc to logically group related inputs for documentation.
3. Include description, default values, and mark required inputs by omitting defaults.
4. Prepare your README with placeholder markers (without the parenthesis I used to stop it from replacing the example) for inputs injection:

    ```markdown
    ...
    <!-- START_C_INPUTS_(...) -->
    <!-- END_C_(...)_MAP -->
    ...
    ```
5. Provide a badge SVG template with placeholders {{COLOR}} and {{STATUS}} for dynamic replacement.
6. Add the StageFreight component to your .gitlab-ci.yml, passing the required inputs to connect your spec, README, badge paths, and GitLab domain.
7. Tag your releases in Git to trigger the pipeline.
> Optionally extend the pipeline by adding build/release jobs (Docker, Windows, Linux) before or after the StageFreight jobs, integrating your actual artifact generation.

## Notes & Future Work
> Currently, StageFreight supports release orchestration for Docker and Windows builds with plans for Linux binary or DEB package publishing.

The release notes script can be customized to better reflect project-specific changelog conventions.

Badge and input documentation injection promotes transparency and ease of use for component consumers.

The component is designed for reuse and extension across multiple projects and artifact types within your GitLab ecosystem.

This documentation should give you a clear understanding of how StageFreight works, how to use it, and how to build your own GitLab components compatible with its release tooling. We hope you are hyped as we were to start using this tool!
