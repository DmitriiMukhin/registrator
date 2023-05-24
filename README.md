# Registrator (With Network priority)

I added to the "registrator" the ability to select **docker networks name** or **subnetwork** has been prioritized in the tools.

Under certain conditions and it does not matter the order of the Docker network, the eth0 card is not reassembled as the first network. This creates a problem with Consul's healthcheck, for example, where the IP address Consul used is unreachable by Consul.

This therefore allows you to have several networks identified in your container but to prioritize the one you want.

In the event that no IP is found in the list of defined networks, registrator will show the first IP (standard operation).

## Source
https://gitlab.com/dkr-registrator/registrator

## Fork of
https://github.com/gliderlabs/registrator

# Docker
Docker page: https://hub.docker.com/r/hypolas/registrator

Docker pull: hypolas/registrator

Pull command: docker pull hypolas/registrator


```docker-compose.yml```:
```yaml
version: '3.8'

services:
  registrator:
    image: hypolas/registrator:latest
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro
    command: -internal -cleanup -resync 10 -networks-priority "10.10.0.0/16" consul://consul:8500
```

# Result
![registrator](docs/images/registrator.gif)

# How to use
## CLI Options
```
Usage of /bin/registrator:
  /bin/registrator [options] <registry URI>

  -cleanup=false: Remove dangling services
  -deregister="always": Deregister exited services "always" or "on-success"
  -internal=false: Use internal ports instead of published ones
  -ip="": IP for ports mapped to the host
  -resync=0: Frequency with which services are resynchronized
  -retry-attempts=0: Max retry attempts to establish a connection with the backend. Use -1 for infinite retries
  -retry-interval=2000: Interval (in millisecond) between retry-attempts.
  -tags="": Append tags for all registered services
  -ttl=0: TTL for services (default is no expiry)
  -ttl-refresh=0: Frequency with which service TTLs are refreshed
  -networks-priority="": If containers have multi networks, you can specified witch network used (in -internal mode). Comma separator
```

## You are here for this option
```
-networks-priority=""
```

# Examples
## Command line for global consiguration.
```
-internal -cleanup -resync 10 -networks-priority "10.10.0.0/16,my_docker_network_name,10.1.1.0/24" consul://consul:8500
```
## Environnement variables for specifics container configuration.
```yml
version: '3.8'

services:
  test:
    image: sverrirab/sleep
    networks:
      - ipam50
      - ipam51
      - ipam52
      - ipamX
   environment:
      SERVICE_NAME: test
      SERVICE_NETWORKS_PRIORITY: ipamX
      SERVICE_50_NETWORKS_PRIORITY: ipam50
      SERVICE_51_NETWORKS_PRIORITY: ipam51
      SERVICE_52_NETWORKS_PRIORITY: 10.52.0.0/16
```

# Differences with fork
- Update Alpine to recent build.
- Remove all locked dependecies (must be compatible with more recent tools. Not tested for all).
- Split packages to real Go modules.

## License

MIT

<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/c/c3/License_icon-mit.svg/256px-License_icon-mit.svg.png" />
