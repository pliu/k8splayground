package distributor

import (
	"context"
	"fmt"
	"math/rand"
	"reflect"
	"time"

	corev1 "k8s.io/api/core/v1"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

type Void struct{}

var VoidValue Void

func ClaimResource(c client.Client, configmapName string, namespaceName string, hostname string) {
	for true {
		if deleted, success := tryCleanup(c, configmapName, namespaceName); success {
			fmt.Printf("Deleted assignments for %v\n", deleted)
		}
		if assignment, success := TryClaimResource(c, configmapName, namespaceName, hostname); success {
			fmt.Printf("Assigned %s\n", assignment)
		}
		time.Sleep(time.Duration(50+rand.Int31n(21)) * time.Second)
	}
}

func tryCleanup(c client.Client, configmapName string, namespaceName string) ([]string, bool) {
	pods, err := getPods(c, namespaceName)
	if err != nil {
		return nil, false
	}
	podNames := make(map[string]Void)
	for _, pod := range pods {
		podNames[pod.Name] = VoidValue
	}
	return TryRemoveStaleAssignments(c, configmapName, namespaceName, podNames)
}

func TryRemoveStaleAssignments(c client.Client, configmapName string, namespaceName string, podNames map[string]Void) ([]string, bool) {
	configmap, err := GetConfigMap(c, configmapName, namespaceName)
	if err != nil {
		fmt.Printf("ConfigMap %s was not found in namespace %s\n", configmapName, namespaceName)
		return nil, false
	}
	usedResources := make(map[string]interface{})
	if usedResourcesJson, exists := configmap.Annotations[DISTRIBUTOR_ASSIGNMENT_ANNOTATION_KEY]; exists {
		usedResources = ParseJson(usedResourcesJson)
	}
	toDelete := FindStaleAssignments(usedResources, podNames)
	if len(toDelete) == 0 {
		return nil, false
	}
	for _, podName := range toDelete {
		delete(usedResources, podName)
	}
	modifyAssignmentAnnotation(configmap, usedResources)
	return toDelete, TryWriteConfigMap(c, configmap)
}

func TryClaimResource(c client.Client, configmapName string, namespaceName string, hostname string) (string, bool) {
	configmap, err := GetConfigMap(c, configmapName, namespaceName)
	if err != nil {
		fmt.Printf("ConfigMap %s was not found in namespace %s\n", configmapName, namespaceName)
		return "", false
	}
	usedResources := make(map[string]interface{})
	if usedResourcesJson, exists := configmap.Annotations[DISTRIBUTOR_ASSIGNMENT_ANNOTATION_KEY]; exists {
		usedResources = ParseJson(usedResourcesJson)
	}
	assignment, assigned := getHostAssignment(usedResources, hostname)
	if assigned {
		fmt.Printf("%s is already assigned\n", hostname)
		return assignment, true
	}
	resources := ParseJson(configmap.Annotations[DISTRIBUTOR_CAPACITY_ANNOTATION_KEY])
	resource, found := FindFreeResource(resources, usedResources)
	if !found {
		fmt.Println("No available resources to distribute")
		return "", false
	}
	usedResources[hostname] = resource
	modifyAssignmentAnnotation(configmap, usedResources)
	return resource, TryWriteConfigMap(c, configmap)
}

func GetConfigMap(c client.Client, configmapName string, namespaceName string) (*corev1.ConfigMap, error) {
	configmap := &corev1.ConfigMap{}
	if err := c.Get(context.TODO(), client.ObjectKey{Name: configmapName, Namespace: namespaceName}, configmap); err != nil {
		return nil, err
	}
	return configmap, nil
}

func getPods(c client.Client, namespaceName string) ([]corev1.Pod, error) {
	pods := &corev1.PodList{}
	listOps := &client.ListOptions{Namespace: namespaceName}
	if err := c.List(context.TODO(), pods, listOps); err != nil {
		return nil, err
	}
	return pods.Items, nil
}

func getHostAssignment(usedResources map[string]interface{}, hostname string) (string, bool) {
	if assignment, exists := usedResources[hostname]; exists {
		return assignment.(string), true
	}
	return "", false
}

func FindFreeResource(resources map[string]interface{}, usedResources map[string]interface{}) (string, bool) {
	for _, resource := range usedResources {
		resourceString := resource.(string)
		resources[resourceString] = resources[resourceString].(float64) - 1
		if resources[resourceString].(float64) == 0 {
			delete(resources, resourceString)
		}
		if len(resources) == 0 {
			break
		}
	}
	if len(resources) == 0 {
		return "", false
	}
	keys := reflect.ValueOf(resources).MapKeys()
	return keys[0].Interface().(string), true
}

func FindStaleAssignments(usedResources map[string]interface{}, podNames map[string]Void) []string {
	toDelete := []string{}
	for usedPodName, _ := range usedResources {
		if _, exists := podNames[usedPodName]; exists {
			continue
		}
		toDelete = append(toDelete, usedPodName)
	}
	return toDelete
}

func modifyAssignmentAnnotation(configmap *corev1.ConfigMap, usedResources map[string]interface{}) {
	usedResourcesJson := writeJson(usedResources)
	annotations := configmap.Annotations
	annotations[DISTRIBUTOR_ASSIGNMENT_ANNOTATION_KEY] = usedResourcesJson
	configmap.SetAnnotations(annotations)
}

func TryWriteConfigMap(c client.Client, configmap *corev1.ConfigMap) bool {
	if err := c.Update(context.TODO(), configmap); err != nil {
		return false
	}
	return true
}
