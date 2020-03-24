# Kubernetes KMS Plugin Provider for HashiCorp Vault

Kubernetes 1.10 ([PR 55684](https://github.com/kubernetes/kubernetes/pull/55684), [Docs](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/)) added the ability to:
* Abstract the encryption provider from the Kubernetes API server
* Manage the encryption external to the Kubernetes cluster in a remote KMS

This Kubernetes KMS Plugin Provider for HashiCorp Vault extends the previous functionality and enables an end state setup as shown in the following diagram.

![Secrets with HashiCorp Vault](vault/docs/vaultplugin.png)

# About the Kubernetes KMS plugin provider for HashiCorp Vault
The Kubernetes KMS Plugin Provider for HashiCorp Vault implementation is a simple adapter that adapts calls from Kubernetes to HashiCorp Vault APIs using configuration that determines how the plugin finds the HashiCorp Vault installation.
The plugin is implemented based on the Kubernetes contract as described in [Implementing a KMS plugin](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/#implementing-a-kms-plugin).

# Getting Started
Before building the KMS plugin provider for HashiCorp Vault, it is highly recommended that you read and understand [Encrypting Secret Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/) and [Using a KMS provider for data encryption](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/) to understand how Kubernetes encrypts secrets at rest.

# Requirements
The Kubernetes KMS Plugin Provider for HashiCorp Vault has the following requirements:
* Kubernetes 1.10 or later
* [Go](https://golang.org/) 1.9 or later

# Enable Kubernetes authentication for Vault
Follow step 1 and 2 from the Hashicorp's official Vault Agent [documentation](https://learn.hashicorp.com/vault/identity-access-management/vault-agent-k8s#step-1-create-a-service-account). 
Note: Only thing to change from the setup provided in the above link is to create the service account and bindings in kube-system namespace instead of default.


# Starting the KMS plugin provider for HashiCorp Vault inside your cluster
Note: The KMS Plugin Provider for HashiCorp Vault must be running before starting the Kubernetes API server.

To start the plugin provider:
1. Create/Modify a `vault-values.yaml` configuration file as shown in the following sample, using values appropriate for your configuration.
```yaml
keyNames:
  - my-key
transitPath: /transit
ca-cert: /home/me/ca.cert
addr: https://example.com:8200
```

2. Run the following command to start the plugin.
```
docker build . -t user-name/vault-kms-plugin:tag_name
```

3. Push the image created to docker hub
```
docker push user-name/vault-kms-plugin:tag_name
```

4. Create the config map in kube-system name space
```
kubectl create configmap example-vault-agent-config --from-file=./configs-k8s/ -n kube-system
```

5. Update the pod.yaml with image name available on docker hub and create the pod in kube-system namespace, ensure that the socket file created is accessible by kube-api-server
```
kubectl apply --filename pod.yaml -n kube-system
```

# Configuring the Kubernetes cluster for the KMS Plugin Provider for HashiCorp Vault

To configure the KMS plugin provider for Vault on the Kubernetes API server, edit the `encryption-config.yaml` configuration file on the server as follows:
1. Include a provider of type `kms` in the providers array.
2. Specify `vault` as the name of the plugin provider.
3. Set the following properties as appropriate for your configuration:
 * `endpoint`: Listen address of the gRPC server (KMS plugin). The endpoint is a UNIX domain socket.
 * `cachesize`: Number of data encryption keys (DEKs) to be cached in the clear.

 ```yaml
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
    - secrets
    providers:
    - kms:
        name: vault
        endpoint: unix:///tmp/kms/socketfile.sock
        cachesize: 100
    - identity: {}  
```

4. If you use Rancher configuration goes as below, modify cluster.yaml
```
kube-api:
      always_pull_images: false
      extra_binds:
        - '/var/run/kmsplugin/:/var/run/kmsplugin/'
      pod_security_policy: false
      secrets_encryption_config:
        enabled: true
        custom_config:
          apiVersion: apiserver.config.k8s.io/v1
          kind: EncryptionConfiguration
          resources:
          - resources:
            - secrets
            providers:
            - kms:
                name: aws-encryption-provider
                endpoint: unix:///var/run/kmsplugin/socket.sock
                cachesize: 1000
                timeout: 3s
            - identity: {}
      service_node_port_range: 30000-32767
```

See [Configuring the KMS provider](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/#configuring-the-kms-provider).

# Verifying the configuration
If you can access the etcd node or etcd using etcdctl then try following below steps:
1. Write a Kubernetes secret as below:
```
kubectl create secret generic secret1 --from-literal=Hello=World!!!
```

2. Using etcdctl try to access the secret as below, you should be able to see the secret stored in encrypted format
```
ETCDCTL_API=3 etcdctl get /registry/secrets/default/secret1
```

Else you can verify the configuration by starting the Kubernetes API server and testing the features as described in  [Encrypting your data with the KMS provider](https://kubernetes.io/docs/tasks/administer-cluster/kms-provider/#encrypting-your-data-with-the-kms-provider).

Note: The whole setup above ensures that your secrets are encrypted at rest in etcd, they can still be accessed via `kubectl get secret` command. Kubernetes does not allow the secrets to be encrypted when you run this command because `kubectl get secrets` makes the same API call that your pods make when they have to retrive the secret from etcd. Encryption at this level would mean your pods will also not be able to read the secrets.
