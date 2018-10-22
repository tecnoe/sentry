# Requirements
apt-get update && apt-get upgrade -y
apt-get install -y  python-setuptools python-pip python-dev libxslt1-dev libxml2-dev libz-dev libffi-dev libssl-dev libpq-dev libyaml-dev postgresql nginx-full supervisor
add-apt-repository ppa:chris-lea/redis-server
apt-get update
apt-get install redis-server redis-tools

# Checking redis > 3.0
redis-server --version
systemctl restart redis-server

#Create a sentry user, IMPORTANT to run sentry web and worker
sudo adduser sentry
sudo adduser sentry sudo

# Install virtualenv via pip:
pip install -U virtualenv

# Change user root user to sentry
sudo su - sentry

# 3 . Select a location for the environment and configure it with virtualenv. As exemplified, the location used is /www/sentry:
virtualenv /www/sentry/

# Activate the virtualenv now:
source /www/sentry/bin/activate
# Note: Activating the environment will adjust the PATH and pip will install into the virtualenv by default. use: deactivate to exit.


# Now that the environment is setup, install sentry on the machine. Again pip is used:
pip install -U sentry

# Create database and Enable citext extension as it is required for the installation (the database creation will fail is this step is skipped):
sudo su - postgres
psql -d template1 -U postgres
create extension citext;
\q

createdb sentrydb
createuser sentry --pwprompt
psql -d template1 -U postgres
GRANT ALL PRIVILEGES ON DATABASE sentrydb to sentry;
ALTER USER sentry WITH SUPERUSER;
\q


# Initialize Sentry:
sentry init /etc/sentry
#This command will create the configuration files in the directory /etc/sentry.

# Edit the file /etc/sentry/sentry.conf.py and add the database credentials: It should look like the following example:

DATABASES = {
    'default': {
    'ENGINE': 'sentry.db.postgres',
    'NAME': 'sentrydb',
    'USER': 'sentry',
    'PASSWORD': 'sentry',
    'HOST': 'localhost',
    'PORT': '5432',
    'AUTOCOMMIT': True,
    'ATOMIC_REQUESTS': False,
    }
}

# In order to receive mails from our Sentry instance, configure the e-mail in the file /etc/sentry/config.yml:
mail.from: 'sentry@localhost'
mail.host: 'localhost'
mail.port: 25
mail.username: ''
mail.password: ''
mail.use-tls: false

#  Initialize the database by running the upgrade function of Sentry:
SENTRY_CONF=/etc/sentry sentry upgrade

# Edit the file /etc/nginx/sites-enabled/default and put the following content in it:

server {
    listen 80 default_server;
    server_name sentry.local;

    location / {
    proxy_pass         http://localhost:9000;
    proxy_redirect     off;

    proxy_set_header   Host              $host;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
    }

}

# Save the file and restart your Sentry server:
service nginx restart

#log out from sentry user IMPORTANT.
exit

# Configure Sentry server as a service with supervisord standard put the following configuration in the file /etc/supervisor/conf.d/sentry.conf:
[program:sentry-web]
directory=/www/sentry/
environment=SENTRY_CONF="/etc/sentry"
command=/www/sentry/bin/sentry run web
autostart=true
autorestart=true
redirect_stderr=true
user=sentry
stdout_logfile=syslog
stderr_logfile=syslog

[program:sentry-worker]
directory=/www/sentry/
environment=SENTRY_CONF="/etc/sentry"
command=/www/sentry/bin/sentry run worker
autostart=true
autorestart=true
redirect_stderr=true
user=sentry
stdout_logfile=syslog
stderr_logfile=syslog

[program:sentry-cron]
directory=/www/sentry/
environment=SENTRY_CONF="/etc/sentry"
command=/www/sentry/bin/sentry run cron
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=syslog
stderr_logfile=syslog

# 2 . Save the file and reload supervisor:
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start all
sudo supervisorctl status