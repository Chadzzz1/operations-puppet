# == Class java
#
# This class allows to deploy one or more versions of openjdk, choosing
# the favourite combination of version and variant (jdk, jdk-headless, etc.).
#
# The first Java PackageInfo entry in $java_packages will be set as default
# via alternatives if more than one Java versions are listed.
#
class java (
    Array[Java::PackageInfo] $java_packages,
    Boolean                  $hardened_tls=false,
) {

    $java_packages.each |$java_package_info| {
        java::package { "openjdk-${java_package_info['variant']}-${java_package_info['version']}":
            package_info => $java_package_info,
            hardened_tls => $hardened_tls,
        }
    }

    $default_java_package = $java_packages[0]

    # It will be nice to be able to reference this variable from outside of this class.
    # (secondary java version homes will have to be constructed by users)
    # E.g. in kafka profile we can use this var like
    # class { 'confluent::kafka::common':  java_home => $::java::java_home, ... }
    $java_home = "/usr/lib/jvm/java-${default_java_package['version']}-openjdk-amd64"
    $java_exec = "${java_home}/jre/bin/java"

    # By default set alternatives even if only one jvm is deployed on the host.
    alternatives::java { $default_java_package['version']:
        require => Java::Package["openjdk-${default_java_package['variant']}-${default_java_package['version']}"],
    }
}
