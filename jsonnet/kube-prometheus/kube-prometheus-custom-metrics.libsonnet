local k = import 'ksonnet/ksonnet.beta.4/k.libsonnet';

// Custom metrics API allows the HPA v2 to scale based on arbirary metrics.
// For more details on usage visit https://github.com/DirectXMan12/k8s-prometheus-adapter#quick-links

{
  _config+:: {
    prometheusAdapter+:: {
      // Rules for custom-metrics
      config+:: {
        rules+: [
          {
            seriesQuery: '{__name__=~"^container_.*",container!="POD",namespace!="",pod!=""}',
            seriesFilters: [],
            resources: {
              overrides: {
                namespace: {
                  resource: 'namespace'
                },
                pod: {
                  resource: 'pod'
                }
              },
            },
            name: {
              matches: '^container_(.*)_seconds_total$',
              as: ""
            },
            metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>,container!="POD"}[1m])) by (<<.GroupBy>>)'
          },
          {
            seriesQuery: '{__name__=~"^container_.*",container!="POD",namespace!="",pod!=""}',
            seriesFilters: [
              { isNot: '^container_.*_seconds_total$' },
            ],
            resources: {
              overrides: {
                namespace: {
                  resource: 'namespace'
                },
                pod: {
                  resource: 'pod'
                }
              },
            },
            name: {
              matches: '^container_(.*)_total$',
              as: ''
            },
            metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>,container!="POD"}[1m])) by (<<.GroupBy>>)'
          },
          {
            seriesQuery: '{__name__=~"^container_.*",container!="POD",namespace!="",pod!=""}',
            seriesFilters: [
              { isNot: '^container_.*_total$' },
            ],
            resources: {
              overrides: {
                namespace: {
                  resource: 'namespace'
                },
                pod: {
                  resource: 'pod'
                }
              },
            },
            name: {
              matches: '^container_(.*)$',
              as: ''
            },
            metricsQuery: 'sum(<<.Series>>{<<.LabelMatchers>>,container!="POD"}) by (<<.GroupBy>>)'
          },
          {
            seriesQuery: '{namespace!="",__name__!~"^container_.*"}',
            seriesFilters: [
              { isNot: '.*_total$' },
            ],
            resources: {
              template: '<<.Resource>>'
            },
            name: {
              matches: '',
              as: ''
            },
            metricsQuery: 'sum(<<.Series>>{<<.LabelMatchers>>}) by (<<.GroupBy>>)'
          },
          {
            seriesQuery: '{namespace!="",__name__!~"^container_.*"}',
            seriesFilters: [
              { isNot: '.*_seconds_total' },
            ],
            resources: {
              template: '<<.Resource>>'
            },
            name: {
              matches: '^(.*)_total$',
              as: ''
            },
            metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[1m])) by (<<.GroupBy>>)'
          },
          {
            seriesQuery: '{namespace!="",__name__!~"^container_.*"}',
            seriesFilters: [],
            resources: {
              template: '<<.Resource>>'
            },
            name: {
              matches: '^(.*)_seconds_total$',
              as: ''
            },
            metricsQuery: 'sum(rate(<<.Series>>{<<.LabelMatchers>>}[1m])) by (<<.GroupBy>>)'
          }
        ],
      },
    },
  },

  prometheusAdapter+:: {
    customMetricsApiService: {
      apiVersion: 'apiregistration.k8s.io/v1',
      kind: 'APIService',
      metadata: {
        name: 'v1beta1.custom.metrics.k8s.io',
      },
      spec: {
        service: {
          name: $.prometheusAdapter.service.metadata.name,
          namespace: $._config.namespace,
        },
        group: 'custom.metrics.k8s.io',
        version: 'v1beta1',
        insecureSkipTLSVerify: true,
        groupPriorityMinimum: 100,
        versionPriority: 100,
      },
    },
    customMetricsClusterRoleServerResources:
      local clusterRole = k.rbac.v1.clusterRole;
      local policyRule = clusterRole.rulesType;

      local rules =
        policyRule.new() +
        policyRule.withApiGroups(['custom.metrics.k8s.io']) +
        policyRule.withResources(['*']) +
        policyRule.withVerbs(['*']);

      clusterRole.new() +
      clusterRole.mixin.metadata.withName('custom-metrics-server-resources') +
      clusterRole.withRules(rules),

    customMetricsClusterRoleBindingServerResources:
      local clusterRoleBinding = k.rbac.v1.clusterRoleBinding;

      clusterRoleBinding.new() +
      clusterRoleBinding.mixin.metadata.withName('custom-metrics-server-resources') +
      clusterRoleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
      clusterRoleBinding.mixin.roleRef.withName('custom-metrics-server-resources') +
      clusterRoleBinding.mixin.roleRef.mixinInstance({ kind: 'ClusterRole' }) +
      clusterRoleBinding.withSubjects([{
        kind: 'ServiceAccount',
        name: $.prometheusAdapter.serviceAccount.metadata.name,
        namespace: $._config.namespace,
      }]),

    customMetricsClusterRoleBindingHPA:
      local clusterRoleBinding = k.rbac.v1.clusterRoleBinding;

      clusterRoleBinding.new() +
      clusterRoleBinding.mixin.metadata.withName('hpa-controller-custom-metrics') +
      clusterRoleBinding.mixin.roleRef.withApiGroup('rbac.authorization.k8s.io') +
      clusterRoleBinding.mixin.roleRef.withName('custom-metrics-server-resources') +
      clusterRoleBinding.mixin.roleRef.mixinInstance({ kind: 'ClusterRole' }) +
      clusterRoleBinding.withSubjects([{
        kind: 'ServiceAccount',
        name: 'horizontal-pod-autoscaler',
        namespace: 'kube-system',
      }]),
  }
}
