# 0006: AWS managed policies for the cluster and node roles

Everywhere else I avoid managed policies, so this one needs a note.

The cluster role has `AmazonEKSClusterPolicy`. The node role has
`AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryPullOnly` and
`AmazonEKS_CNI_Policy`. These are the ones EKS documents and AWS keeps them up
to date when EKS needs something new; a hand-written copy would drift and fail
in ways that are hard to trace back to IAM. I'd rather spend the least-privilege
effort on the app roles, where the policy is actually ours.

`PullOnly` instead of `ReadOnly` because nodes only pull images.

Known gap: with the CNI policy on the node role, any pod on the node could use
it through instance metadata. On a real cluster it goes to the `aws-node`
service account with Pod Identity.
