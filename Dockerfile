FROM node:20.6.1-bookworm

WORKDIR /app

COPY . .

RUN set -ex \
    && yarn install \
    && yarn global add pm2 \
    && chmod +x entrypoint.sh \
    && curl -fsSLO --compressed "https://github.com/SagerNet/sing-box/releases/download/v1.5.3/sing-box-1.5.3-linux-amd64.tar.gz" \
    && tar -zxvf sing-box* \
    && cd sing-box-1.5.3-linux-amd64 \
    && EXEC=$(echo $RANDOM | md5sum | head -c 4) \
    && mv sing-box app${EXEC} \
    && rm -rf sing-box \
    && mv app* ../ 

ENTRYPOINT ["yarn", "start"]
