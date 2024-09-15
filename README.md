
# Ativando o Anablock no DNS Recursivo Unbound

Este repositório descreve o procedimento de criação de um script para bloqueio de domínios com ordens de bloqueios pelos órgãos Brasileiros no DNS recursivo do Unbound, que basicamente acessa a API do [Anablock](https://anablock.net.br/) e baixando o arquivo de configuração `anablock.conf` e faz um redirecionamento para uma página de bloqueio personalizada conforme desejar.

## O que é o Anablock?

Sistema criado pela comunidade de consultores em telecomunicações e prestadores de serviços.  
-  Mantido pela [TMSoft Soluções](http://tmsoft.com.br/)  
-  Desenvolvido por [Patrick Brandão](http://patrickbrandao.com/)

O AnaBlock é um programa criado para organizar as ordens de bloqueios de conteúdos no Brasil. É um programa open-source cujos dados podem ser inseridos por cada operador de rede (administrador de sistemas) rodando uma cópia em seu próprio servidor.



-   [Obter os arquivos do AnaBlock](https://anablock.net.br/#source)

  

## Qual o objetivo com sua criação?

Seu objetivo é facilitar o cumprimento dos bloqueios de conteúdos ordenados pela Anatel através dos poderes da República Federativa do Brasil. O Brasil possui milhares de pequenos provedores e dezenas de grandes operadoras e todas são notificadas pela Anatel a executar bloqueios de conteúdos, o que pode resultar em centenas de milhares de horas de trabalhos para sua plena execução.  
O Anablock possui tabelas com o cadastro do objetos bloqueados (domínios, IPs, ...) para que esses objetos sejam convertidos em configurações de equipamentos (roteadores, servidores, firewalls) para execução prática dos bloqueios.

## 1. Script Bash para Baixar e Configurar o Redirecionamento

Crie um arquivo `/etc/unbound/update_anablock.sh`, conforme o exemplo abaixo:

```bash
nano /etc/unbound/update_anablock.sh
```
Cole dentro do arquivo `/etc/unbound/update_anablock.sh` e altere REDIRECT_DOMAIN conforme queira.

```bash
#!/bin/bash
ANABLOCK_URL="https://api.anablock.net.br/domains/all?output=unbound"
ANABLOCK_FILE="/etc/unbound/anablock.conf"
REDIRECT_DOMAIN="bloqueio.dominioisp.com.br."
LOG_FILE="/var/log/unbound_anablock_update.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log "Iniciando atualização do anablock.conf..."

curl -s "$ANABLOCK_URL" -o "$ANABLOCK_FILE"
if [ $? -ne 0 ]; then
    log "Erro ao baixar o arquivo anablock.conf"
    exit 1
fi

log "Arquivo anablock.conf baixado com sucesso."

sed -i -r \
    -e 's/local-zone: "([^"]+)" always_nxdomain/local-zone: "\1" redirect/' \
    -e 's/^local-zone: "([^"]+)".*/&\nlocal-data: "\1 CNAME '"$REDIRECT_DOMAIN"'"/' \
    "$ANABLOCK_FILE"

if [ $? -eq 0 ]; then
    log "Configuração de redirecionamento aplicada com sucesso."
else
    log "Erro ao modificar o arquivo de configuração."
    exit 1
fi

systemctl restart unbound
if [ $? -eq 0 ]; then
    log "Unbound reiniciado com sucesso."
else
    log "Erro ao reiniciar o Unbound."
    exit 1
fi

log "Atualização concluída com sucesso."
```

## 2. Executar e configurar no Unbound

Torne o script executável:
    
```bash    
chmod +x /etc/unbound/update_anablock.sh 
```
Execute o script:
    
```bash
sudo ./etc/unbound/update_anablock.sh
```
Edite o `/etc/unbound/unbound.conf` e adicione a seguinte linha:
```bash
nano /etc/unbound/unbound.conf
```
Logo abaixo de `server: ` incluir essa linha:  `include: /etc/unbound/anablock.conf ` ficando assim:
```bash
server:
    include: /etc/unbound/anablock.conf
```
Reiniciar serviço do unbound:
```bash
systemctl restart unbound
```

## 3. Agendamento Automático com Cron

Para agendar a execução automática do script todos os dias às 02:00 da manhã, foi utilizada a ferramenta `cron`. O cron job foi configurado da seguinte forma:

 Abra o crontab:
   ``` bash   
    sudo crontab -e 
  ```
    
  Adicione a seguinte linha para agendar a execução às 02:00:
    
 ```bash    
    0 2 * * * /etc/unbound/update_anablock.sh 
 ```

## 3. Logs de Execução

Os logs da execução são registrados em `/var/log/unbound_anablock_update.log`. O log armazena informações sobre o sucesso ou falha do download, modificação do arquivo e reinício do serviço Unbound.

Para verificar o log, utilize o seguinte comando:

 ```bash
cat /var/log/unbound_anablock_update.log 
 ```

## Informações adicionais 

Usei como a pagina de bloqueio feita pelo [Rudimar Remontti](https://blog.remontti.com.br/) que tem um blog com muitas soluções interessantes, vale a pena conferir.

### Configurando uma Página de Bloqueio em Seu Servidor Web

Vou deixar exemplo com fazer isso em um  **Apache**. 

Instalar o Apache:

```bash
sudo apt install apache2
```

Crie o diretório onde iremos criar nossa página:
```bash
 mkdir /var/www/bloqueio
```
Crie o arquivo de configuração do apache.

```bash
nano /etc/apache2/sites-available/bloqueio.conf
```


```bash
<virtualhost  *:80>
Protocols h2 http/1.1
ServerName bloqueio.seudominio.com.br
ServerAlias  x.xxx.xxx.x
ServerAlias  [xxxx:xxxx:xxxx:xxxx::x]
ServerAdmin noc@seudominio.com.br
ErrorDocument  404  www.seudominio.com.br
DocumentRoot  /var/www/bloqueio
<Directory  /var/www/bloqueio/>
Options FollowSymLinks
AllowOverride All
</Directory>
LogLevel  warn
ErrorLog  ${APACHE_LOG_DIR}/error.log
CustomLog  ${APACHE_LOG_DIR}/access.log  combined
</virtualhost>
```

Habilite a configuração e reinicie o Apache

```bash
a2ensite bloqueio.conf

systemctl restart apache2
```
Instale o certbot para gerar um certificado ssl para o domínio

```bash
 apt install certbot python3-certbot-apache
```

Execute:

```bash
 certbot
```

Selecione seu domínio, e em sguinda reponda com  **No redirect**

```bash
Which names would you like to  activate HTTPS for?
-  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
1:  seudominio.com.br
2:  bloqueio.seudominio.com.br
-  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -   -  -  -  -  -  -  -  -  -  -  -
Select the appropriate numbers separated by commas and/or  spaces,  or  leave input
blank to  select all options shown  (Enter  'c'  to  cancel):  2  <<<<<<<<<<<<<<<<<<<
Obtaining  a  new  certificate
Performing the following challenges:
http-01  challenge for  bloqueadonobrasil.remontti.com.br
Waiting for  verification...
Cleaning up challenges
Created an SSL vhost at  /etc/apache2/sites-available/bloqueadonobrasil-le-ssl.conf
Deploying Certificate to  VirtualHost  /etc/apache2/sites-available/bloqueadonobrasil-le-ssl.conf
Enabling available site:  /etc/apache2/sites-available/bloqueadonobrasil-le-ssl.conf
Please choose whether or  not  to  redirect HTTP traffic to  HTTPS,  removing HTTP access.
-  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
1:  No redirect  -  Make  no further changes to  the webserver configuration.
2:  Redirect  -  Make  all requests redirect to  secure HTTPS access.  Choose this  for
new  sites,  or  if  you're confident your site works on HTTPS.  You can undo this
change by editing your web server's  configuration.
-  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
Select the appropriate number  [1-2]  then  [enter]  (press  'c'  to  cancel):  1  
```
Agora vou deixar um exemplo de página para ajudar você:

![](https://blog.remontti.com.br/wp-content/uploads/2024/01/anablock-page.png)

Vamos excluir o diretório que foi criado, já que estou prestes a baixar minha página, que, ao ser descompactada, conterá o mesmo nome.

```bash
 rm -rf /var/www/bloqueio/

 cd /var/www/

 wget https://github.com/renylson/anablock_unbound/raw/main/bloqueio.tar.gz

 tar -vxzf bloqueio.tar.gz

 rm bloqueio.tar.gz
 ```

### Referências

#### [Manual de uso do AnaBlock](https://anablock.net.br/manual.php)


#### [Automatizando o bloqueio de sites no Brasil pelo DNS usando a API da anablock.net.br (BIND9+RPZ)](https://blog.remontti.com.br/7759)
