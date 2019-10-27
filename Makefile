cluster_name ?= pydata-nyc
name ?= $(cluster_name)
config ?= config.yaml

# GCP settings
project_id ?= dask-demo-182016
zone ?= us-central1-b
num_nodes ?= 1
machine_type ?= n1-standard-8
worker_machine_type ?=n1-standard-16
user ?= taugspurger@anaconda.com


cluster:
	gcloud container clusters create $(cluster_name) \
	    --num-nodes=$(num_nodes) \
	    --machine-type=$(machine_type) \
	    --zone=$(zone) \
	    --enable-autorepair \
	    --enable-autoscaling --min-nodes=1 --max-nodes=150 \
		--no-enable-basic-auth \
		--no-issue-client-certificate \
		--metadata disable-legacy-endpoints=true
	gcloud beta container node-pools create dask-scipy-preemptible \
	    --cluster=$(cluster_name) \
	    --preemptible \
	    --machine-type=$(worker_machine_type) \
	    --zone=$(zone) \
	    --enable-autorepair \
	    --enable-autoscaling --min-nodes=1 --max-nodes=200 \
	    --node-taints preemptible=true:NoSchedule
	gcloud container clusters get-credentials $(cluster_name) --zone $(zone)

helm:
	kubectl --namespace kube-system create serviceaccount tiller
	kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
	helm init --service-account tiller --wait
	kubectl patch deployment tiller-deploy --namespace=kube-system --type=json --patch='[{"op": "add", "path": "/spec/template/spec/containers/0/command", "value": ["/tiller", "--listen=localhost:44134"]}]'

dask:
	helm repo add pangeo https://pangeo-data.github.io/helm-chart/
	helm repo update
	@echo "Installing dask"
	@helm upgrade --install \
	    $(name) pangeo/pangeo \
		--namespace=$(name) \
		-f $(config) \
		-f secret_$(config) \

delete-helm:
	helm delete $(name) --purge
	kubectl delete namespace $(name)

delete-cluster:
	yes | gcloud container clusters delete $(cluster_name) --zone=$(zone)

shrink:
	gcloud container clusters resize $(cluster_name) --size=3 --zone=$(zone)

scale-up:
	gcloud container clusters resize $(cluster_name) --node-pool=dask-scipy-preemptible --size=720 --zone=$(zone)
	gcloud container clusters resize $(cluster_name) --node-pool=default-pool --size=80 --zone=$(zone)

docker: Dockerfile
	gcloud builds submit \
		--tag gcr.io/$(project_id)/dask-ml-pydata:$$(git rev-parse HEAD |cut -c1-6) \
		--timeout=1h .
	gcloud container images add-tag \
		gcr.io/$(project_id)/dask-ml-pydata:$$(git rev-parse HEAD |cut -c1-6) \
		gcr.io/$(project_id)/dask-ml-pydata:latest --quiet

commit:
	echo "$$(git rev-parse HEAD)"


print-node-pools:
	gcloud container node-pools list --cluster=$(name)
