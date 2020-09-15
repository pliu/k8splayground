package main

import (
	distributor "client/pkg"
	"fmt"
	"os"
)

func main() {
	k8sClient, err := distributor.GetK8sClient("")
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	namespace, err := distributor.GetDistributorNamespace()
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	configmapName := os.Getenv(distributor.CONFIGMAP_NAME_ENV_KEY)
	if configmapName == "" {
		fmt.Printf("%s not set\n", distributor.CONFIGMAP_NAME_ENV_KEY)
		os.Exit(1)
	}
	hostname := distributor.GetHostname()
	if hostname == "" {
		fmt.Printf("%s not set\n", distributor.HOSTNAME_ENV_KEY)
		os.Exit(1)
	}
	distributor.ClaimResource(k8sClient, configmapName, namespace, hostname)
}
