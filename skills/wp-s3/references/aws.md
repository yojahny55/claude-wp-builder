# S3 on AWS: the infrastructure side

What has to exist before `/wp-s3` is run against a production site. Everything here is
configured once per site and environment, by whoever owns the AWS account.

The shape:

```
 Visitor ──HTTPS──▶ CloudFront (media.<domain>) ──OAC──▶ S3 <bucket>
                                                            ▲
 WordPress ───────── IAM role ── PutObject / GetObject / DeleteObject ┘
```

## Per site and environment

| Item | Format | Notes |
|---|---|---|
| Site | `<site>` | Short identifier, no spaces |
| Environment | `prod` / `staging` | Its own resources. Never shared with production |
| Region | `<region>` | The server's region, for latency and egress cost |
| Bucket | `<org>-wp-media-<site>-<env>` | Globally unique, and permanent: renaming means migrating |
| Media domain | `media.<domain>` | Staging gets its own |
| Site domain | `https://www.<domain>` | For the CORS header |
| IAM role | `wp-media-<site>-<env>` | One per site and environment |

**One bucket per site and environment.** It isolates permissions, billing, lifecycle and the
blast radius of any mistake. Sharing one bucket with a prefix per site works — it was
measured working — but it complicates both the bucket policy and the CloudFront
configuration and buys nothing. A shared bucket also means a deletion in staging deletes
production's media.

## Bucket

| Setting | Value |
|---|---|
| Block Public Access | **On**, all four |
| Object Ownership | Bucket owner enforced (ACLs off), the default |
| Encryption | SSE-S3 |
| Versioning | **On** |
| Tags | `site=<site>`, `env=<env>`, `app=wordpress-media` |

A lifecycle rule is mandatory once versioning is on: WordPress rewrites thumbnails and an
optimizer plugin generates `.webp` beside every file, so old versions accumulate and bill.

```json
{
  "Rules": [
    {
      "ID": "expire-old-versions",
      "Status": "Enabled",
      "Filter": {},
      "NoncurrentVersionExpiration": { "NoncurrentDays": 30 },
      "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 },
      "Expiration": { "ExpiredObjectDeleteMarker": true }
    }
  ]
}
```

Thirty days is the window to recover a file deleted by mistake. Match it to the backup
policy — and note that once the media leave the disk, **the server's backups no longer
contain them**. Versioning is the protection now.

## Certificate and DNS

1. An ACM certificate for `media.<domain>` **in `us-east-1`**, wherever the bucket lives —
   that is where CloudFront requires it.
2. After the distribution exists: `CNAME` (or `ALIAS`) from `media.<domain>` to the
   distribution's domain.

## CloudFront

Origin: the bucket's REST endpoint, not its website endpoint. Access through **Origin Access
Control**, signing always. Empty origin path.

Default behaviour: redirect HTTP to HTTPS, `GET, HEAD` (plus `OPTIONS` with CORS
preflight), compression on.

**Cache policy: include the query string in the cache key**, at minimum `ver`. Elementor
regenerates its CSS under the same filename and changes only `?ver=`; a distribution that
ignores the query string keeps serving the old stylesheet. Long default TTL — a day is
reasonable, a year is the maximum. No headers or cookies in the key.

**Response headers policy (CORS).** Required: Elementor's CSS and any uploaded font are
requested from the site's domain against `media.<domain>`.

| Header | Value |
|---|---|
| `Access-Control-Allow-Origin` | `https://www.<domain>` |
| `Access-Control-Allow-Methods` | `GET, HEAD, OPTIONS` |
| `Access-Control-Allow-Headers` | `*` |
| `Access-Control-Max-Age` | `86400` |
| Origin override | On |

Invalidations are rarely needed: editing an image produces a new filename. Only a file
replaced under its own name needs one.

## Bucket policy

Only that site's distribution may read, and **only the public paths**.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudFrontReadsPublicMediaOnly",
      "Effect": "Allow",
      "Principal": { "Service": "cloudfront.amazonaws.com" },
      "Action": "s3:GetObject",
      "Resource": [
        "arn:aws:s3:::<bucket>/uploads/20*",
        "arn:aws:s3:::<bucket>/uploads/woocommerce-placeholder*",
        "arn:aws:s3:::<bucket>/uploads/elementor/*"
      ],
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::<account>:distribution/<distribution-id>"
        }
      }
    }
  ]
}
```

`uploads/20*` covers the year folders. **Never** add these:

| Path | Contents |
|---|---|
| `uploads/wc-logs/` | WooCommerce logs |
| `uploads/woocommerce_uploads/` | Files behind downloadable products |
| `uploads/wpcf7_uploads/` | Form attachments |
| `uploads/wrio/`, `uploads/wio_backup/` | Image optimizer logs and untouched originals |

A plugin that uploads to a public path of its own has to be added here deliberately, one
path at a time.

## IAM role for the server

On the EC2 instance profile or the ECS task role. **Lightsail does not support instance
roles**: there, create an IAM user with the same policy and hand the key pair over a secure
channel, then configure the site with `--auth key`.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Bucket",
      "Effect": "Allow",
      "Action": ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"],
      "Resource": "arn:aws:s3:::<bucket>"
    },
    {
      "Sid": "Objects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject", "s3:PutObject", "s3:PutObjectAcl", "s3:DeleteObject",
        "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"
      ],
      "Resource": "arn:aws:s3:::<bucket>/*"
    }
  ]
}
```

- `s3:DeleteObject` is required: deleting an image in WordPress deletes the original and
  every thumbnail.
- `s3:PutObjectAcl` is in the policy the plugin generates for itself, because it sends an
  ACL on every upload.
- With SSE-KMS instead of SSE-S3, add `kms:GenerateDataKey` and `kms:Decrypt` on the key.

## Networking

The server needs outbound HTTPS to `s3.<region>.amazonaws.com`. In a private subnet behind
NAT, create a **VPC Gateway Endpoint for S3**: it is free and it keeps every upload and read
off the NAT bill.

## Monitoring

CloudWatch alarms on the distribution's `5xx` and `4xx` rates. A rise in `403` usually means
a public path missing from the bucket policy. Optionally, CloudFront access logs and
CloudTrail data events on the bucket.

## Hand over to whoever configures WordPress

| Item | Value |
|---|---|
| Bucket name | |
| Region | |
| Media domain, with `https://` | |
| Role attached to the server | yes / no — if no, the key pair, over a secure channel |
| Distribution ID | for the occasional invalidation |
