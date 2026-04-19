Плейбук запускает minikube для домашнего сервера для тестов 

1. Поменять ip-адрес и путь к ключу в inventory 


2. Запуск playbook
ansible-playbook -i hosts.ini minikube-lab.yml -b -K
(-b = become/sudo, -K = запрос sudo-пароля, если нужен)