FROM nvidia/cuda@sha256:01d41694d0b0be8b7d1ea8146c7d318474a0f4a90bfea17d3ac1af0328a0830b

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y libz3-4 libz3-dev haskell-stack libtinfo-dev libgmp-dev zlib1g-dev

RUN git clone https://github.com/diku-dk/futhark
WORKDIR "futhark"

RUN stack upgrade
RUN stack setup
RUN stack build
RUN stack install