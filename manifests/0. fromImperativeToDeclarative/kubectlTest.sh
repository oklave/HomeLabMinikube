# 1. Создание Pod`а императивно
kubectl run web --image=nginx:alpine --port=80 -o yaml --dry-run=client > pod.yaml

# kubectl get pods - чтобы наблюдать за подами

# 2. Создание декларативно
kubectl apply -f pod.yaml
kubectl get pods