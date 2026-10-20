# Native release artifact validation

The manual `release.yml` workflow builds each release row from the version job's
revision, runs the installed workload on that row, and uploads its platform gem
only after acceptance passes. Verification checks the downloaded set before the
credential-bearing publish job runs. Dry runs stop before publication.

`script/verify_release_artifacts` requires exactly one source gem and one gem per
requested platform, at the requested version. It rejects duplicate rows,
unexpected rows and noncanonical filenames. Platform packages must bind their
platform, version and revision in `provenance.json`; their target must match the
release matrix mapping, and `platforms.json` must declare the requested ABI.
The recorded Cargo.lock hash and FFI crate version must match the verifier's
checkout, which the workflow pins to the release revision. Both recorded
library hashes must match the packaged library. A nonempty output directory is
rejected so an older gem cannot survive into the verified set.
Successful verification writes canonical gem filenames and SHA256SUMS into the
empty output directory.

For example, using the release job's actual revision and version:

```sh
script/verify_release_artifacts --directory candidates --revision "$RELEASE_SHA" \
  --version "$RELEASE_VERSION" --platforms "$PLATFORMS" --abi-version 1 --output verified
```

`script/publish_release_gems --directory verified` checks the entire checksum
inventory and every gem's hash before the first push. Missing, extra or duplicate
entries, malformed names and changed bytes fail before publication. The workflow
also checks SHA256SUMS independently before configuring trusted-publisher
credentials. On retries, an already-published version is accepted only after
fetching that gem and comparing its bytes with the local verified gem. Other
publication failures stop the remaining pushes and report what already succeeded.

The trusted-publisher identity remains owner `claricle`, repository `emf`,
workflow `release.yml`, with no environment. Publication is manual, uses OIDC and
requires `dry_run: false`. Local focused tests substitute the gem command and
never publish to RubyGems.

These checks validate recorded metadata and byte integrity; they are not build
attestations. The source gem has no revision provenance, so its revision is
established by the workflow's checkout/build chain, not by inspecting the gem.
The verifier cannot independently prove that native bytes were compiled from the
recorded revision, that a package contains machine code for its declared target,
or that the installed workload ran. Those properties depend on the row build and
acceptance jobs. SHA256SUMS is an integrity inventory carried by the workflow artifact, not an authenticated signature.
Unexecuted platform rows remain unverified; local temporary-package regressions
do not establish platform support.

Focused local checks need Ruby and the bundle, but no Rust compiler or native
library:

```sh
EMF_BACKEND=ruby bundle exec rspec spec/scripts/verify_release_artifacts_spec.rb \
  spec/scripts/publish_release_gems_spec.rb
bundle exec rubocop --cache false script/verify_release_artifacts script/publish_release_gems \
  spec/scripts/verify_release_artifacts_spec.rb spec/scripts/publish_release_gems_spec.rb
```
