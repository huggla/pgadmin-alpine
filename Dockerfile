FROM huggla/alpine-slim:20180907-edge as stage1

COPY ./rootfs /rootfs

ARG PGADMIN4_TAG="REL-3_3"
#ARG APKS="python3 postgresql-libs libressl2.7-libssl libressl2.7-libcrypto libffi ca-certificates libintl krb5-conf libcom_err keyutils-libs libverto krb5-libs libtirpc libnsl"
ARG APKS="python3 postgresql-libs libressl2.7-libssl"

RUN mkdir -p /rootfs/usr/bin /rootfs/usr/local/bin /rootfs/usr/lib/python3.6 \
 && apk --no-cache add $APKS \
 && apk --no-cache --quiet info > /apks.list \
 && apk --no-cache --quiet manifest $(cat /apks.list) | awk -F "  " '{print $2;}' > /apks_files.list \
 && tar -cvp -f /apks_files.tar -T /apks_files.list -C / \
 && tar -xvp -f /apks_files.tar -C /rootfs/ \
 && apk --no-cache add --virtual .build-dependencies build-base postgresql-dev libffi-dev git python3-dev \
 && pip3 --no-cache-dir install --upgrade pip \
 && pip3 --no-cache-dir install gunicorn \
 && git clone --branch $PGADMIN4_TAG --depth 1 https://git.postgresql.org/git/pgadmin4.git \
 && pip3 install --no-cache-dir -r /pgadmin4/requirements.txt \
 && cp -a /pgadmin4/web /rootfs/pgadmin4 \
 && cp -a /usr/bin/gunicorn /rootfs/usr/local/bin/ \
 && rm -rf /pgadmin4 /rootfs/pgadmin4/regression /rootfs/pgadmin4/pgadmin/feature_tests \
 && find /rootfs/pgadmin4 -name tests -type d | xargs rm -rf \
 && mv /rootfs/pgadmin4 / \
 && python3.6 -O -m compileall /pgadmin4 \
 && mv /pgadmin4 /rootfs/ \
 && cp -a /usr/lib/python3.6/site-packages /rootfs/usr/lib/python3.6/ \
 && cp -a /usr/bin/python3.6 /rootfs/usr/local/bin/ \
 && cd /rootfs/usr/bin \
 && ln -sf ../local/bin/python3.6 python3.6 \
 && cd /rootfs/usr/local/bin \
 && ln -s python3.6 python \
 && apk --no-cache del .build-dependencies

FROM node:6 AS stage2

COPY --from=stage1 /rootfs /rootfs
COPY --from=stage1 /rootfs /

RUN yarn --cwd /pgadmin4 install \
 && yarn --cwd /pgadmin4 run bundle \
 && yarn cache clean \
 && mkdir -p /rootfs/pgadmin4/pgadmin/static/js/generated \
 && cp -a /pgadmin4/pgadmin/static/js/generated/* /rootfs/pgadmin4/pgadmin/static/js/generated/ \
 && rm -rf /pgadmin4 /rootfs/pgadmin4/babel.cfg /rootfs/pgadmin4/karma.conf.js /rootfs/pgadmin4/package.json /rootfs/pgadmin4/webpack* /rootfs/pgadmin4/yarn.lock /rootfs/pgadmin4/.e* /rootfs/pgadmin4/.p*

FROM huggla/base:20180907-edge

COPY --from=stage2 /rootfs /

ARG CONFIG_DIR="/etc/pgadmin"
ARG DATA_DIR="/pgdata"

ENV VAR_LINUX_USER="postgres" \
    VAR_CONFIG_FILE="$CONFIG_DIR/config_local.py" \
    VAR_BINDS="-b 0.0.0.0:5050" \
    VAR_THREADS="1" \
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
    VAR_FINAL_COMMAND="\$gunicornCmdArgs gunicorn pgAdmin4:app"

USER starter

ONBUILD USER root
