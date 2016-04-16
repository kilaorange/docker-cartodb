FROM ubuntu:12.04.5

#  'exit 101' updated to exit status 0
RUN echo '#!/bin/sh' > /usr/sbin/policy-rc.d \
&& echo 'exit 0' >> /usr/sbin/policy-rc.d \
&& chmod +x /usr/sbin/policy-rc.d \
&& dpkg-divert --local --rename --add /sbin/initctl \
&& cp -a /usr/sbin/policy-rc.d /sbin/initctl \
&& sed -i 's/^exit.*/exit 0/' /sbin/initctl \
&& echo 'force-unsafe-io' > /etc/dpkg/dpkg.cfg.d/docker-apt-speedup \
&& echo 'DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' > /etc/apt/apt.conf.d/docker-clean \
&& echo 'APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' >> /etc/apt/apt.conf.d/docker-clean \
&& echo 'Dir::Cache::pkgcache ""; Dir::Cache::srcpkgcache "";' >> /etc/apt/apt.conf.d/docker-clean \
&& echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/docker-no-languages \
&& echo 'Acquire::GzipIndexes "true"; Acquire::CompressionTypes::Order:: "gz";' > /etc/apt/apt.conf.d/docker-gzip-indexes \
&&  locale-gen en_US.UTF-8 \
&&  update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
&& apt-get clean && apt-get update -y && apt-get -y install --fix-missing software-properties-common  autoconf binutils-doc bison build-essential flex git python-software-properties apt-utils 

RUN add-apt-repository -y ppa:cartodb/base \
&& add-apt-repository -y ppa:cartodb/gis \
&& add-apt-repository -y ppa:cartodb/mapnik \
&& add-apt-repository -y ppa:cartodb/nodejs \
&& add-apt-repository -y ppa:cartodb/redis \
&& add-apt-repository -y ppa:cartodb/postgresql-9.3 \
&& add-apt-repository -y ppa:cartodb/nodejs-010 \
&& add-apt-repository -y ppa:cartodb/varnish \
&& add-apt-repository -y ppa:cartodb/gis

RUN apt-get update && apt-get upgrade -y \
&& apt-get install -y proj \
											proj-bin \
											proj-data \
											libproj-dev \
											libjson0 \
											libjson0-dev \
											python-simplejson \
											libgeos-c1v5 \
											libgeos-dev \
											gdal-bin \
											libgdal1-dev \
											libgdal-dev \
											ogr2ogr2-static-bin \
											libxml2-dev \
											liblwgeom-2.1.8 \
											postgis \
											postgresql-9.3-postgis-2.2 \
											libpq5 \
											libpq-dev \
											postgresql-client-9.3 \
											postgresql-client-common \
											postgresql-9.3 \
											postgresql-contrib-9.3 \
											postgresql-server-dev-9.3 \
											postgresql-plpython-9.3 \
											wget \
											libreadline6-dev \
											openssl \
											python-pip \
											python-all-dev \
											imagemagick \
											unp \
											zip \
											nodejs \
											git \
											redis-server \
											libpango1.0-dev \
											supervisor

RUN echo '' > /etc/postgresql/9.3/main/pg_hba.conf \
&&  echo 'local   all             postgres                                trust' >> /etc/postgresql/9.3/main/pg_hba.conf \
&&  echo 'local   all             all                                     trust' >> /etc/postgresql/9.3/main/pg_hba.conf \
&&  echo 'host    all             all             127.0.0.1/32            trust' >> /etc/postgresql/9.3/main/pg_hba.conf \
&&  echo 'host    all             all             ::1/128            			trust' >> /etc/postgresql/9.3/main/pg_hba.conf

RUN cd ~ \
&& git clone https://github.com/CartoDB/cartodb-postgresql.git \
&& git clone git://github.com/CartoDB/Windshaft-cartodb.git \
&& git clone git://github.com/CartoDB/CartoDB-SQL-API.git \
&& git clone --recursive https://github.com/CartoDB/cartodb.git


RUN service postgresql restart \
&& service redis-server restart \
&& ps ax \
&& createuser publicuser --no-createrole --no-createdb --no-superuser -U postgres \
&& createuser tileuser --no-createrole --no-createdb --no-superuser -U postgres \
&& createdb -T template0 -O postgres -U postgres -E UTF8 template_postgis \
&& createlang plpgsql -U postgres -d template_postgis \
&& psql -U postgres template_postgis -c 'CREATE EXTENSION postgis;CREATE EXTENSION postgis_topology;' \
& ldconfig \
&& cd ~/cartodb-postgresql/ \
&& git checkout master \
&& make all install \
&& service postgresql restart

RUN cd ~/CartoDB-SQL-API/ \
&& git checkout master \
&& npm install \
&& cp config/environments/development.js.example config/environments/development.js

#node app.js development

RUN cd ~/Windshaft-cartodb/ \
&& git checkout master \
&& npm install \
&& cp config/environments/development.js.example config/environments/development.js


RUN  cd ~ \
&& wget -O ruby-install-0.5.0.tar.gz https://github.com/postmodern/ruby-install/archive/v0.5.0.tar.gz \
&& tar -xzvf ruby-install-0.5.0.tar.gz \
&& cd ruby-install-0.5.0/ \
&& make install \
&& ruby-install ruby 2.2.3 \
&& export PATH=$PATH:/opt/rubies/ruby-2.2.3/bin \
&& gem install bundler \
&& gem install compass \
&& cd ~/cartodb/ \
&& RAILS_ENV=development bundle install \
&& npm install \
&& export CPLUS_INCLUDE_PATH=/usr/include/gdal \
&& export C_INCLUDE_PATH=/usr/include/gdal \
&& export PATH=$PATH:/usr/include/gdal \
&& pip install -r python_requirements.txt \
&& export PATH=$PATH:$PWD/node_modules/grunt-cli/bin \
&& bundle install \
&& bundle exec grunt --environment development --force \
&& cp config/app_config.yml.sample config/app_config.yml \
&& cp config/database.yml.sample config/database.yml


RUN 	export PATH=$PATH:/opt/rubies/ruby-2.2.3/bin \
&& echo $PATH \
&& cd ~/cartodb \
&& service postgresql start \
&& service redis-server start \
&& RAILS_ENV=development bundle exec rake rake:db:create \
&& RAILS_ENV=development bundle exec rake rake:db:migrate \
&& bundle exec rake cartodb:db:create_publicuser

# enable the universe
RUN sed -i 's/^#\s*\(deb.*universe\)$/\1/g' /etc/apt/sources.list

COPY supervisord.conf /etc/supervisor/conf.d/carto-supervisord.conf
COPY resque /root/cartodb/script/resque
EXPOSE 3000 8080 8181
CMD /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
