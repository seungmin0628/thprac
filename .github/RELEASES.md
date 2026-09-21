# Release automation

The repository uses release-please to turn Conventional Commits on `master`
into release pull requests and GitHub releases.

## One-time setup

Install the release GitHub App on `seungmin0628/thprac`, and create these
repository Actions secrets:

- `RELEASE_PLEASE_GITHUB_APP_CLIENT_ID`: the GitHub App client ID
- `RELEASE_PLEASE_GITHUB_APP_PRIVATE_KEY`: the complete PEM private key,
  including its `BEGIN` and `END` lines

The App installation must be allowed to write repository contents, pull
requests, and issues. The workflow requests only those permissions when it
creates the installation token.

The App installation token is required because releases created with the
workflow's default `GITHUB_TOKEN` do not trigger another workflow. The release
build starts from the `release.published` event, so release-please creates the
release with a fresh GitHub App token generated inside the workflow.

## Flow

1. Merge Conventional Commit changes into `master`.
2. `Release Please` creates or updates a release pull request with the next
   version and changelog.
3. Merge the release pull request.
4. release-please creates the version tag and publishes the GitHub release.
5. `Release Build` checks out that exact tag, performs the Windows Release
   build, and attaches the application and symbol packages to the release.

The existing `v1.1` release is the baseline. The manifest represents it as
SemVer `1.1.0`; subsequent tags use full SemVer, such as `v1.1.1` or `v1.2.0`.
