FROM pipeline/image-service-base:latest

RUN mkdir /image-service
COPY . /image-service/
WORKDIR /image-service

RUN npm install --production

ENTRYPOINT [ "node", "index.js" ]
