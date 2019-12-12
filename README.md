<p align="center"><a href="http://35.227.205.240/?job=build-multicloud-operators-foundation_postsubmit">
<img alt="Build Status" src="http://35.227.205.240/badge.svg?jobs=build-multicloud-operators-foundation_postsubmit">
</a>
</p>

# multicloud manager

multicloud manager is the service to manager kubernetes clusters deployed on multiple cloud providers

This is a guide on how to build and deploy multicloud manager from code.

Prerequisite:
- ko, download at [ko](https://github.com/google/ko)

## Setup

Create a directory `$GOPATH/src/github.ibm.com/IBMPrivateCloud`, and clone the code into the directory.

Populate the vendor directory. If necessary, set environment variable `GO111MODULE=on`.

```sh
go mod vendor
```

## Build

Run the following after cloning/pulling/making a change.

```sh
make build
```

make build will build all the binaries in output directory.

## Deploy

You can use `ko` to deploy multicloud manager with the following step.

> Note:
> * Go version needs >= go1.11.
> * Need `export GO111MODULE=on` if Go version is go1.11 or go1.12.
> * The best practice is to configure persistent volume for ETCD and MongoDB StatefulSet.
> * The yaml file of ETCD StatefulSet is `deploy/hub/200-etcd.yaml`. And the mountPath is:
> ```
> volumeMounts:
> - mountPath: /etcd-data
> ```
> * The yaml file of MongoDB StatefulSet is `deploy/hub/200-mongo.yaml`. And the mountPath is:
> ```
> volumeMounts:
> - mountPath: /data/db
> ```
> * If deploy on OCP, needs to run the following command beforehand.
> ```
> oc adm policy add-scc-to-user anyuid system:serviceaccount:multicloud-system:default
> ```

1. Install deployment tool **ko**
    > More information see [ko](https://github.com/google/ko)

    ```sh
    go get github.com/google/ko/cmd/ko
    ```

    Configure `KO_DOCKER_REPO` by running `gcloud auth configure-docker` if you are using Google Container Registry or `docker login` if you are using Docker Hub.

    ```sh
    export PROJECT_ID=$(gcloud config get-value core/project)
    export KO_DOCKER_REPO="gcr.io/${PROJECT_ID}"
    ```

    or

    ```sh
    export KO_DOCKER_REPO=docker.io/<your account>
    ```

2. Install on hub cluster

    Deploy hub components

    ```sh
    ko apply -f deploy/hub --base-import-paths --tags=latest
    ```

    > Note: If you deploy the hub components in OpenShift, you need to adjust your `scc` policy by running command `oc adm policy add-scc-to-user anyuid system:serviceaccount:multicloud-system:default`

3. Install on managed cluster

    Create bootstrap secret `klusterlet-bootstrap` in `default` namespace using a kubeconfig file with any authenticated hub cluster user. If the kubeconfig file includes keys, like `client-certificate` and `client-key`, which reference to local certification files, replace them with `client-certificate-data` and `client-key-data`. The corresponding values of these keys can be obtained with the command below.

    ```sh
    cat /path/to/cert/file | base64 --wrap=0
    ```

    And then create the secret.

    ```sh
    kubectl create secret generic klusterlet-bootstrap --from-file=kubeconfig=/<path>/kubeconfig -n default
    ```

   Customize the cluster name and namespaces of managed cluster in `deploy/klusterlet/300-klusterlet.yaml`.
   Make sure that the name and namespace are unique in the hub.

    ```sh
    --cluster-name=cluster0
    --cluster-namespace=cluster0
    ```

    Configure `default/klusterlet-bootstrap` to `bootstrap-secret` and `cluster0/cluster0` to `cluster` in `deploy/klusterlet/200-connectionmanager.yaml`.

    ```sh
    --bootstrap-secret=default/klusterlet-bootstrap     # namespace/bootstrap-secret
    --cluster=cluster0/cluster0    # cluster-namespace/cluster-name
    ```

    Deploy klusterlet components

    ```sh
    ko apply -f deploy/klusterlet --base-import-paths --tags=latest
    ```

4. (Optional) Enable service registry on managed cluster

    After klusterlet components were installed in managed cluster, Customize the cluster name and namespaces of managed cluster in `deploy/serviceregistry/200-serviceregistry`

    ```sh
    --cluster-name=cluster0
    --cluster-namespace=cluster0
    ```

    > Note: if you want to discover a NodePort type service, you need to set the cluster outside IP with args `--member-cluster-proxy-ip`

    Deploy service registry components

    ```sh
    ko apply -f deploy/serviceregistry --base-import-paths --tags=latest
    ```

    > Note: If you deploy the service registry in OpenShift, you need to adjust your `scc` policy by running command `oc adm policy add-scc-to-user anyuid system:serviceaccount:multicloud-endpoint:default`

    Configure the Kubernetes DNS to forward/proxy the registered services that have `mcm.svc.` suffix to service registry DNS, e.g.

    Find the mcm-svcreg-dns service cluster IP

    ```sh
    kubectl get -n multicloud-endpoint service mcm-svcreg-dns -o jsonpath='{.spec.clusterIP}'
    ```

    If there is no forward plugin in current Kubernetes DNS configuration, configure and enable the forward plugin in the Kubernetes DNS configuration with `kubectl edit -n kube-system configmap coredns`, e.g.

    ```yaml
    Corefile: |
        .:53 {

            ...

            forward mcm.svc. <mcm-svcreg-dns-cluster-ip>
        }
    ```

    If there is already a forward plugin in current Kubernetes DNS configuration, configure and enable the proxy plugin in the Kubernetes DNS configuration, e.g.

    ```yaml
    Corefile: |
        .:53 {
            ...

            forward . /etc/resolv.conf {
               except mcm.svc
            }

            ...

            proxy mcm.svc. <mcm-svcreg-dns-cluster-ip>
        }
    ```

5. Query managed cluster status on hub

    ```sh
    kubectl get clusterjoinrequests.mcm.ibm.com

    NAME                                                      CLUSTER NAME   CLUSTER NAMESPACE   STATUS     AGE
    clusterjoin-3j4pL11QZWvIBS-0I03GUOk5P0PhZH28zltQfGPxwlo   cluster0       cluster0            Approved   31m
    ```

    ```sh
    kubectl get cluster --all-namespaces

    NAMESPACE   NAME       MANAGED BY   ENDPOINTS           STATUS   AGE
    cluster0    cluster0                192.168.65.3:6443   Ready    31m
    ```

## How to use

### View clusters informations

1. Get cluster information

    ```sh
    kubectl get clusters --all-namespaces
    kubectl get clusters -n [namespace_name]
    ```

    example:

    ```sh
    kubectl get cluster --all-namespaces

    NAMESPACE   NAME      ENDPOINTS           STATUS    AGE
    mcmk12      mcmk12    9.37.135.130:8001   Ready     4d
    ```

2. Get cluster status information

    ```sh
    kubectl get clusterstatus --all-namespaces
    kubectl get clusterstatus -n [namespace_name]
    ```

    example:

    ```sh
    kubectl get clusterstatus --all-namespaces

    NAMESPACE   NAME      ADDRESSES      USED/TOTAL CPU   USED/TOTAL MEMORY   USED/TOTAL STORAGE   NODE      POD       AGE       VERSION
    mcmk12      mcmk12    9.37.135.130   7600m/38         21805Mi/74670Mi     129Gi/129Gi          8         111       4d        3.1.0-dirty
    ```

3. Get cluster join request information

    ```sh
    kubectl get clusterjoinrequest
    ```

    example:

    ```sh
    kubectl get clusterjoinrequest

    NAME                                                      CLUSTER NAME   CLUSTER NAMESPACE   STATUS     AGE
    clusterjoin-UOoCuEUYBMMqpNC7nEghojrt-WOBYOvKizhXQJdkJ9A   mcmk12         mcmk12              Approved   4d
    clusterjoin-kBtZfvgOCKiyTMqvm88hRhuThh4q5LELXa8QVqt0e8E   mcmk00         mcmk04              Denied     6d
    ```

4. Get certificate signing request

    ```sh
    kubectl get csr
    ```

    example:

    ```sh
    kubectl get csr

    NAME                                                      AGE       REQUESTOR                                   CONDITION
    clusterjoin-2_zZJYViKZkYCWOke1cFon3RKHXjp9ll2Ns5XkXoh5w   1h        system:serviceaccount:kube-system:default   Approved,Issued
    ```

    approve cluster join request

    ```sh
    kubectl certificate approve <csr_name>
    ```

    example:

    ```sh
    kubectl certificate approve clusterjoin-2_zZJYViKZkYCWOke1cFon3RKHXjp9ll2Ns5XkXoh5w

    certificatesigningrequest.certificates.k8s.io/clusterjoin-2_zZJYViKZkYCWOke1cFon3RKHXjp9ll2Ns5XkXoh5w approved
    ```

### Perform an action on managed cluster

1. Create a kube resource on managed cluster

    example:

    create a deployment on cluster cluster0

    ```sh
    kubectl apply -f examples/work/kube/kubework_create.yaml --validate=false

    kubectl get work --all-namespaces
    NAMESPACE   NAME                            TYPE       CLUSTER      STATUS       REASON   AGE
    cluster0    nginx-work-create               Action     cluster0     Completed             8s
    ```

    After work completed, the deployment will be deployed on cluster cluster0.

    you can also update/delete a kube resource on managed cluster.

    example:

    ```sh
    kubectl apply -f examples/work/kube/kubework_update.yaml --validate=false
    kubectl apply -f examples/work/kube/kubework_delete.yaml --validate=false
    ```

2. Create a helm release on managed cluster

    example:

    ```sh
    kubectl apply -f examples/work/helm/helmwork_create.yaml --validate=false

    kubectl get work --all-namespaces

    NAMESPACE   NAME                                    TYPE       CLUSTER   STATUS       REASON   AGE
    cluster0         nginx-create                            Action     cluster0        Completed             8s
    ```

    After work completed, the helm release will be deployed on cluster cluster0.

    you can also update/delete a helm release on managed cluster.

    example:

    ```sh
    kubectl apply -f examples/work/helm/helmwork_update.yaml --validate=false
    kubectl apply -f examples/work/helm/helmwork_delete.yaml --validate=false
    ```

### (Optional) Register and dicover services on clusters

1. Register a service from a managed cluster to hub cluster

    Annotate your service with `mcm.ibm.com/service-discovery: '{}'` annotation, if the antiotion value is `{}`, the servcie will  be discovered on each managered cluster, you can select the managered clusters with `target-clusters` field, e.g. for the annotation `mcm.ibm.com/service-discovery: '{"target-clusters": ["clutser1", "cluster2"]}'`, the service will be discoved on managered cluster cluster1 and cluster2

2. Visit the registered servcie on managed cluster

    Example: if you have a service `svc/http` in mamaged cluster `cluster0`, you annotate it with `mcm.ibm.com/service-discovery: '{}'` annotation, you can find this serive on other managed clusters by DNS name `http.svc.mcm.svc` or `http.svc.cluster0.mcm.svc`

### Query resources on managed cluster

1. Query kube resource on managed cluster

    example:

    query master node in managed cluster

    ```sh
    kubectl apply -f examples/resourceview/nodeview.yaml --validate=false

    kubectl get resourceview getmasternode

    CLUSTER   NAME          STATUS   ROLES         AGE   VERSION
    cluster0        9.30.183.32   Ready    etcd,master   10d   v1.13.9+icp-ee
    ```

2. Query master node on managed cluster periodicall

    example:

    ```sh
    kubectl apply -f examples/resourceview/nodeview_periodic.yaml --validate=false

    kubectl get resourceview getmasternodeperiod

    CLUSTER   NAME          STATUS   ROLES         AGE   VERSION
    cluster0        9.30.183.32   Ready    etcd,master   10d   v1.13.9+icp-ee
    ```

### Get logs of pod on managed cluster

you can view the pod log of managed cluster

```sh
export TOKEN=<BEARER TOKEN>
curl -k -H "Authorization: Bearer $TOKEN " https://<HUB CLUSTER HOST>:<API PORT/apis/mcm.ibm.com/v1alpha1/namespaces/<MANAGED CLUSTER NAMESPACE> /clusterstatuses/<MANAGED CLUSTER NAME>/log/<POD NAMESPACE>/<POD NAME>/<CONTAINER NAME>
```

example:

```sh
export TOKEN=eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdF9oYXNoIjoiZjQ2ODcxMWRjZDc1Zjc2MDRkMGJlNWY4OTQ4NDAwYWE3MjRlOWZiNSIsInJlYWxtTmFtZSI6ImN1c3RvbVJlYWxtIiwidW5pcXVlU2VjdXJpdHlOYW1lIjoiYWRtaW4iLCJpc3MiOiJodHRwczovLzEyNy4wLjAuMTo4NDQzL2lkYXV0aC9vaWRjL2VuZHBvaW50L09QIiwiYXVkIjoiMTA2YTA3ZGNmZjVlYTVkZmM2ZmIzYjBkZGU1NzE1MjEiLCJleHAiOjE1NzE5NTE3NDAsImlhdCI6MTU3MTk1MTc0MCwic3ViIjoiYWRtaW4iLCJ0ZWFtUm9sZU1hcHBpbmdzIjpbXX0.hB0kg1-EbD7fY10aLiI8pOmPiPbgzulKQQK0Bo1SUdwMKxDEeDAQ4bMm-qrjMnsWPV2tRw_rlwTEhhu3ACY7NaWupEQRxjwTZUuXbe2SCf_ozcbGkl-TptCPRmcrx7xucPmRfQJqNJmvYdKXA31gI-1yD1YWJYjglIxLCYpXRnEmOaYDR0N0iduxeinfqbVpdmVicgIcFo5JgkuQa3hbLqqgILwKEZ3LzI98KV5DwJbQ3NOkD5HG_GQnIE8jfTn3zsbrFK4_jPq0lBmpYJZGdiJL4CBJDGBbkwg6fhTz3g7bXSdxWX_lq0V7ak9FrG6b947c05T0omiYubZdWVZMSw

curl -k -H "Authorization: Bearer $TOKEN " https://9.30.183.32:8001/apis/mcm.ibm.com/v1alpha1/namespaces/cluster0/clusterstatuses/cluster0/log/kube-system/tiller-deploy-8f484458-jp5fp/tiller
```
