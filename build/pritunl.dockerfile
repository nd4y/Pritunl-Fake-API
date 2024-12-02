ARG BASE_IMAGE
FROM $BASE_IMAGE

# Install curl
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y curl && rm -rf /var/lib/apt/lists/*

# Copy FakeAPI CA certificate to python truststore
COPY ./certs/ca.crt.pem .

RUN cat ca.crt.pem | tee -a /usr/lib/pritunl/usr/lib/python3.9/site-packages/certifi/cacert.pem; rm -f ca.crt.pem
