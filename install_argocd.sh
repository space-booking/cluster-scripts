######################################
# Installing And Configuring Argo CD #
######################################

echo ✔️ Updating argo brew packages
brew tap argoproj/tap
brew install argocd

echo ✔️ Creating argocd namespace
kubectl create namespace argocd

kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏱ Wait for argocd pods to contain the status condition of type 'Ready', this can take a while"
kubectl wait --for=condition=Ready pods --all --namespace argocd

echo ✔️ argocd pods are ready
echo ✔️ Making sure argocd is available through port: 9001

# Perform kubectl port-forward in background
kubectl port-forward --namespace argocd service/argocd-server 9001:443 &

echo ℹ️ Trying to get argocd-initial-admin-secret
export PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ℹ️ If you want to make use of the console:
echo 🔑 argoCD username: admin
echo 🔑 argoCD password: $PASSWORD

argocd login localhost:9001 --insecure --username admin --password $PASSWORD

kubectl --namespace argocd get pods
