FROM nodesource/wheezy:4.4.6

RUN apt-get update && apt-get install -y \
  wget \
  curl \
  vim \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir /image-service
COPY . /image-service/
WORKDIR /image-service

RUN npm install --production

ENTRYPOINT [ "node", "index.js" ]
