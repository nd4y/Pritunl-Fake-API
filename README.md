### Назначение
Адаптация проекта https://github.com/simonmicro/Pritunl-Fake-API для развертывания API сервера Pritunl на том же сервере, где запущен VPN сервер Pritunl.

### Как это работает
1. В Docker запускается вебсервер с FakeAPI сервера лицензирования Pritunl
2. В конфигурационных файлах Pritunl подменяется адрес API сервера лиценизирования Pritunl на `pritunl-fakeapi.local`
3. В /etc/hosts вносится запись `127.0.0.1 pritunl-fakeapi.local` 
4. Используются самоподписанные сертификаты для обеспечения TLS между Pritunl и FakeAPI сервером лицензирования

### Протестировано на версиях 
- Ubuntu Server 22.04 LTS pritunl/now 1.32.3552.76-0ubuntu1~jammy
- Ubuntu Server 20.04 LTS pritunl/now 1.32.3504.68-0ubuntu1~focal 

при использовании клиента OpenVPN. Использование официального клиента Pritunl не тестировалось. 
### Требования
1. Версия ОС и пакета из списка [Протестировано на версиях](#протестировано-на-версиях) 
2. Установленный Docker и Docker Compose в соотвествии с документацией https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository . Пакеты docker.io и docker-compose не поддерживаются. 
3. Пользователь с доступом к Docker без sudo `sudo usermod -aG docker ${USER}`
4. Установленный Pritunl с бесплатной лицензией
5. Порт веб интерфейса Pritunl сменен со стандартного 443 на любой свободный, кроме 80 и 443

### Установка
1. (Рекомендуется) зафиксировать версию Pritunl
```
sudo apt-mark hold pritunl*
```
2. Клонировать репозиторий /opt/pritunl-fakeapi . Можно использовать любой путь на сервере. /opt/pritunl-fakeapi используется в примерах команд ниже.
```
sudo mkdir /opt/pritunl-fakeapi -p && \
sudo chown ${USER}:${USER} /opt/pritunl-fakeapi && \
git clone https://github.com/nd4y/Pritunl-Fake-API.git /opt/pritunl-fakeapi
```
3. (Рекомендуется) сгенерировать сертификаты удостоверяющего центра и сервера. (команды для выпуска сертификатов протестированы на OpenSSL 1.1.1w (Debian 10) и OpenSSL 1.1.1f (Ubuntu 22.04 LTS) 
    1. Перейти в каталог и удалить имеющиеся сертификаты `cd /opt/pritunl-fakeapi/mounts/nginx/certs && rm -f *.pem`
    2. Выпустить сертификат удостоверяющго центра
    ```
    openssl req -x509 -newkey rsa:4096 -keyout ca.key.pem -out ca.crt.pem -sha256 -days 3650 -nodes -subj "/CN=Self-Signed Root Certification Authority" 
    ```
    3. Выпустить запрос на сертификат сервера
    ```
    openssl req -newkey rsa:4096 -nodes -days 3650 -keyout tls.key.pem -out tls.req.pem -subj "/CN=Self-Signed Server Certificate" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:pritunl-fakeapi.local"))
    ```
    4. Подписать запрос на сертификат сервера сертификатом удоствоверяющего центра
    ```
    openssl x509 -req -in tls.req.pem -CA ca.crt.pem -CAkey ca.key.pem -out tls.crt.pem -CAcreateserial -days 3650 -extensions SAN -extfile  <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS:pritunl-fakeapi.local"))
    ```
    5. Удалить файл приватного ключа удостоверяющего центра, файл запроса сертификата сервера и srl файл.
    ```
    rm -f ca.key.pem tls.req.pem ca.crt.srl
    ```

4. Отключить использование VPN сервером Pritunl порта 80/TCP 
```
sudo pritunl set app.redirect_server false
```
5. Запустить контейнеры 
```
cd /opt/pritunl-fakeapi && docker compose up -d
```
6. Установить сертификат удостоверяющего центра в доверенные для Pritunl 
```
cat /opt/pritunl-fakeapi/mounts/nginx/certs/ca.crt.pem | sudo tee -a /usr/lib/pritunl/usr/lib/python3.9/site-packages/certifi/cacert.pem
```
7. Добавить запись в /etc/hosts
```
echo "127.0.0.1 pritunl-fakeapi.local" | sudo tee -a /etc/hosts
```
8. Запустить скрипт setup.py 
```
chmod +x /opt/pritunl-fakeapi/setup.py && sudo /opt/pritunl-fakeapi/setup.py
```
В скрипте выбрать [I]nstall и в качестве "new API endpoint" указать `pritunl-fakeapi.local`

9. Перезапустить Pritunl
```
sudo systemctl restart pritunl
```
10.  В веб интерфейсе Pritunl активировать подписку, введя ключ активации `active ultimate`