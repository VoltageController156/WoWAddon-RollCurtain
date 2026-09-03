# Roll Curtain Release Process

## Branches

- `main` is production. Stable GitHub releases are built from this branch.
- `beta` is the long-lived integration/testing branch. GitHub prereleases are built from this branch.
- `feature/*` and normal `hotfix/*` branches should target `beta`.
- Emergency production hotfixes may target `main`, but the same fix must then be reconciled back into `beta`.

## Versioning

`RollCurtain/RollCurtain.toc` stores the base version for the next stable release.

Example while preparing 0.0.7:

```text
## Version: 0.0.7
```

The release workflow derives beta versions automatically:

```text
0.0.7-beta.1
0.0.7-beta.2
0.0.7-beta.3
```

The beta version is stamped into the packaged TOC, so the in-game Settings footer shows the exact beta build. The source TOC on `beta` remains the base version (`0.0.7`).

## Development flow

1. Branch from `beta` using `feature/<name>` or `hotfix/<name>`.
2. Open a PR back to `beta`.
3. CI must pass Lua syntax checks and all `tests/test_*.lua` tests.
4. Merge to `beta`.
5. The workflow packages the add-on and publishes a GitHub prerelease such as `v0.0.7-beta.2`.
6. Test that exact ZIP in-game and, when desired, publish the same ZIP to CurseForge as Release Type `Beta`.
7. Repeat until the beta is approved.
8. Open a PR from `beta` to `main`.
9. Merge to `main` only after final approval.
10. The workflow publishes the stable GitHub release using the base TOC version, such as `v0.0.7`.
11. Publish that exact stable ZIP to CurseForge as Release Type `Release`.

## Release artifact policy

- Public ZIP files should come from GitHub Actions, not from manually assembled folders.
- The GitHub beta ZIP should be the same artifact submitted to CurseForge Beta.
- The GitHub stable ZIP should be the same artifact submitted to CurseForge Release.
- Published stable versions should normally remain immutable.

## Hotfix policy

For normal defects:

```text
hotfix/<name> -> beta -> main
```

For a production-critical defect that cannot wait for the normal beta cycle:

```text
main -> hotfix/<name> -> main
```

Afterward, reconcile the production fix back into `beta` before continuing feature development.
