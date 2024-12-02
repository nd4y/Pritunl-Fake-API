### Назначение
Адаптация проекта https://github.com/simonmicro/Pritunl-Fake-API для развертывания Pritunl + Pritunl FakeAPI с помощью Docker Compose

### Как это работает
1. В контейнерах Docker запускаются: 
   1. `pritunl-server` сам VPN сервер + установленная в контейнере MongoDB
   2. `pritunl-fakeapi-nginx` Реализация API сервера лицензирования Pritunl 
   3. `pritunl-fakeapi-fpm` Реализация API сервера лицензирования Pritunl
2. В docker compose подменяется адреса серверов лицензирования `app.pritunl.com` и `auth.pritunl.com` на адрес контейнера с nginx
3. Генерируются сертификат CA и серверные сертификаты для доменных имен `app.pritunl.com` и `auth.pritunl.com`. CA сертификат добавляется в доверенные в контейнере `pritunl-server`. Серверные сертификаты добавляются в качестве серверных в контейнер `pritunl-fakeapi-nginx`
4. Используются сгенерированные самоподписанные сертификаты для обеспечения TLS между Pritunl и FakeAPI сервером лицензирования

### Протестировано
Только использование OpenVPN клиента. Работа с официальным клиентом Pritunl не тестировалась.

### Требования
1. Установленный Docker и Docker Compose в соотвествии с документацией https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository . Пакеты docker.io и docker-compose не поддерживаются. 
2. Пользователь с доступом к Docker без sudo `sudo usermod -aG docker ${USER}`

### Установка
1. Клонировать репозиторий /opt/pritunl-fakeapi . Можно использовать любой путь на сервере. /opt/pritunl-fakeapi используется в примерах команд ниже.
```
sudo mkdir /opt/pritunl-fakeapi -p && \
sudo chown ${USER}:${USER} /opt/pritunl-fakeapi && \
git clone https://github.com/nd4y/Pritunl-Fake-API.git /opt/pritunl-fakeapi
```
2. Рекомендуется сгенерировать сертификаты удостоверяющего центра и сервера. Вы можете использовать уже сгененированные сертификаты из этого репозитория, однако, это может негативно отразиться на безопастности решения. Рекомендуется генерировать новые сертификаты для каждой инсталляции. Команды для выпуска сертификатов протестированы на OpenSSL 1.1.1w (Debian 11) и OpenSSL 1.1.1f (Ubuntu 22.04 LTS).
    1. Перейти в каталог и удалить имеющиеся сертификаты `cd /opt/pritunl-fakeapi/build/certs && rm -f *.pem`
    2. Выпустить сертификат удостоверяющго центра
    ```
    openssl req -x509 -newkey rsa:4096 -keyout ca.key.pem -out ca.crt.pem -sha256 -days 3650 -nodes -subj "/CN=Self-Signed Root Certification Authority" 
    ```
    3. Выпустить запрос на сертификат сервера
    ```
    openssl req -newkey rsa:4096 -nodes -days 3650 -keyout tls.key.pem -out tls.req.pem -subj "/CN=Self-Signed Server Certificate" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:app.pritunl.com,DNS:auth.pritunl.com"))
    ```
    4. Подписать запрос на сертификат сервера сертификатом удоствоверяющего центра
    ```
    openssl x509 -req -in tls.req.pem -CA ca.crt.pem -CAkey ca.key.pem -out tls.crt.pem -CAcreateserial -days 3650 -extensions SAN -extfile  <(printf "[SAN]\nsubjectAltName=DNS:app.pritunl.com,DNS:auth.pritunl.com")
    ```
    5. Удалить файл приватного ключа удостоверяющего центра, файл запроса сертификата сервера и srl файл.
    ```
    rm -f ca.key.pem tls.req.pem ca.crt.srl
    ```
    В каталоге `/opt/pritunl-fakeapi/build/certs` должны быть 3 файла:
       1. ca.crt.pem - Сертификат CA, выпустивший tls.crt.pem. При сборке копируется в контейнер `pritunl-server`
       2. tls.crt.pem - Сертификат, подписанный ca.crt.pem и имеющий в SAN DNS:app.pritunl.com,DNS:auth.pritunl.com . При сборке копируется в контейнер `pritunl-fakeapi-nginx`
       3. tls.key.pem - Закрытый ключ к сертификату подписанному ca.crt.pem и имеющий в SAN DNS:app.pritunl.com,DNS:auth.pritunl.com . При сборке копируется в контейнер `pritunl-fakeapi-nginx`

3. Запустить контейнеры 
```
cd /opt/pritunl-fakeapi && docker compose up -d --build
```
4. Получить первичные логин и пароль для входа, выполнив команду `docker compose exec pritunl pritunl default-password`
5. Перейти в Web Interface Pritunl `http://SERVER_IP:80`, введя логин и пароль, полученные на предыдущем шаге, где SERVER_IP - IP адрес (или доменное имя) хоста, на который выполнялась установка.
6. В веб интерфейсе Pritunl активировать подписку, введя ключ активации `active ultimate`

