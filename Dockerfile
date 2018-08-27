FROM huggla/alpine

ARG PGADMIN4_VERSION="3.2"
ARG CONFIG_DIR="/etc/pgadmin"
ARG DATA_DIR="/pgdata"

RUN apk --no-cache add python3 postgresql-libs \
 && apk --no-cache add --virtual .build-dependencies python3-dev gcc musl-dev postgresql-dev wget ca-certificates libffi-dev make \
 && downloadDir="$(mktemp -d)" \
 && wget -O "$downloadDir/pgadmin4-${PGADMIN4_VERSION}-py2.py3-none-any.whl" https://ftp.postgresql.org/pub/pgadmin/pgadmin4/v${PGADMIN4_VERSION}/pip/pgadmin4-${PGADMIN4_VERSION}-py2.py3-none-any.whl \
 && pip3 --no-cache-dir install --upgrade pip \
 && pip3 --no-cache-dir install "$downloadDir/pgadmin4-${PGADMIN4_VERSION}-py2.py3-none-any.whl" \
 && rm -rf "$downloadDir" \
 && apk del .build-dependencies \
 && mkdir -p /var/lib/pgadmin \
 && ln /usr/bin/python3 /usr/local/bin/python

ENV VAR_LINUX_USER="postgres" \
    VAR_CONFIG_FILE="$CONFIG_DIR/config_local.py" \
    VAR_param_DEFAULT_SERVER="'0.0.0.0'" \
    VAR_param_SERVER_MODE="False" \
    VAR_param_ALLOW_SAVE_PASSWORD="False" \
    VAR_param_CONSOLE_LOG_LEVEL="30" \
    VAR_param_LOG_FILE="'/var/log/pgadmin'" \
    VAR_param_FILE_LOG_LEVEL="0" \
    VAR_param_SQLITE_PATH="'$DATA_DIR/sqlite/pgadmin4.db'" \
    VAR_param_SESSION_DB_PATH="'$DATA_DIR/sessions'" \
    VAR_param_STORAGE_DIR="'$DATA_DIR/storage'" \
    VAR_param_UPGRADE_CHECK_ENABLED="False" \
    VAR_FINAL_COMMAND="/usr/local/bin/python /usr/lib/python2.7/site-packages/pgadmin4/pgAdmin4.py"

USER starter
