# 0009: Network layout

Status: accepted

| | Choice | Why |
|---|---|---|
| Private subnets | /19 per AZ | The VPC CNI gives every pod a VPC IP; ~8k addresses each |
| Public subnets | /24 per AZ | Only NAT gateways and load balancers |
| NAT | per AZ in us-east-1, one in us-west-2 | One NAT is fine for standby, not for the primary |
| Default SG | managed, no rules | Nothing gets traffic by accident |
| Subnet tags | `kubernetes.io/role/elb`, `internal-elb` | So the LB controller finds them |

VPCs need to be /16 or bigger (validated) and use different ranges per region
so they can be peered later. If us-west-2 ever takes real traffic, set
`single_nat_gateway = false`.
