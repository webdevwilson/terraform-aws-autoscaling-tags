variable autoscaling_group_arn {
  description = "The ARN of the autoscaling group"
}

variable tags {
  description = "The tags that will be applied to the instances"
  type        = "map"
}