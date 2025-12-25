output "frontend_ec2_id" {
  value = aws_instance.frontend.id
}

output "backend_ec2_id" {
  value = aws_instance.backend.id
}

output "db_ec2_id" {
  value = aws_instance.db.id
}

output "ansible_ec2_id" {
  value = aws_instance.ansible.id
}

output "ansible_public_ip" {
  value = aws_instance.ansible.public_ip
}

output "backend_private_ip" {
  value = aws_instance.backend.private_ip
}

output "s3_bucket_name" {
  value = aws_s3_bucket.uploads.bucket
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "sns_topic_arn" {
  value = aws_sns_topic.upload_topic.arn
}

output "db_private_ip" {
  value = aws_instance.db.private_ip
  
}
output "frontend_ec2_ip" {
  value = aws_instance.frontend.private_ip
}
