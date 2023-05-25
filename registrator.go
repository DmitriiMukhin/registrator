package main

import (
	"errors"
	"flag"
	"fmt"
	"log"
	"os"
	"runtime"
	"strings"
	"time"

	"gitlab.com/dkr-registrator/bridge"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
)

var (
	Version          string
	nFilter          = []string{}
	hostIp           = flag.String("ip", "", "IP for ports mapped to the host")
	internal         = flag.Bool("internal", false, "Use internal ports instead of published ones")
	networksPriority = flag.String("networks-priority", "", "If containers have multi networks, you can specified witch network used (in -internal mode)")
	explicit         = flag.Bool("explicit", false, "Only register containers which have SERVICE_NAME label set")
	useIpFromLabel   = flag.String("useIpFromLabel", "", "Use IP which is stored in a label assigned to the container")
	refreshInterval  = flag.Int("ttl-refresh", 0, "Frequency with which service TTLs are refreshed")
	refreshTtl       = flag.Int("ttl", 0, "TTL for services (default is no expiry)")
	forceTags        = flag.String("tags", "", "Append tags for all registered services")
	resyncInterval   = flag.Int("resync", 0, "Frequency with which services are resynchronized")
	deregister       = flag.String("deregister", "always", "Deregister exited services \"always\" or \"on-success\"")
	retryAttempts    = flag.Int("retry-attempts", 0, "Max retry attempts to establish a connection with the backend. Use -1 for infinite retries")
	retryInterval    = flag.Int("retry-interval", 2000, "Interval (in millisecond) between retry-attempts.")
	cleanup          = flag.Bool("cleanup", false, "Remove dangling services")
	version          = flag.Bool("version", false, "Print application version")
)

func getopt(name, def string) string {
	if env := os.Getenv(name); env != "" {
		return env
	}
	return def
}

func assert(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func main() {
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage of %s:\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "  %s [options] <registry URI>\n\n", os.Args[0])
		flag.PrintDefaults()
	}
	flag.Parse()

	if len(os.Args) == 2 && os.Args[1] == "--version" || *version {
		fmt.Println("Version:\t", Version)
		os.Exit(0)
	}
	log.Printf("Starting registrator %s ...", Version)

	if flag.NArg() != 1 {
		if flag.NArg() == 0 {
			fmt.Fprint(os.Stderr, "Missing required argument for registry URI.\n\n")
		} else {
			fmt.Fprintln(os.Stderr, "Extra unparsed arguments:")
			fmt.Fprintln(os.Stderr, " ", strings.Join(flag.Args()[1:], " "))
			fmt.Fprint(os.Stderr, "Options should come before the registry URI argument.\n\n")
		}
		flag.Usage()
		os.Exit(2)
	}

	if *hostIp != "" {
		log.Println("Forcing host IP to", *hostIp)
	}

	if *networksPriority != "" {
		nFilter = strings.Split(*networksPriority, ",")
	}

	if (*refreshTtl == 0 && *refreshInterval > 0) || (*refreshTtl > 0 && *refreshInterval == 0) {
		assert(errors.New("-ttl and -ttl-refresh must be specified together or not at all"))
	} else if *refreshTtl > 0 && *refreshTtl <= *refreshInterval {
		assert(errors.New("-ttl must be greater than -ttl-refresh"))
	}

	if *retryInterval <= 0 {
		assert(errors.New("-retry-interval must be greater than 0"))
	}

	dockerHost := os.Getenv("DOCKER_HOST")
	if dockerHost == "" {
		if runtime.GOOS != "windows" {
			os.Setenv("DOCKER_HOST", "unix:///tmp/docker.sock")
		} else {
			os.Setenv("DOCKER_HOST", "npipe:////./pipe/docker_engine")
		}
	}

	docker, err := client.NewClientWithOpts(client.FromEnv)
	if err != nil {
		panic(err)
	}

	if *deregister != "always" && *deregister != "on-success" {
		assert(errors.New("-deregister must be \"always\" or \"on-success\""))
	}

	b, err := bridge.New(docker, flag.Arg(0), bridge.Config{
		HostIp:           *hostIp,
		Internal:         *internal,
		Explicit:         *explicit,
		UseIpFromLabel:   *useIpFromLabel,
		ForceTags:        *forceTags,
		RefreshTtl:       *refreshTtl,
		RefreshInterval:  *refreshInterval,
		DeregisterCheck:  *deregister,
		Cleanup:          *cleanup,
		NetworksPriority: nFilter,
	})

	assert(err)

	attempt := 0
	for *retryAttempts == -1 || attempt <= *retryAttempts {
		log.Printf("Connecting to backend (%v/%v)", attempt, *retryAttempts)

		err = b.Ping()
		if err == nil {
			break
		}

		if err != nil && attempt == *retryAttempts {
			assert(err)
		}

		time.Sleep(time.Duration(*retryInterval) * time.Millisecond)
		attempt++
	}

	// Start event listener before listing containers to avoid missing anything
	events, _ := docker.Events(b.Ctx, types.EventsOptions{})
	log.Println("Listening for Docker events ...")

	b.Sync(false)

	quit := make(chan struct{})

	// Start the TTL refresh timer
	if *refreshInterval > 0 {
		ticker := time.NewTicker(time.Duration(*refreshInterval) * time.Second)
		go func() {
			for {
				select {
				case <-ticker.C:
					b.Refresh()
				case <-quit:
					ticker.Stop()
					return
				}
			}
		}()
	}

	// Start the resync timer if enabled
	if *resyncInterval > 0 {
		resyncTicker := time.NewTicker(time.Duration(*resyncInterval) * time.Second)
		go func() {
			for {
				select {
				case <-resyncTicker.C:
					b.Sync(true)
				case <-quit:
					resyncTicker.Stop()
					return
				}
			}
		}()
	}

	// Process Docker events
	for msg := range events {
		switch msg.Status {
		case "start":
			go b.Add(msg.ID)
		case "die":
			go b.RemoveOnExit(msg.ID)
		}
	}

	close(quit)
	log.Fatal("Docker event loop closed") // todo: reconnect?
}
