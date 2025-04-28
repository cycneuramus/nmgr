# Changelog

## [2.0.0](https://github.com/cycneuramus/nmgr/compare/v1.0.0...v2.0.0) (2025-04-28)


### ⚠ BREAKING CHANGES

* Complete rewrite in Nim

### Features

* Add --purge option to 'down' action ([c61a08a](https://github.com/cycneuramus/nmgr/commit/c61a08a57e48f31dde597d4b745aa56761b0b840))
* Add --version flag ([4f970c5](https://github.com/cycneuramus/nmgr/commit/4f970c5df2658daedf93e82de63960d77cd7f7a6))
* Add 'edit' action ([c92ad86](https://github.com/cycneuramus/nmgr/commit/c92ad86078263dc912325bfc45953e551183a637))
* Add exec command ([c27d9f3](https://github.com/cycneuramus/nmgr/commit/c27d9f36e1e7b93e485e125b55d075e421fbb21b))
* Complete rewrite in Nim ([c92ad86](https://github.com/cycneuramus/nmgr/commit/c92ad86078263dc912325bfc45953e551183a637))
* Include custom targets in completion ([c63658d](https://github.com/cycneuramus/nmgr/commit/c63658d66a56277ff9b29b240f4d5ded2a8112f5))
* Up command updates job if spec changed ([a24de7b](https://github.com/cycneuramus/nmgr/commit/a24de7bafb1c584d9e147273a6227063a3174958))


### Bug Fixes

* Exit after installing completion ([73277d6](https://github.com/cycneuramus/nmgr/commit/73277d6b5e2943d7a0b23315c142e2c7f12f7d81))
* Explicitly depend on 'nomad' executable ([c92ad86](https://github.com/cycneuramus/nmgr/commit/c92ad86078263dc912325bfc45953e551183a637))
* Support *.nomad job specs ([f14c782](https://github.com/cycneuramus/nmgr/commit/f14c78291d005a198c91ad50a40892aa8cf4c384))


### Performance Improvements

* Forego regex matching and parse HCL directly ([c92ad86](https://github.com/cycneuramus/nmgr/commit/c92ad86078263dc912325bfc45953e551183a637))
* Ingest default config and completion script at compile-time ([c92ad86](https://github.com/cycneuramus/nmgr/commit/c92ad86078263dc912325bfc45953e551183a637))
* Populate 'action' and 'target' registries at compile-time ([c92ad86](https://github.com/cycneuramus/nmgr/commit/c92ad86078263dc912325bfc45953e551183a637))
* Use generator instead of reading config files to memory ([70ed81d](https://github.com/cycneuramus/nmgr/commit/70ed81d73bc4e2a7c1b4859a60918a18e8e86d08))

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
