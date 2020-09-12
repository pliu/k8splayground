package distributor

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"strings"
)

func GetDistributorNamespace() (string, error) {
	if isRunModeLocal() {
		return "default", nil
	}
	nsBytes, err := ioutil.ReadFile("/var/run/secrets/kubernetes.io/serviceaccount/namespace")
	if err != nil {
		return "", err
	}
	ns := strings.TrimSpace(string(nsBytes))
	return ns, nil
}

func ParseJson(jsonString string) map[string]interface{} {
	var result map[string]interface{}
	json.Unmarshal([]byte(jsonString), &result)
	return result
}

func writeJson(dict map[string]interface{}) string {
	bytes, err := json.Marshal(dict)
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
	return string(bytes)
}

func isRunModeLocal() bool {
	return os.Getenv(RUN_MODE_ENV_KEY) == LOCAL_RUN_MODE_ENV_VALUE
}
