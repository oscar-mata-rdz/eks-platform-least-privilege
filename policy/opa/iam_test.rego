package main

import rego.v1

doc(statements) := {"data": {"aws_iam_policy_document": {"app": [{"statement": statements}]}}}

test_scoped_policy_passes if {
	count(deny) == 0 with input as doc([{
		"actions": ["s3:GetObject", "s3:PutObject"],
		"resources": ["${aws_s3_bucket.this.arn}/*"],
	}])
}

test_service_wildcard_denied if {
	count(deny) > 0 with input as doc([{"actions": ["s3:*"], "resources": ["${aws_s3_bucket.this.arn}/*"]}])
}

test_partial_wildcard_denied if {
	count(deny) > 0 with input as doc([{"actions": ["s3:Get*"], "resources": ["${aws_s3_bucket.this.arn}/*"]}])
}

test_resource_star_denied if {
	count(deny) > 0 with input as doc([{"actions": ["s3:GetObject"], "resources": ["*"]}])
}

test_all_buckets_arn_denied if {
	count(deny) > 0 with input as doc([{"actions": ["s3:GetObject"], "resources": ["arn:aws:s3:::*"]}])
}

test_resource_star_allowed_for_non_scopable_action if {
	count(deny) == 0 with input as doc([{"actions": ["sts:GetCallerIdentity"], "resources": ["*"]}])
}

test_deny_statements_are_ignored if {
	count(deny) == 0 with input as doc([{
		"effect": "Deny",
		"actions": ["s3:*"],
		"resources": ["*"],
		"principals": [{"type": "*", "identifiers": ["*"]}],
	}])
}

test_dynamic_statements_are_checked if {
	count(deny) > 0 with input as {"data": {"aws_iam_policy_document": {"app": [{"dynamic": {"statement": [{
		"for_each": "${local.can_write ? [1] : []}",
		"content": [{"actions": ["s3:*"], "resources": ["*"]}],
	}]}}]}}}
}

test_not_actions_denied if {
	count(deny) > 0 with input as doc([{"not_actions": ["iam:*"], "resources": ["*"]}])
}

test_pod_identity_without_namespace_pin_denied if {
	count(deny) > 0 with input as doc([{
		"actions": ["sts:AssumeRole", "sts:TagSession"],
		"principals": [{"type": "Service", "identifiers": ["pods.eks.amazonaws.com"]}],
		"condition": [{"test": "StringEquals", "variable": "aws:RequestTag/eks-cluster-arn", "values": ["${var.cluster_arn}"]}],
	}])
}

test_pod_identity_fully_pinned_passes if {
	count(deny) == 0 with input as doc([{
		"actions": ["sts:AssumeRole", "sts:TagSession"],
		"principals": [{"type": "Service", "identifiers": ["pods.eks.amazonaws.com"]}],
		"condition": [
			{"test": "StringEquals", "variable": "aws:RequestTag/eks-cluster-arn", "values": ["${var.cluster_arn}"]},
			{"test": "StringEquals", "variable": "aws:RequestTag/kubernetes-namespace", "values": ["payments"]},
			{"test": "StringEquals", "variable": "aws:RequestTag/kubernetes-service-account", "values": ["payments-service"]},
		],
	}])
}

test_jsonencode_policy_denied if {
	count(deny) > 0 with input as {"resource": {"aws_iam_policy": {"app": [{"policy": "${jsonencode({Statement = []})}"}]}}}
}

test_policy_document_reference_passes if {
	count(deny) == 0 with input as {"resource": {"aws_iam_policy": {"app": [{"policy": "${data.aws_iam_policy_document.app.json}"}]}}}
}

test_full_access_attachment_denied if {
	count(deny) > 0 with input as {"resource": {"aws_iam_role_policy_attachment": {"app": [{
		"role": "${aws_iam_role.this.name}",
		"policy_arn": "arn:aws:iam::aws:policy/AmazonS3FullAccess",
	}]}}}
}

test_passrole_warns if {
	count(warn) > 0 with input as doc([{"actions": ["iam:PassRole"], "resources": ["${aws_iam_role.worker.arn}"]}])
}
