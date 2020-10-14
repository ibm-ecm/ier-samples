# Uninstalling IBM Enterprise Records ga-5.2.1.4 on Certified Kubernetes

## Delete the operator

To uninstall the deployments and the Enterprise records operator, use the 'deleteOperator.sh' command to delete all the resources that are linked to the operator.

```bash
   ./scripts/deleteOperator.sh
```

Verify that all pods created with the deployment are terminated and deleted.

## Delete deployments

If you want to delete the custom resource deployment, you can delete the corresponding YAML file.

For example:
```bash
  $ kubectl delete -f descriptors/my_ier_v1_ier_cr.yaml
```

To uninstall an instance of the operator, you must delete all of the manifest files in the cluster:

```bash
  $ kubectl delete -f descriptors/operator.yaml
  $ kubectl delete -f descriptors/role_binding.yaml
  $ kubectl delete -f descriptors/role.yaml
  $ kubectl delete -f descriptors/service_account.yaml
  $ kubectl delete -f descriptors/ibm_cp4a_crd.yaml
```


