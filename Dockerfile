
FROM --platform=$TARGETOS/$TARGETARCH localhost:5000/base-php:$TARGETARCH AS composer

WORKDIR /build

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

COPY composer.json composer.lock ./

RUN composer install --no-dev --no-interaction --no-autoloader --no-scripts

# ================================
# Stage 1-2: Yarn Install
# ================================
FROM --platform=$TARGETOS/$TARGETARCH node:20-alpine AS yarn

WORKDIR /build

COPY package.json yarn.lock ./

RUN yarn config set network-timeout 300000 \
    && yarn install --frozen-lockfile

# ================================
# Stage 2-1: Composer Optimize
# ================================
FROM --platform=$TARGETOS/$TARGETARCH composer AS composerbuild

COPY . ./

RUN composer dump-autoload --optimize

# ================================
# Stage 2-2: Build Frontend Assets
# ================================
FROM --platform=$TARGETOS/$TARGETARCH yarn AS yarnbuild

WORKDIR /build

COPY --exclude=Caddyfile --exclude=docker/ . ./
COPY --from=composer /build ./

RUN yarn run build

# ================================
# Stage 5: Final Application Image
# ================================
FROM --platform=$TARGETOS/$TARGETARCH localhost:5000/base-php:$TARGETARCH AS final

WORKDIR /var/www/html

RUN apk update && apk add --no-cache \
    nginx supervisor supercronic curl

COPY --chown=root:www-data --chmod=640 --from=composerbuild /build ./
COPY --chown=root:www-data --chmod=640 --from=yarnbuild /build/public ./public

# Nginx config
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/site.conf /etc/nginx/http.d/default.conf

# Laravel & Permissions
RUN chown root:www-data ./ \
    && chmod 750 ./ \
    && find ./ -type d -exec chmod 750 {} \; \
    && mkdir -p /pelican-data/storage /var/www/html/storage/app/public /var/run/supervisord /etc/supercronic \
    && ln -s /pelican-data/.env ./.env \
    && ln -s /pelican-data/database/database.sqlite ./database/database.sqlite \
    && ln -sf /var/www/html/storage/app/public /var/www/html/public/storage \
    && ln -s /pelican-data/storage/avatars /var/www/html/storage/app/public/avatars \
    && ln -s /pelican-data/storage/fonts /var/www/html/storage/app/public/fonts \
    && chown -R www-data:www-data /pelican-data ./storage ./bootstrap/cache /var/run/supervisord /var/www/html/public/storage \
    && chmod -R u+rwX,g+rwX,o-rwx /pelican-data ./storage ./bootstrap/cache /var/run/supervisord

# Laravel scheduler cron
COPY docker/crontab /etc/supercronic/crontab

# Entrypoint & supervisor
COPY docker/entrypoint.sh ./docker/entrypoint.sh
COPY docker/supervisord.conf /etc/supervisord.conf

HEALTHCHECK --interval=5m --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/up || exit 1

EXPOSE 80
VOLUME /pelican-data

USER www-data

ENTRYPOINT [ "/bin/ash", "docker/entrypoint.sh" ]
CMD [ "supervisord", "-n", "-c", "/etc/supervisord.conf" ]
