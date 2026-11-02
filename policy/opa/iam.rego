package main

import rego.v1

resource_star_ok := {
	"sts:GetCallerIdentity",
	"ec2:DescribeAvailabilityZones",
}

escalation_actions := {
	"iam:passrole",
	"iam:createpolicyversion",
	"iam:setdefaultpolicyversion",
	"iam:attachrolepolicy",
	"iam:putrolepolicy",
	"iam:updateassumerolepolicy",
	"iam:createaccesskey",
	"iam:createrole",
	"sts:assumerole",
	"eks:createpodidentityassociation",
	"eks:updatepodidentityassociation",
}

statements contains {"doc": name, "st": st} if {
	some name, docs in input.data.aws_iam_policy_document
	some doc in docs
	some st in doc.statement
}

statements contains {"doc": name, "st": st} if {
	some name, docs in input.data.aws_iam_policy_document
	some doc in docs
	some dyn in doc.dynamic.statement
	some st in dyn.content
}

allows(st) if not st.effect

allows(st) if st.effect == "Allow"

label(s) := sprintf("%s.%s", [s.doc, object.get(s.st, "sid", "<no sid>")])

wide_resource(r) if r == "*"

wide_resource(r) if regex.match(`^arn:[^:]*:[^:]*:[^:]*:[^:]*:\*$`, r)

has_condition(st, key) if {
	some c in st.condition
	c.variable == key
}

trusts_service(st, service) if {
	some p in st.principals
	p.type == "Service"
	service in p.identifiers
}

deny contains msg if {
	some s in statements
	allows(s.st)
	some action in s.st.actions
	contains(action, "*")
	msg := sprintf("%s: wildcard action %q.", [label(s), action])
}

deny contains msg if {
	some s in statements
	allows(s.st)
	some r in s.st.resources
	wide_resource(r)
	some action in s.st.actions
	not action in resource_star_ok
	msg := sprintf("%s: %q on %q, use a specific ARN.", [label(s), action, r])
}

deny contains msg if {
	some s in statements
	allows(s.st)
	some field in ["not_actions", "not_resources"]
	s.st[field]
	msg := sprintf("%s: %s not allowed in Allow.", [label(s), field])
}

deny contains msg if {
	some s in statements
	allows(s.st)
	some p in s.st.principals
	"*" in p.identifiers
	msg := sprintf("%s: principal \"*\" not allowed.", [label(s)])
}

deny contains msg if {
	some s in statements
	allows(s.st)
	trusts_service(s.st, "pods.eks.amazonaws.com")
	some key in [
		"aws:RequestTag/eks-cluster-arn",
		"aws:RequestTag/kubernetes-namespace",
		"aws:RequestTag/kubernetes-service-account",
	]
	not has_condition(s.st, key)
	msg := sprintf("%s: trust policy must pin %s.", [label(s), key])
}

policy_attributes := {
	"aws_iam_policy": "policy",
	"aws_iam_role_policy": "policy",
	"aws_iam_user_policy": "policy",
	"aws_iam_group_policy": "policy",
	"aws_iam_role": "assume_role_policy",
	"aws_s3_bucket_policy": "policy",
}

deny contains msg if {
	some rtype, attr in policy_attributes
	some name, blocks in input.resource[rtype]
	some r in blocks
	value := r[attr]
	not regex.match(`^\$\{data\.aws_iam_policy_document\.[A-Za-z0-9_-]+\.json\}$`, value)
	msg := sprintf("%s.%s: %s must use aws_iam_policy_document.", [rtype, name, attr])
}

deny contains msg if {
	some rtype in [
		"aws_iam_role_policy_attachment",
		"aws_iam_policy_attachment",
		"aws_iam_user_policy_attachment",
		"aws_iam_group_policy_attachment",
	]
	some name, blocks in input.resource[rtype]
	some r in blocks
	regex.match(`:policy/(AdministratorAccess|PowerUserAccess|[A-Za-z0-9]*FullAccess)$`, r.policy_arn)
	msg := sprintf("%s.%s: %s not allowed.", [rtype, name, r.policy_arn])
}

warn contains msg if {
	some s in statements
	allows(s.st)
	not s.st.principals
	some action in s.st.actions
	lower(action) in escalation_actions
	msg := sprintf("%s: %q can escalate privileges, needs a second review.", [label(s), action])
}
