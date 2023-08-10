This script is used to build and deploy the Bedford lab website. It

* Clones the [blotter](https://github.com/blab/blotter) repo
* Clones all project repos specified in blotter's [`_config.yml`](https://github.com/blab/blotter/blob/master/_config.yml)
* Preprocesses Markdown
* Builds site with Jekyll
* Pushes site to S3 `aws s3`
* Creates CloudFront invalidation with `aws cloudfront`

# Install

Install with:
```
brew install awscli
bundle install
```

# Todo

* Restore gzipping on S3 upload
  * This can be done with `JEKYLL_ENV=production bundle exec jekyll build`, but currently encountering an error when trying to compress an already gzipped file
  * Will wait to activate until `/projects` have been updated to not copy over excess material
* Use `--dryrun` to collect changed files for CloudFront invalidation
* Update `/projects` to specify projects that should only have README.md copied over and other projects that should have full directory structure copied over
