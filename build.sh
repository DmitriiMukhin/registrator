# export DOCKER_BUILDKIT=0
# export COMPOSE_DOCKER_CLI_BUILD=0
# BuildKit create: docker buildx create --use --driver-opt env.http_proxy=$(cat .env.secret.proxy) --driver-opt env.https_proxy=$(cat .env.secret.proxy) --driver-opt '"env.no_proxy='$no_proxy'"'
export APPLICATION_VERSION=$(cat VERSION)
export BUILD_GOOS="linux"
export BUILD_ARCH="386 amd64 arm arm64"
export BASE_IMAGE=alpine:3.18.0
export LOCAL_REGISTRY=docker.io
export DOCKER_REGISTRY=docker.io
export IMAGE=hypolas/registrator
export HTTP_PROXY=$(cat .env.secret.proxy)
export HTTPS_PROXY=$(cat .env.secret.proxy)
AMEND_IMAGE=""
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

		AMEND_IMAGE="${AMEND_IMAGE} --amend ${LOCAL_REGISTRY}/${IMAGE}:${APPLICATION_VERSION}-${BARCH}"

		echo "Build: ${DOCKER_ARCH} ---- ${BOS}"
		export ARCH="${BARCH}"
		CGO_ENABLED=0 GOARCH=${BARCH} GOOS=${BOS} go build -a -installsuffix cgo -trimpath -ldflags="-X 'main.Version=${APPLICATION_VERSION}'" -ldflags "-w -s" -o bin/registrator-${BOS}-${BARCH} .
		docker-compose  build registrator --no-cache \
		--build-arg ARCH=linux/${DOCKER_ARCH} \
		--build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
		--build-arg BARCH=${BARCH} \
		--build-arg BOS=${BOS}
		# docker push "${LOCAL_REGISTRY}/${IMAGE}:${APPLICATION_VERSION}-${BARCH}"
	done
done

# echo docker manifest create ${DOCKER_REGISTRY}/${IMAGE}:${APPLICATION_VERSION} ${AMEND_IMAGE}
# docker manifest create ${DOCKER_REGISTRY}/${IMAGE}:${APPLICATION_VERSION} ${AMEND_IMAGE}
# docker manifest push --purge ${DOCKER_REGISTRY}/${IMAGE}:${APPLICATION_VERSION}

# docker manifest create ${DOCKER_REGISTRY}/${IMAGE}:latest ${AMEND_IMAGE}
# docker manifest push --purge ${DOCKER_REGISTRY}/${IMAGE}:latest