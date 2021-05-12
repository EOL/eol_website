FROM ruby:2.6.5
LABEL maintainer="Jeremy Rice <jrice@eol.org>"

LABEL last_full_rebuild="2021-02-11"

RUN apt-get update -q && \
    apt-get install -qq -y build-essential libpq-dev curl wget openssh-server openssh-client \
    apache2-utils nodejs procps supervisor vim nginx logrotate msmtp && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    mkdir /etc/ssmtp

RUN apt-get update -q && \
    apt-get install -qq -y npm

RUN npm install -g --no-fund yarn

RUN apt-get update -q && \
    apt-get install -qq -y yarn && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

LABEL last_source_update="2020-01-09"

COPY . /app
COPY config/nginx-sites.conf /etc/nginx/sites-enabled/default
COPY config/nginx.conf /etc/nginx/nginx.conf
# NOTE: supervisord *service* doesn't work with custom config files, so just use default:
# UPDATE: I have removed the config file from Dockerfile and moved it to a mounted file in docker-compose.
# COPY config/supervisord.conf /etc/supervisord.conf
COPY Gemfile ./

# Set up mail (for user notifications, which are rare but critical)

# root is the person who gets all mail for userids < 1000
RUN echo "root=admin@eol.org" >> /etc/ssmtp/ssmtp.conf
# Here is the gmail configuration (or change it to your private smtp server)
RUN echo "mailhub=smtp-relay.gmail.com:25" >> /etc/ssmtp/ssmtp.conf

RUN echo "UseTLS=YES" >> /etc/ssmtp/ssmtp.conf
RUN echo "UseSTARTTLS=YES" >> /etc/ssmtp/ssmtp.conf

RUN gem install bundler:2.1.4
RUN bundle config set without 'test development staging'
RUN bundle install --jobs 10 --retry 5
# Skipping this for now. The secrets file does not appear to work at this stage. :\
# RUN cd app && rake assets:precompile

RUN apt-get update
RUN apt-get install -qq -y cmake

RUN cd / && git clone https://github.com/neo4j-drivers/seabolt.git && \
    cd seabolt && ./make_debug.sh && cd build && cpack && cd / && \
    tar xzf /seabolt/build/dist-package/seabolt-1.7.4-dev-Linux-debian-10.tar.gz && \
    cp -rf seabolt-1.7.4-dev-Linux-debian-10/* .

RUN touch /tmp/supervisor.sock
RUN chmod 777 /tmp/supervisor.sock
RUN ln -s /tmp /app/tmp

EXPOSE 3000

ENTRYPOINT ["/app/bin/entrypoint.sh"]

CMD ["supervisord", "-c", "/etc/supervisord.conf"]
