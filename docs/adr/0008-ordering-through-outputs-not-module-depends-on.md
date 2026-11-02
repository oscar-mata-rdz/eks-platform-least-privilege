# 0008: Ordering through outputs, not module depends_on

Status: accepted

The apps (namespace, pod identity association) need a cluster with nodes and
the pod identity add-on first. My first version had `depends_on = [module.eks]`
on the apps module, and the plan showed the bucket name and the whole IAM policy
as "known after apply": a module-level `depends_on` delays every data source in
the module until apply. Bad trade when the plan is where you review the policy.

So the eks module's `cluster_name` output depends on the node groups and the
add-on, and the apps module takes `cluster_name` as input. Same ordering,
readable plan.

If something new in `app-workload` has to wait for the cluster, it needs to use
`var.cluster_name`.
