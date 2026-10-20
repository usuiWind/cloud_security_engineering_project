resource "aws_s3_bucket" "public_test" {
  bucket = "meridian-public-test-622896097641"
}

resource "aws_s3_bucket_public_access_block" "public_test" {
  bucket                  = aws_s3_bucket.public_test.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
