# export DOCKER_BUILDKIT=0
# export COMPOSE_DOCKER_CLI_BUILD=0
export APPLICATION_VERSION=$(cat VERSION)
export BUILD_GOOS="linux"
export BUILD_ARCH="386 amd64 arm arm64"
export BASE_IMAGE=alpine:3.18.0
export IMAGE=hypolas/registrator
for BOS in ${BUILD_GOOS}
do
	for BARCH in ${BUILD_ARCH}
	do
		DOCKER_ARCH=${BARCH}
		if [ "${BARCH}" = "arm" ]
		then
			DOCKER_ARCH="arm/v7"
		elif  [ "${BARCH}"  = "arm64" ]
		then
			DOCKER_ARCH="arm64/v8"
		fi

		export ARCH="${BARCH}"
		CGO_ENABLED=0 GOARCH=${BARCH} GOOS=${BOS} go build -a -installsuffix cgo -trimpath -ldflags="-X 'main.Version=${APPLICATION_VERSION}'" -ldflags "-w -s" -o bin/registrator-${BOS}-${BARCH} .
		docker-compose  build registrator --no-cache \
		--build-arg ARCH=linux/${DOCKER_ARCH} \
		--build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
		# docker buildx build \
		#   --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
		#   --build-arg BASE_IMAGE=${BASE_IMAGE} \
        #   --tag your-username/multiarch-example:latest \
        #   --platform linux/${DOCKER_ARCH} .
	done
done


# docker-compose up -d consul
# docker-compose  build registrator --no-cache --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
# docker-compose up --force-recreate registrator network-port-test