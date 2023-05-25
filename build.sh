export BUILDKIT_PROGRESS=plain
export APPLICATION_VERSION=$(cat VERSION)
CGO_ENABLED=0 GOOS=linux go build \
	-a -installsuffix cgo \
	-trimpath \
	-ldflags "-w -s" \
	-ldflags="-X 'main.Version=${APPLICATION_VERSION}'" \
	-o build/registrator .
# docker-compose up --force-recreate --build registrator
docker-compose up -d consul
docker-compose  build registrator --no-cache --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
docker-compose up --force-recreate registrator network-port-test