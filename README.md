# Add tags to Autoscaling Groups with Terraform

This module makes it easy to apply tag maps to an autoscaling group's instances with Terraform.

## Example Usage

```hcl
module "autoscaling_tags" {
	source 					= "github.com/webdevwilson/terraform-aws-autoscaling-tags?ref=v1.0"
	autoscaling_group_arn   = "${aws_autoscaling_group.main.arn}"
	tags 					= "${var.tags}"
}
```