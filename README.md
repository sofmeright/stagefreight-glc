![Latest Release](https://gitlab.prplanit.com/components/stagefreight/-/badges/release.svg) ![Latest Release Status](https://gitlab.prplanit.com/components/stagefreight/-/raw/main/assets/badge-release-status.svg) [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/T6T41IT163)

# ![StageFreight](https://gitlab.prplanit.com/uploads/-/system/project/avatar/36/Screenshot_2025-08-01_214734.png?width=26) StageFreight

> A reusable GitLab CI component for managing and publishing release artifacts and metadata in a consistent, automated way.  
> It focuses on orchestrating the release lifecycle: generating release notes, creating GitLab releases, documenting component inputs, and updating release status badges.  
> StageFreight is **not** responsible for building the artifacts themselves but provides a foundation to integrate various build/release targets like Docker images, Windows builds, and Linux packages.

StageFreight is developed by SoFMeRight of PrecisionPlanIT as part of his Ant Parade philosophy.

---

Notice: We are not even in "BETA", this is early stages. We have strong ambitions, but this takes time.
> To release the base feature set we will migrate our release pipeline logic from other projects.

Progress:
- ✅ Docker - Push to as many unique registries as you need. (Docker Hub is the only one you can embed in the release page, currently.)
- ✅ Components - Basic features working as expected! Will implement more features in the future.
- 🚫 Binary (deb/exe/etc.) release management ~ We actually have a project this is done in we forgot about so there is code to be recycled. But we will need time to implement.

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

## `gl-component-release`

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

## `gl-docker-release`

### You can use this syntax to push to up to 3 registries.

```yaml
cache:
  key: "${CI_COMMIT_REF_SLUG}-${CI_PIPELINE_ID}"
  paths:
    - .cache/

include:
  - component: $CI_SERVER_FQDN/components/stagefreight/gl-docker-release@dev
    inputs:
      gitlab_domain: "https://gitlab.prplanit.com"
      gitlab_token: "${GITLAB_TOKEN}"
      docker_release_path: "prplanit/gluetun-qbit-port-mgmt"

      freight_docker_url_1: "docker.io"
      freight_docker_user_1: "${DOCKER_HUB_USERNAME}"
      freight_docker_pass_1: "${DOCKER_HUB_PASSWORD}"
      freight_docker_path_1: "prplanit/gluetun-qbit-port-mgmt"
      freight_docker_registry_1: "docker"

      freight_docker_url_2: "..."
      freight_docker_user_2: "..."
      freight_docker_pass_2: "..."
      freight_docker_path_2: "..."
      freight_docker_registry_2: "..."

      freight_docker_url_3: "..."
      freight_docker_user_3: "..."
      freight_docker_pass_3: "..."
      freight_docker_path_3: "..."
      freight_docker_registry_3: "..."
    - project: 'components/stagefreight'
    file: '/export-dependencies.yml'
    ref: main

stages:
  - build
  - release
```

### Or use this Advanced Syntax to push to as many registries *as you want*.

```yaml
cache:
  key: "${CI_COMMIT_REF_SLUG}-${CI_PIPELINE_ID}"
  paths:
    - .cache/

include:
  - component: $CI_SERVER_FQDN/components/stagefreight/gl-docker-release@dev
    inputs:
      gitlab_domain: "https://gitlab.prplanit.com"
      gitlab_token: "${GITLAB_TOKEN}"
      docker_release_path: "prplanit/gluetun-qbit-port-mgmt"
  - project: 'components/stagefreight'
    file: '/export-dependencies.yml'
    ref: main

# Declare registries within a single YAML array variable
variables:
  freight_docker_override: |
    - url: quay.io
      user: "$QUAY_USER"
      pass: "$QUAY_PASS"
      path: "myuser/myapp:$CI_COMMIT_TAG"
      registry: quay
    - url: registry.gitlab.com
      user: "$CI_REGISTRY_USER"
      pass: "$CI_REGISTRY_PASSWORD"
      path: "$CI_PROJECT_PATH:$CI_COMMIT_TAG"
      registry: gitlab
    - url: ...
      user: ...
      pass: ...
      path: ...
      registry: ...
      ...
```

---

# Component Inputs

<!-- START_C_INPUTS_MAP -->
## `gl-component-release`

### GitLab CI/CD Inputs
Inputs that configure GitLab Job behavior
| Name | Required | Default | Description |
|------|----------|---------|-------------|
| branch_name | 🚫 | "main" | Branch to push badge/README changes to |
| gitlab_branch | 🚫 | "main" | Target Git branch for commits. |
| gitlab_domain | 🚫 | "https://gitlab.prplanit.com" | Base GitLab domain (used for badge & catalog links) |
| gitlab_job | 🚫 | "run-ansible" | The intended name of the CI job spawned by this component. |
| gitlab_stage | 🚫 | "ansible" | The intended name of the CI stage this job will run in. |
| gitlab_token | ✅ | "" | Token for authenticating GitLab API calls. |

### StageFreight Settings
Core settings used by StageFreight.
| Name | Required | Default | Description |
|------|----------|---------|-------------|
| badge_template | 🚫 | "assets/badge-release-generic.svg" | SVG template for badge generation |
| badge_output | 🚫 | "assets/badge-release-status.svg" | Final badge output path |
| component_spec_files | 🚫 | ["templates/gl-component-release.yml","templates/gl-docker-release.yml"] | Array of component spec files (for README input info) |
| readme_file | 🚫 | "README.md" | README file to inject Markdown input map into |


---

## `gl-docker-release`

### Docker Registry 1 Config
Note that you can configure more than 3 by overriding
| Name | Required | Default | Description |
|------|----------|---------|-------------|
| freight_pipeline_status_file | 🚫 | "assets/badge-release_status.svg" | Path to store "badge-release_status.svg" within parent pipelines repo. |
| freight_docker_url_1 | ✅ | "" | The registry endpoint to push the Docker image to (i.e. docker.io) |
| freight_docker_user_1 | ✅ | "" | The username used to authenticate with the registry. |
| freight_docker_pass_1 | ✅ | "" | The password or access token for authentication. |
| freight_docker_path_1 | ✅ | "" | The full image path to push (i.e. prplanit/stagefreight) |

### Docker Registry 2 Config
Below this section are examples to configure more registries
| Name | Required | Default | Description |
|------|----------|---------|-------------|
| freight_docker_registry_1 | ✅ | "" | A friendly name used in logs to identify this registry. |
| freight_docker_url_2 | ✅ | "" | The registry endpoint to push the Docker image to (i.e. docker.io) |
| freight_docker_user_2 | ✅ | "" | The username used to authenticate with the registry. |
| freight_docker_pass_2 | ✅ | "" | The password or access token for authentication. |
| freight_docker_path_2 | ✅ | "" | The full image path to push (i.e. prplanit/stagefreight) |

### Docker Registry 3 Config
Below this section are examples to configure more registries
| Name | Required | Default | Description |
|------|----------|---------|-------------|
| freight_docker_registry_2 | ✅ | "" | A friendly name used in logs to identify this registry. |
| freight_docker_url_3 | ✅ | "" | The registry endpoint to push the Docker image to (i.e. docker.io) |
| freight_docker_user_3 | ✅ | "" | The username used to authenticate with the registry. |
| freight_docker_pass_3 | ✅ | "" | The password or access token for authentication. |
| freight_docker_path_3 | ✅ | "" | The full image path to push (i.e. prplanit/stagefreight) |
| freight_docker_registry_3 | ✅ | "" | A friendly name used in logs to identify this registry. |

### GitLab Instance Config
These are necessary for upload tasks etc
| Name | Required | Default | Description |
|------|----------|---------|-------------|
| gitlab_domain | ✅ | "" | GitLab domain used to locate repository folders for uploads, etc. |

### Gitlab Release Linking only work with Docker for now
Configures embedding of the Docker Hub image into the release page
| Name | Required | Default | Description |
|------|----------|---------|-------------|
| gitlab_token | ✅ | "" | Token for authenticating GitLab API calls. |

### StageFreight Settings
Core settings used by StageFreight
| Name | Required | Default | Description |
|------|----------|---------|-------------|
| docker_release_path | ✅ | "" | Path/Name of the DockerHub Image to embed on the release page. |


---

<!-- END_C_INPUTS_MAP -->

## It Does Not Work? (Common Fixes)

- Are you calling the component from a protected branch/tag? If yes, you may want to make CI/CD variables protected too for security reasons.
- Are you passing protected variables to the component but the project calling it is not in a protected branch/tag? You will need to adjust for that, I recommend the solution above.
- Base64 encoding CI/CD variables is an ideal solution to make them oneliners if you want to make full use of GitLabs safeguards.

#### Runners can cache variable/files in a way that causes unintentional effects.

> It is possible to have keys/secrets or other files persist in the cache of the runner & locally. This can be confusing when you encounter it.

Two solutions for this caching issue:
1. There is a Gitlab -> Build -> Pipelines ->  Clear runner caches.
2. You can place code that makes the cache key change in the gitlab-ci.yml file on a root level block and it will force the cache to purge each run:
```
cache:
  key: "${CI_COMMIT_REF_SLUG}-${CI_PIPELINE_ID}"
  paths:
    - .cache/
```

---

# **Technical Details**

## gl-component-release
> This is the component module that handles releases for GitLab components, it even manages its own release cycle using this module.

### gl-component-release: Pipeline Jobs

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

### gl-component-release: Scripts

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

# How to Build Your Own Component for Use with StageFreight

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
