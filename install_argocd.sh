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

######################################
# Configuring ingress to argocd.spacebooking.com #
######################################

echo ℹ️  Enabling Minikube\'s ingress addon
minikube addons enable ingress

MINIKUBE_IP=$(minikube ip)
ARGO_INGRESS="argocd.spacebooking.com"
HOSTS_ENTRY="$MINIKUBE_IP $ARGO_INGRESS"

if grep -Fq "$MINIKUBE_IP" /etc/hosts > /dev/null
then
    echo 🔑 Updating $HOSTS_ENTRY to /etc/hosts
    sudo sed -i '' "s/^$MINIKUBE_IP.*/$HOSTS_ENTRY/" /etc/hosts
else
    echo 🔑 Adding $HOSTS_ENTRY to /etc/hosts
    echo "$HOSTS_ENTRY" | sudo tee -a /etc/hosts
fi

cat <<EOF > ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
    host: argocd.spacebooking.com
  tls:
  - hosts:
    - argocd.spacebooking.com
    secretName: argocd-secret
EOF

# See https://github.com/kubernetes/ingress-nginx/issues/5401
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission

kubectl apply -f ingress.yaml

open https://argocd.spacebooking.com
