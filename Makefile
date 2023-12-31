######################################### COLOR CODES #########################################
BLACK		:= "\033[0;30m"
RED			:= "\033[0;31m"
GREEN		:= "\033[0;32m"
YELLOW		:= "\033[0;33m"
BLUE		:= "\033[0;34m"
PURPLE		:= "\033[0;35m"
CYAN		:= "\033[0;36m"
WHITE		:= "\033[0;37m"
END			:= "\033[m"
RESET		:= "\033[0m"
######################################## MAIN COMMANDS ########################################

# Varsayılan olarak çalıştırılacak hedefi tanımlayınız.
# Herhangi bir hedef belirtmeden sadece 'make' komutu ile çalıştırıldığında çalışacaktır.
.DEFAULT_GOAL	:= help

# Docker Compose dosyaları ve dizinlerinin değişkenlerini tanımlayınız.
COMPOSE_FILE	:= docker-compose.yml
COMPOSE_DIR		:= ./srcs/
USER			:= ayaman
WP_DIR			:= /home/$(USER)/data/wordpress
DB_DIR			:= /home/$(USER)/data/mariadb

#Tek adımla tüm yapıyı kurun.
setup: install create-data up ## Install the whole build in one step.

#Container'ları, volumleri, network bağlantılarını ve image'leri görüntüleyin.
info: ps ls_v ls_n images ## View ps, volumes, networks and images.
	@echo $(GREEN)"=========================================================================="$(END)

#Linux sistemine SSH (Secure Shell) erişimi sağlamak için gerekli ayarları yapmayı amaçlar.
setup-ssh: ## It aims to make the necessary settings to provide SSH (Secure Shell) access to the Linux system.
	sudo usermod -aG sudo $(USER)
	if ! sudo grep -q "$(USER)    ALL=(ALL:ALL) ALL" /etc/sudoers; then \
		echo "$(USER)    ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers; \
	fi
	sudo apt install openssh-server -y
	sudo apt install ufw -y
	sudo apt-get install wget -y
	sudo service ssh restart
	if ! sudo grep -q "Port 4242" /etc/ssh/sshd_config; then \
		echo "Port 4242" | sudo tee -a /etc/ssh/sshd_config; \
	fi
	if ! sudo grep -q "PermitRootLogin yes" /etc/ssh/sshd_config; then \
		echo "PermitRootLogin yes" | sudo tee -a /etc/ssh/sshd_config; \
	fi
	if ! sudo grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config; then \
		echo "PasswordAuthentication yes" | sudo tee -a /etc/ssh/sshd_config; \
	fi
	sudo systemctl restart sshd
	sudo service ssh restart
	sudo ufw enable
	sudo ufw allow ssh
	sudo ufw allow 4242
	sudo ufw allow 3306
	sudo ufw allow 80
	sudo ufw allow 443
	sudo ufw allow OpenSSH
	sudo ufw enable
	@echo $(GREEN)"...then add port(4242) for Virtual Machine"
	@echo "Now you can connect to your VM in this way from your own terminal: 'ssh user_name@localhost -p 4242' or ssh root@localhost -p 4242"
	@echo "if you can't connect, check the 'known_hosts' file example: 'rm -rf /home/ayaman/.ssh/known_hosts'"$(END)

# 'docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) up --build -d' komutu: docker-compose.yml dosyasını temel alarak servisleri oluşturur.
#	'-f': Çalıştırılacak Docker Compose dosyasının yolunu belirtir.
#	'up': Docker Compose ile belirtilen servisleri oluşturur ve başlatır.
#	'--build': Docker Compose, servislerin yeni bir yapı oluşturulmasını gerektirip gerektirmediğini kontrol eder. Bu parametre ile tüm servisler yeniden oluşturulur.
#	'-d': Servisleri arka planda (daemon modunda) başlatır. Konteynerler arka planda çalışır ve terminal bağlantısı kesilse bile çalışmaya devam ederler.
#Container'ları yeniden oluşturun ve başlatın.
re: clean create-data ## Recreate and start the containers (with rebuild).
	docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) up --build -d

# Docker ortamını tam kapsamlı bir şekilde temizler ve taze bir başlangıç için hazır hale getirir.
fclean: clean ## It thoroughly cleans the Docker environment and gets it ready for a fresh start.
	@if [ $$(docker ps -aq | wc -l) -gt 0 ]; then \
		docker stop $$(docker ps -aq); \
		docker rm -vf $$(docker ps -aq); \
	fi
	@if [ $$(docker images -aq | wc -l) -gt 0 ]; then \
		docker rmi -f $$(docker images -aq); \
	fi
	@if [ $$(docker volume ls -q | wc -l) -gt 0 ]; then \
		docker volume rm $$(docker volume ls -q); \
	fi
	@if [ $$(docker network ls | grep -v "bridge\|none\|host" | awk '{print $$1}' | tail -n +2 | wc -l) -gt 0 ]; then \
		docker network rm $$(docker network ls | grep -v "bridge\|none\|host" | awk '{print $$1}' | tail -n +2); \
	fi
	@rm -rf $(WP_DIR) $(DB_DIR)
# 	docker system prune -af

# >	'docker-compose down --rmi all --volumes' komutu: Yalnızca projenin altındaki Docker Compose dosyasında tanımlı olan container, volume ve network'leri kaldırır ve container'ların kullandığı image'leri de siler.
#	Bu, projeye özgü temizleme işlemidir ve sadece bu projeye ait olan bileşenleri etkiler.
# >	'rm -rf $(HOME)/data/wordpress' && 'rm -rf $(HOME)/data/mariadb' komutu: Kullandığımız servislerin ana makine üzerinde depoladığı dizinlerin temizlenmesinde kullanılır.
#Docker-compose.yml'ye ait tüm servisleri durdurup, (volumleri, imageleri, networkleri ve bağlantılı dosyaları) temizleyin.
clean: ## Stop all services of docker-compose.yml and clean (volumes, images, networks and linked files).
	@docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) down --rmi all --volumes
	docker system prune
	@rm -rf $(WP_DIR) $(DB_DIR)

# > '127.0.0.1	ayaman.42.fr' yapısı, sanal makineden projeden istenildiği gibi bir url girişini sağlamak için hosts dosyasına eklenmelidir.
# Gerekli programları kurun.
install: ## Install required programs.
	sudo apt-get update
	sudo apt-get upgrade
	sudo apt-get install docker-compose
	if ! sudo grep -q "127.0.0.1	ayaman.42.fr" /etc/hosts; then \
		echo "127.0.0.1	ayaman.42.fr" | sudo tee -a /etc/hosts; \
	fi

# Docker Compose dosyanızda mariadb ve wordpress için driver: local olarak ayrılmış bir volume kullanıyorsanız ve bu volume'lerin host makinenizde belirli klasörlere monte edilmesini istiyorsanız klasörleri ayrı olarak oluşturmalınız.
#	Oluşturulacak klasörler docker-compose.yml içinde 'volumes' parametresinin alt parametresi olan 'device' parametresine uygun olmalıdır.
# 'mkdir -p'deki 'p' parametresi dosya kontrolü yapar. Yani aynı isime sahip bir dosya varsa oluşturma işlemini gerçekleştirmiyor.
create-data:
	@mkdir -p $(WP_DIR)
	@mkdir -p $(DB_DIR)

################################### DOCKER COMPOSE COMMANDS ###################################

#Container'ları başlatın.
up: ## Start the containers.
	@docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) up -d

#Container'ları durdurun ve temizleyin.
down: ## Stop and remove the containers.
	@docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) down

#Hizmetleriniz için imaj oluşturmak veya güncellemek için kullanılır.
build: ## Used to create or update images for your services.
	@docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) build

#Çalışan Container'ları listeleyin.
ps: ## List running containers.
	@echo $(GREEN)"=========================== RUNNING CONTAINERS ==========================="$(END)
	@docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) ps

#Container günlüklerini görüntüleyin.
logs: ## View container logs.
	@docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) logs -f

#Çalışan image'leri listeleyin.
images: ## List docker-compose images.
	@echo $(GREEN)"=========================== IMAGES ======================================="$(END)
	@docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) images

#Herhangi bir container'ın içinde komut çalıştırın (örnek, 'make exec SRV=mariadb').
exec: ## Execute a command inside the any container (e.g. 'make exec SRV=mariadb').
	@docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) exec -it $(SRV) bash

#Docker Compose projesi içindeki docker-compose.yml dosyasını işleyerek projenin yapılandırmasını ve hizmetlerin ayarlarını görüntüler.
config: ## Displaying the configuration and settings of services docker-compose.yml
	@docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) config

#Durmuş hizmetleri başlatmak için kullanılır.
start: ## Used for stopped startup services.
	@docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) start

#Hizmetleri durdurmak için kullanılır.
stop: ## Use Services to stop.
	@docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) stop

#Hizmetleri yeniden başlatmak için kullanılır.
restart: ## Used to restart services.
	@docker-compose -f $(COMPOSE_DIR)$(COMPOSE_FILE) restart

####################################### DOCKER COMMANDS #######################################

# Çalışan tüm container'ları listeleyebilirsiniz.
containers: 
	@docker container list --all

# Öncelikle image'in pull edilmesi gerekmektedir.
# SRV=debian:buster, SRV=mariadb, SRV=nginx, SRV=wordpress, SRV=adminer
run:
	@docker run -it $(SRV)

# Bu yapı ile image'leri dockerhub'tan çekebilirsiniz.
# SRV=debian:buster, SRV=mariadb, SRV=nginx, SRV=wordpress, SRV=adminer
pull:
	@docker pull $(SRV)

# Çalıştırılan image'lerin arayüzüne bağlanmak için kullanabilirsiniz.
# SRV=debian:buster, SRV=mariadb, SRV=nginx, SRV=wordpress, SRV=adminer
exec_:
	@docker exec -it $(SRV) bash

# Çalışan image'lerin günlük kayıtlarına bakabilirsiniz.
# SRV=debian:buster, SRV=mariadb, SRV=nginx, SRV=wordpress, SRV=adminer
logs_:
	@docker logs $(SRV)

# Docker nesnesinin (konteyner, imaj, ağ, hacim vb.) ayrıntılı bilgilerini görüntülemek için kullanılır. 
# SRV=debian:buster, SRV=mariadb, SRV=nginx, SRV=wordpress, SRV=adminer
inspect:
	@docker inspect $(SRV)

# Docker ortamınızda bulunan ağları listelemek için kullanılır.
ls_n:
	@echo $(GREEN)"=========================== NETWORKS ====================================="$(END)
	@docker network ls

# Docker ortamınızda bulunan volumleri listelemek için kullanılır.
ls_v:
	@echo $(GREEN)"=========================== VOLMUES ======================================"$(END)
	@docker volume ls

# Varolan bir Docker volume'ı görüntülemek için kullanılır.
# DIR=srcs_db_data, DIR=srcs_wp_data
volume:
	@docker volume inspect $(DIR)

# Tüm çalışan containerları durdurmak için kullanılır.
stop_:
	@docker stop $(docker ps -aq)

# Durdurulan tüm containerları silmek için kullanılır.
rm:
	@docker rm -f $(docker ps -aq)

images_:
	@docker images

############################################ HELP #############################################

# Mevcut hedefleri ve açıklamalarını görüntülemek için bir yardım hedefi tanımlayın.
help:
	@echo $(GREEN)"внимание! Измените «USER» в make-файле."$(END)
	@echo $(GREEN)"Attention! Change «USER» in Makefile."$(END)
	@echo $(RED)"Firstly, setup packets in root: \n\
		'#> apt-get install sudo' \n\
		'#> apt-get install git' \n\
		'#> apt-get install make' \n\
		'set MV networks; host machine ip: 127.0.0.1,  host b. point: 443, guest b.point: 443"$(END)
	@echo $(GREEN)"For the first use: use the 'make setup' and 'make setup-ssh' commands."$(END)
	@echo "Usage: make ["$(BLUE)"target"$(END)"]"
	@echo "\033[31mTargets:\033[0m"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf $(RED)">"$(CYAN)"%-10s"$(END)"%s\n", $$1, $$2}'

# Debian veya Ubuntu tabanlı Linux sistemlerinde paket yönetimini kullanarak sistemdeki paketleri güncellemek ve eksik paketleri yüklemek için kullanılır.
fix-package:
	apt-get update && apt-get install -y --fix-missing

# TLS versiyonunun kontrolü için kullanılır.
tls: ## Check the TLS version.
	@echo $(GREEN)"=========================== TLSv1.2 ====================================="$(END)
	@docker exec nginx openssl s_client -connect localhost:443 -tls1_2
	@echo $(GREEN)"=========================== TLSv1.3 ====================================="$(END)
	@docker exec nginx openssl s_client -connect localhost:443 -tls1_3
	@echo $(GREEN)"=========================================================================="$(END)

############################################ INFO #############################################

### Using makefile for docker-compose ###
# https://medium.com/freestoneinfotech/simplifying-docker-compose-operations-using-makefile-26d451456d63

### A makefile example with docker compose commands ###
# https://www.inanzzz.com/index.php/post/wqfy/a-makefile-example-with-docker-compose-commands

### How do I find the Debian:buster version and which one? ###
# https://www.debian.org/releases/buster/debian-installer/
# OS for VM: 'debian-10.13.0-amd64-netinst'

### Setup the google chrome ###
# $> apt-get install wget
# $> wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
# $> sudo apt install ./google-chrome-stable_current_amd64.deb
# $> google-chrome

### How to PULL VM files your pc ###
# Firstly zip your files:
#	$> tar -czvf inception.gz inception
# Connect with sftp:
#	$> sftp ayaman@localhost
# Pull the file to your directory:
#	$> get inception.gz /Users/ayaman/Desktop
#	or
#	You can pull and get with VS code.

### How to PUT files main pc to VM pc ###
# Connect with sftp:
#	$> sftp ayaman@localhost
# Put the file to your directory:
#	$> put /Users/ayaman/"3'in-1i.txt" /home/ayaman
#	or
#	You can pull and get with VS code.

### How to connect on your pc special url: ayaman.42.fr ###
# Find your pc /etc/hosts file and add the line '127.0.0.1 ayaman.42.fr'

### How to access your project page on Ecole Macs? ###
# $> hostname
# Use the hostname output, put the url : https://k2m15s08.42kocaeli.com.tr/

### How to get private ip address ###
# $> ipconfig getifaddr en0

###############################################################################################
.PHONY: setup setup-ssh re fclean clean install info ps create-data up down build ps images logs exec config start stop restart containers run pull exec_ logs_ inspect ls_n ls_v stop_ rm iamges_ help fix-package
