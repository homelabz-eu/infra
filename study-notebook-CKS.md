# Cluster Setup and Hardening

## CIS Benchmarks
```
sh /root/Assessor/Assessor-CLI.sh -i -rd /var/www/html/ -nts -rp index
```

## kube-bench
```
kube-bench run --targets="master,node,controlplane,etcd,policies"
```

## Authentication

### Static Token File (not recommended)

To use this method we need to mount the file on apiserver pod and pass the flag `--basic-auth-file=`.

ie: user-token-details.csv
```
oi43h6o43h6o34h,user1,u0010,group1
```

When using it, token should be passed as bearer token on request header:
```
curl -v -k https://master-node:6443/api/v1/pods --header "Authorization: Bearer oi43h6o43h6o34h"
```

### Service Accounts

## Authorization
