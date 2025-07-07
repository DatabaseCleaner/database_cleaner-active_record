# Guidelines for contributing

## 1. Fork & Clone

Since you probably don't have rights to the main repo, you should Fork it (big
button up top). After that, clone your fork locally and optionally add an
upstream:

    git remote add upstream git@github.com:DatabaseCleaner/database_cleaner-active_record.git

## 2. Make sure the tests run fine

The gem uses Appraisal to configure different Gemfiles to test different Rails versions.

- You can run all the databases through docker if needed with `docker compose up` (you can also have them running on your system, just comment out the ones you don't need from the `docker-compose.yml` file)
- Copy `spec/support/sample.config.yml` to `spec/support/config.yml` and edit it
- `BUNDLE_GEMFILE=gemfiles/rails_6.1.gemfile bundle install` (change `6.1` with any version from the `gemfiles` directory)
- `BUNDLE_GEMFILE=gemfiles/rails_6.1.gemfile bundle exec rake`

Note that if you don't have all the supported databases installed and running,
some tests will fail.

> Note that you can check the `.github/workflows/ci.yml` file for different combinations of Ruby and Rails that are expected to work

## 3. Prepare your contribution

This is all up to you but a few points should be kept in mind:

- Please write tests for your contribution
- Make sure that previous tests still pass
- Push it to a branch of your fork
- Submit a pull request
