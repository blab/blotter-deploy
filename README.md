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
* Use `--dryrun` to collect changed files for CloudFront invalidation
* Update `/projects` to specify projects that should only have README.md copied over and other projects that should have full directory structure copied over
