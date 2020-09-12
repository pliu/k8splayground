package distributor

import (
	"k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/rest"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/client/apiutil"
	"sigs.k8s.io/controller-runtime/pkg/client/config"
)

func GetK8sClient(impersonateUser string) (client.Client, error) {
	cfg, err := config.GetConfig()
	if err != nil {
		return nil, err
	}
	cfg.Impersonate = rest.ImpersonationConfig{
		UserName: impersonateUser,
		Groups:   nil,
		Extra:    nil,
	}

	mapper, err := apiutil.NewDynamicRESTMapper(cfg)
	if err != nil {
		return nil, err
	}

	options := client.Options{Scheme: scheme.Scheme, Mapper: mapper}

	c, err := client.New(cfg, options)
	if err != nil {
		return nil, err
	}

	return c, nil
}
