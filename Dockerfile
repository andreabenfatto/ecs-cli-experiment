FROM ubuntu:latest

ENV LEIN_INSTALL_PATH /usr/local/bin/lein
ENV LEIN_BIN_URL https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein
ENV LEIN_ROOT true
ENV APP_DIR /opt/app
ENV APP_JAR_NAME delivery-standalone.jar
ENV WAIT_FOR_IT_PATH /usr/local/bin/wait-for-it.sh
ENV WAIT_FOR_IT_URL https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh
ENV BOOT_URL https://github.com/boot-clj/boot-bin/releases/download/latest/boot.sh

ENV DEBIAN_FRONTEND=noninteractive

# Install security updates and required packages
RUN apt-get update && \
    apt-get install --assume-yes unattended-upgrades \
                                 # Install apt-tools
                                 software-properties-common \
                                 # Install Java8
                                 default-jdk \
                                 # curl required for Leinigen install
                                 curl \
				 # Install apache2
				 apache2 \
				 apache2-utils \
				 # Install supervisor
				 supervisor

# install forego
ENV FOREGO_TMP_PATH forego-tmp.deb
ENV FOREGO_PACKAGE_URL https://bin.equinox.io/c/ekMN3bCZFUn/forego-stable-linux-amd64.deb

RUN curl -o $FOREGO_TMP_PATH $FOREGO_PACKAGE_URL && \
    dpkg -i $FOREGO_TMP_PATH && \
    rm $FOREGO_TMP_PATH

# Create htpasswd
RUN htpasswd -c -b /etc/apache2/passwdfile rpm Y4rTkgdd29LKL4fB

# Copy apache config
COPY provision/roles/web-rpm2/files/apache2.conf /etc/apache2/apache2.conf

# Copy apache vhost
COPY rpm2.conf /etc/apache2/sites-enabled/rpm2.conf
COPY rpm2-vhost-dev.conf /etc/apache2/rpm2-vhost-dev.conf
COPY rpm2-vhost-golive.conf /etc/apache2/rpm2-vhost-golive.conf
COPY rpm2-vhost-prd.conf /etc/apache2/rpm2-vhost-prd.conf
COPY rpm2-vhost-test.conf /etc/apache2/rpm2-vhost-test.conf

# Disable the default virtualhost configurations
RUN a2dissite 000-default

# Disable this module because it is incompatible with mpm_prefork
RUN a2dismod mpm_event

# Copy mpm_prefork config file
COPY provision/roles/web-rpm2/files/mpm_prefork.conf /etc/apache2/mods-available/

# Enable some modules for apache
RUN a2enmod rewrite headers proxy proxy_http mpm_prefork socache_shmcb

# Supervisord setup
COPY supervisord.conf /etc/supervisord.conf
RUN mkdir /etc/supervisord.d

# Add Maxmind repository and install geoipupdate
RUN add-apt-repository ppa:maxmind/ppa && \
    apt-get update && \
    apt-get install --assume-yes geoipupdate

## GeoIP2 credentials
COPY provision/roles/web/files/GeoIP.conf /usr/local/etc/

RUN mkdir -p /usr/share/GeoIP

## Download the GeoIP2 database
RUN /usr/bin/geoipupdate -f /usr/local/etc/GeoIP.conf

RUN curl -o $WAIT_FOR_IT_PATH $WAIT_FOR_IT_URL \
    && chmod 755 $WAIT_FOR_IT_PATH

RUN curl -o $LEIN_INSTALL_PATH $LEIN_BIN_URL \
    && chmod 755 $LEIN_INSTALL_PATH

# Install boot for building the Smojure app
# https://github.com/boot-clj/boot
RUN cd /usr/bin \
    && curl -fsSLo boot $BOOT_URL \
    && chmod 755 boot

WORKDIR $APP_DIR

# Cache dependencies as long as project.clj does not change
COPY project.clj $APP_DIR/
RUN lein deps

COPY . $APP_DIR

# Build Smojure
ARG SMOJURE_ENV=production
WORKDIR $APP_DIR/smoke/
ENV BOOT_AS_ROOT yes
ENV BOOT_CLOJURE_NAME org.clojure/clojure
ENV BOOT_VERSION 2.7.1
ENV BOOT_CLOJURE_VERSION 1.7.0
RUN boot $SMOJURE_ENV build

WORKDIR $APP_DIR
RUN mv "$(lein uberjar | sed -n 's/^Created \(.*standalone\.jar\)/\1/p')" ./$APP_JAR_NAME

EXPOSE 10000

CMD ["/usr/bin/supervisord"]
