FROM registry.gitlab.com/tyil/docker-perl6:debian-latest

WORKDIR /app

RUN apt update && apt install -y curl git libssl-dev

COPY META6.json META6.json
COPY bin bin
COPY lib lib
COPY commit-filters commit-filters

RUN zef install --deps-only --/test .

CMD [ "perl6", "bin/geth.p6" ]
