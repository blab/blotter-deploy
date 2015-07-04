This script is used to build and deploy the Bedford lab website. It

* Clones the [blotter](https://github.com/blab/blotter) repo
* Clones all project repos specified in blotter's [`_config.yml`](https://github.com/blab/blotter/blob/master/_config.yml)
* Preprocesses Markdown
* Builds site with Jekyll
* Pushes site to S3 with s3_website.
