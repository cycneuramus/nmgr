# Changelog

## [1.2.4](https://github.com/cycneuramus/nmgr/compare/v1.2.3...v1.2.4) (2026-03-30)


### Bug Fixes

* Don't break target groups by pre-filtering on job running state ([36fbf57](https://github.com/cycneuramus/nmgr/commit/36fbf576659e2c9249ab97dbff55859417cc890e))

## [1.2.3](https://github.com/cycneuramus/nmgr/compare/v1.2.2...v1.2.3) (2026-02-26)


### Bug Fixes

* Prevent reconcile false-positives due to unsorted image seqs ([7396090](https://github.com/cycneuramus/nmgr/commit/739609088d41883aaa7144bc09acf431b922a76d))

## [1.2.2](https://github.com/cycneuramus/nmgr/compare/v1.2.1...v1.2.2) (2026-02-26)


### Bug Fixes

* Add HTTP client timeout ([ce88566](https://github.com/cycneuramus/nmgr/commit/ce88566a265fa049878343c6ef38cd483ac14776))
* Raise error with HCL spec path, not content ([d79e151](https://github.com/cycneuramus/nmgr/commit/d79e1511e780c4208685ff0e16dd3db663bbb13e))
* Validate EDITOR env var and avoid shell execution ([aff630f](https://github.com/cycneuramus/nmgr/commit/aff630f35fd963be1186eedde25c26636eef89cb))


### Performance Improvements

* Compute config paths on-demand, not during job discovery ([763e2a3](https://github.com/cycneuramus/nmgr/commit/763e2a313f9ceaaa1780c95e03e04031f4c8a6f6))

## [1.2.1](https://github.com/cycneuramus/nmgr/compare/v1.2.0...v1.2.1) (2026-02-26)


### Bug Fixes

* Don't duplicate live images in output for jobs using same image in multiple tasks ([264fce1](https://github.com/cycneuramus/nmgr/commit/264fce19159613f23a112e39289bfdb653b208c3))
* Handle jobs of non-service type lacking container images ([fbf55eb](https://github.com/cycneuramus/nmgr/commit/fbf55eb0d94a1c073a796f86a7504ce49e99b8d8))


### Performance Improvements

* Replace redundant API calls with improved state storage ([7d1cca7](https://github.com/cycneuramus/nmgr/commit/7d1cca7c245a080ecfdb33b80b553461dad33a53))
* Use streaming iterator on filter matching instead of reading entire files ([73f925c](https://github.com/cycneuramus/nmgr/commit/73f925c5ee442bfa685cdb22518ce8b79a6da0dc))

## [1.2.0](https://github.com/cycneuramus/nmgr/compare/v1.1.0...v1.2.0) (2026-02-22)


### Features

* Add 'shell' action ([e266589](https://github.com/cycneuramus/nmgr/commit/e2665896f5bea43c9accabc910b605b1171b4301))
* Support multiple target jobs ([4ade629](https://github.com/cycneuramus/nmgr/commit/4ade629fbee1fb382e797884d0f26997ff81ef8d))


### Bug Fixes

* Use allocID instead of job name in exec-like actions to handle jobs with multiple allocations ([de2d363](https://github.com/cycneuramus/nmgr/commit/de2d3630d8a261e8456876ef793be32bd89651a1))

## [1.1.0](https://github.com/cycneuramus/nmgr/compare/v1.0.1...v1.1.0) (2026-02-21)


### Features

* Autocomplete down/logs/exec actions from actually running jobs ([489beff](https://github.com/cycneuramus/nmgr/commit/489beff840e2447b0087a9b746d0efca4dc672ea))
* Migrate from Nomad CLI to HTTP API for up, down, and image actions ([62eb12a](https://github.com/cycneuramus/nmgr/commit/62eb12abe641ffd328441ce9ec99c9625e27df5f))


### Bug Fixes

* Catch IOError in readSpec ([8de15b9](https://github.com/cycneuramus/nmgr/commit/8de15b9c229972b990712b8559f4bcdea0a76819))
* Correctly check ignoreDirs ([4330c0f](https://github.com/cycneuramus/nmgr/commit/4330c0fb78b89053a6fafad8ea5ed194c474b306))
* Handle errors and improve robustness ([8e935d3](https://github.com/cycneuramus/nmgr/commit/8e935d340945d9bd606eb49435fa09860fd8a7f4))
* Revert to Nomad CLI for job submission since API can't do local HCL2 function parsing ([bb27cb9](https://github.com/cycneuramus/nmgr/commit/bb27cb94b5a45abc53a37109833787c6b1a12a92))

## [1.0.1](https://github.com/cycneuramus/nmgr/compare/v1.0.0...v1.0.1) (2025-10-14)


### Bug Fixes

* Properly support -d flag on 'down' ([7f9e748](https://github.com/cycneuramus/nmgr/commit/7f9e748b8a4d1b9d29a6bc82f85d989a9d6e8bab))

## [1.0.0](https://github.com/cycneuramus/nmgr/compare/v0.3.1...v1.0.0) (2025-04-21)


### ⚠ BREAKING CHANGES

* Complete rewrite in Nim

### Features

* Add 'edit' action ([c92ad86](https://github.com/cycneuramus/nmgr/commit/c92ad86078263dc912325bfc45953e551183a637))
* Complete rewrite in Nim ([c92ad86](https://github.com/cycneuramus/nmgr/commit/c92ad86078263dc912325bfc45953e551183a637))


### Bug Fixes

* Explicitly depend on 'nomad' executable ([c92ad86](https://github.com/cycneuramus/nmgr/commit/c92ad86078263dc912325bfc45953e551183a637))


### Performance Improvements

* Forego regex matching and parse HCL directly ([c92ad86](https://github.com/cycneuramus/nmgr/commit/c92ad86078263dc912325bfc45953e551183a637))
* Ingest default config and completion script at compile-time ([c92ad86](https://github.com/cycneuramus/nmgr/commit/c92ad86078263dc912325bfc45953e551183a637))
* Populate 'action' and 'target' registries at compile-time ([c92ad86](https://github.com/cycneuramus/nmgr/commit/c92ad86078263dc912325bfc45953e551183a637))

## [0.3.1](https://github.com/cycneuramus/nmgr/compare/v0.3.0...v0.3.1) (2025-03-15)


### Bug Fixes

* Exit after installing completion ([73277d6](https://github.com/cycneuramus/nmgr/commit/73277d6b5e2943d7a0b23315c142e2c7f12f7d81))


### Documentation

* Update README ([e41dde1](https://github.com/cycneuramus/nmgr/commit/e41dde102f1a39c5f9cf8cc3e6c619187ac7e3c6))

## [0.3.0](https://github.com/cycneuramus/nmgr/compare/v0.2.0...v0.3.0) (2025-03-04)


### Features

* Add exec command ([c27d9f3](https://github.com/cycneuramus/nmgr/commit/c27d9f36e1e7b93e485e125b55d075e421fbb21b))
* Up command updates job if spec changed ([a24de7b](https://github.com/cycneuramus/nmgr/commit/a24de7bafb1c584d9e147273a6227063a3174958))


### Documentation

* Add some docstrings and tweak comments ([a8ff487](https://github.com/cycneuramus/nmgr/commit/a8ff4870237dfa0f97b9c7181d349eb68e6c5f0d))
* Clarify custom filter matching ([acd6275](https://github.com/cycneuramus/nmgr/commit/acd6275aaeb76f6830501c5ba94b06da888a5351))
* Update README ([538e0d6](https://github.com/cycneuramus/nmgr/commit/538e0d63bdbb024a30a35a98310b74b14df282c1))

## [0.2.0](https://github.com/cycneuramus/nmgr/compare/v0.1.1...v0.2.0) (2025-02-19)


### Features

* Add --purge option to 'down' action ([c61a08a](https://github.com/cycneuramus/nmgr/commit/c61a08a57e48f31dde597d4b745aa56761b0b840))
* Add --version flag ([4f970c5](https://github.com/cycneuramus/nmgr/commit/4f970c5df2658daedf93e82de63960d77cd7f7a6))
* Include custom targets in completion ([c63658d](https://github.com/cycneuramus/nmgr/commit/c63658d66a56277ff9b29b240f4d5ded2a8112f5))


### Bug Fixes

* Support *.nomad job specs ([f14c782](https://github.com/cycneuramus/nmgr/commit/f14c78291d005a198c91ad50a40892aa8cf4c384))

## [0.1.1](https://github.com/cycneuramus/nmgr/compare/v0.1.0...v0.1.1) (2025-02-18)


### Performance Improvements

* Use generator instead of reading config files to memory ([70ed81d](https://github.com/cycneuramus/nmgr/commit/70ed81d73bc4e2a7c1b4859a60918a18e8e86d08))
