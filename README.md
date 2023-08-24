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

* Gzip text assets, requires:
  - `JEKYLL_ENV=production bundle exec jekyll build` to gzip these assets
  - Specically flagging only these files in S3 via `--content-encoding gzip`
* Use `--dryrun` to collect changed files for CloudFront invalidation
* Update project layout to ellipses... for long commits
