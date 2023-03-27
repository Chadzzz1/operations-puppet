# SPDX-License-Identifier: Apache-2.0
#
# This define can be used to install a package for a specific kubernetes version from
# our internal apt repository.
#
define k8s::package (
    Enum['master', 'node', 'client'] $package,
    K8s::KubernetesVersion           $version,
    String                           $distro          = "${::lsbdistcodename}-wikimedia",
    Stdlib::HTTPUrl                  $uri             = 'http://apt.wikimedia.org/wikimedia',
    Integer                          $priority        = 1001,
    Boolean                          $ensure_packages = true,
) {
    require k8s::base_dirs
    $component_title = "kubernetes${regsubst($version, '\\.', '')}"
    ensure_resource('apt::package_from_component', $component_title, {
        component => "component/${component_title}",
        packages  => [],
    })
    ensure_packages("kubernetes-${package}", {
        'require' => Apt::Package_from_component[$component_title],
    })
}
