package tests

import (
	distributor "client/pkg"
	"context"
	"fmt"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	corev1 "k8s.io/api/core/v1"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

const TEST_NAMESPACE = "distributor-test"

var (
	k8sClient = initClient()
	namespace = initNamespace()
)

func TestMain(m *testing.M) {
	setup()
	code := m.Run()
	shutdown()
	os.Exit(code)
}

func TestFindFreeResource(t *testing.T) {
	assert := assert.New(t)

	resources := map[string]interface{}{"a": 1.0, "b": 2.0}
	usedResources := map[string]interface{}{"a": "a"}
	resource, found := distributor.FindFreeResource(resources, usedResources)
	assert.True(found)
	assert.Equal("b", resource)

	resources = map[string]interface{}{"a": 1.0, "b": 2.0}
	usedResources = map[string]interface{}{"a": "b", "b": "b"}
	resource, found = distributor.FindFreeResource(resources, usedResources)
	assert.True(found)
	assert.Equal("a", resource)

	resources = map[string]interface{}{"a": 1.0, "b": 2.0}
	usedResources = map[string]interface{}{"a": "b", "b": "b", "c": "a"}
	resource, found = distributor.FindFreeResource(resources, usedResources)
	assert.False(found)

	resources = map[string]interface{}{}
	usedResources = map[string]interface{}{}
	resource, found = distributor.FindFreeResource(resources, usedResources)
	assert.False(found)
}

func TestFindStaleAssignments(t *testing.T) {
	assert := assert.New(t)

	usedResources := map[string]interface{}{"a": "a", "b": "b"}
	podNames := map[string]distributor.Void{"a": distributor.VoidValue, "b": distributor.VoidValue, "c": distributor.VoidValue}
	toDelete := distributor.FindStaleAssignments(usedResources, podNames)
	assert.ElementsMatch([]string{}, toDelete)

	usedResources = map[string]interface{}{"a": "a", "b": "b"}
	podNames = map[string]distributor.Void{"a": distributor.VoidValue}
	toDelete = distributor.FindStaleAssignments(usedResources, podNames)
	assert.ElementsMatch([]string{"b"}, toDelete)

	usedResources = map[string]interface{}{"a": "a", "b": "b"}
	podNames = map[string]distributor.Void{}
	toDelete = distributor.FindStaleAssignments(usedResources, podNames)
	assert.ElementsMatch([]string{"a", "b"}, toDelete)
}

func TestConcurrentTryWriteConfigMap(t *testing.T) {
	configmapName := "concurrenttrywriteconfigmaptest"
	assert := assert.New(t)

	configmap := initConfigMap(configmapName, TEST_NAMESPACE, nil)
	assert.Nil(k8sClient.Create(context.TODO(), configmap))
	configmap1, err := distributor.GetConfigMap(k8sClient, configmapName, TEST_NAMESPACE)
	assert.Nil(err)
	configmap2, err := distributor.GetConfigMap(k8sClient, configmapName, TEST_NAMESPACE)
	assert.Nil(err)

	configmap1Annotations := map[string]string{"1": "1"}
	configmap2Annotations := map[string]string{"2": "2"}
	configmap1.SetAnnotations(configmap1Annotations)
	configmap2.SetAnnotations(configmap2Annotations)
	assert.True(distributor.TryWriteConfigMap(k8sClient, configmap1))
	assert.False(distributor.TryWriteConfigMap(k8sClient, configmap2))

	configmap3, err := distributor.GetConfigMap(k8sClient, configmapName, TEST_NAMESPACE)
	assert.Nil(err)
	assert.Equal(configmap1Annotations, configmap3.Annotations)

	configmap3.SetAnnotations(configmap2Annotations)
	assert.True(distributor.TryWriteConfigMap(k8sClient, configmap3))

	configmap4, err := distributor.GetConfigMap(k8sClient, configmapName, TEST_NAMESPACE)
	assert.Nil(err)
	assert.Equal(configmap2Annotations, configmap4.Annotations)
}

func TestConcurrentTryCleanupClaim(t *testing.T) {
	configmapName := "concurenttrycleanupclaimtest"
	hostnames := []string{"test1", "test2", "test3", "test4"}
	assert := assert.New(t)

	configmap := initConfigMap(configmapName, TEST_NAMESPACE, map[string]string{
		distributor.DISTRIBUTOR_CAPACITY_ANNOTATION_KEY: `{
			"a": 2,
			"b": 1
		}`,
	})
	assert.Nil(k8sClient.Create(context.TODO(), configmap))

	resources := []string{}
	resource1, success := distributor.TryClaimResource(k8sClient, configmapName, TEST_NAMESPACE, hostnames[0])
	assert.True(success)
	resources = append(resources, resource1)
	resource2, success := distributor.TryClaimResource(k8sClient, configmapName, TEST_NAMESPACE, hostnames[1])
	assert.True(success)
	resources = append(resources, resource2)
	resource3, success := distributor.TryClaimResource(k8sClient, configmapName, TEST_NAMESPACE, hostnames[2])
	assert.True(success)
	resources = append(resources, resource3)
	assert.ElementsMatch([]string{"a", "a", "b"}, resources)
	_, success = distributor.TryClaimResource(k8sClient, configmapName, TEST_NAMESPACE, hostnames[3])
	assert.False(success)

	resource, success := distributor.TryClaimResource(k8sClient, configmapName, TEST_NAMESPACE, hostnames[0])
	assert.True(success)
	assert.Equal(resource1, resource)
	resource, success = distributor.TryClaimResource(k8sClient, configmapName, TEST_NAMESPACE, hostnames[1])
	assert.True(success)
	assert.Equal(resource2, resource)
	resource, success = distributor.TryClaimResource(k8sClient, configmapName, TEST_NAMESPACE, hostnames[2])
	assert.True(success)
	assert.Equal(resource3, resource)
	_, success = distributor.TryClaimResource(k8sClient, configmapName, TEST_NAMESPACE, hostnames[3])
	assert.False(success)

	removed, success := distributor.TryRemoveStaleAssignments(k8sClient, configmapName, TEST_NAMESPACE, map[string]distributor.Void{
		hostnames[0]: distributor.VoidValue,
		hostnames[1]: distributor.VoidValue,
	})
	assert.True(success)
	assert.ElementsMatch([]string{hostnames[2]}, removed)

	resource, success = distributor.TryClaimResource(k8sClient, configmapName, TEST_NAMESPACE, hostnames[0])
	assert.True(success)
	assert.Equal(resource1, resource)
	resource, success = distributor.TryClaimResource(k8sClient, configmapName, TEST_NAMESPACE, hostnames[1])
	assert.True(success)
	assert.Equal(resource2, resource)
	resource, success = distributor.TryClaimResource(k8sClient, configmapName, TEST_NAMESPACE, hostnames[3])
	assert.True(success)
	assert.Equal(resource3, resource)
	_, success = distributor.TryClaimResource(k8sClient, configmapName, TEST_NAMESPACE, hostnames[2])
	assert.False(success)
}

func setup() {
	k8sClient.Create(context.TODO(), namespace)
}

func shutdown() {
	k8sClient.Delete(context.TODO(), namespace)
}

func initClient() client.Client {
	k8sClient, err := distributor.GetK8sClient("")
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	return k8sClient
}

func initNamespace() *corev1.Namespace {
	namespace := &corev1.Namespace{}
	namespace.SetName(TEST_NAMESPACE)
	return namespace
}

func initConfigMap(name string, namespace string, annotations map[string]string) *corev1.ConfigMap {
	configmap := &corev1.ConfigMap{}
	configmap.SetName(name)
	configmap.SetNamespace(namespace)
	if annotations != nil {
		configmap.SetAnnotations(annotations)
	}
	return configmap
}
