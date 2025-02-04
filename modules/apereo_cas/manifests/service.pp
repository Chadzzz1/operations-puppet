# SPDX-License-Identifier: Apache-2.0
# @summary define a apereo_cas services
# @param id the numerical id
# @param service_id the id of the services i.e. the url pattern
# @param service_class The services class to use
# @param release_policy the release policy to use
# @param access_strategy the access strategy to use
# @param required_groups a list of required ldap groups for the services
# @param properties a list of addtional properties for the services
# @param allowed_delegate add an allowed delegated authentication provider
# @param client_secret the client_secret used for OIDC
define apereo_cas::service (
    Integer                              $id,
    String                               $service_id,
    Apereo_cas::Service::Class           $service_class   = 'CasRegisteredService',
    Apereo_cas::Service::Release_policy  $release_policy   = 'ReturnAllAttributeReleasePolicy',
    Apereo_cas::Service::Access_strategy $access_strategy  = 'DefaultRegisteredServiceAccessStrategy',
    Array[String]                        $required_groups  = [],
    Hash                                 $properties       = {},
    Optional[String[1]]                  $allowed_delegate = undef,
    Optional[String[1]]                  $client_secret    = undef,
) {
    if $service_class == 'OidcRegisteredService' {
        if !$client_secret {
            fail('$client_secret required when using OidcRegisteredService')
        }

        $additional_params = {
            'clientId'               => $title,
            'clientSecret'           => $client_secret,
            'bypassApprovalPrompt'   => true,
            'supportedResponseTypes' => [ 'java.util.HashSet', [ 'code' ] ],
            'supportedGrantTypes'    => [ 'java.util.HashSet', [ 'authorization_code' ] ],
            'scopes'                 => [ 'java.util.HashSet', [ 'profile', 'openid', 'email', 'groups' ] ]
        }
    } else {
        $additional_params = {}
    }

    include apereo_cas
    $delegate = $allowed_delegate ? {
        undef   => {},
        default => {
            'delegatedAuthenticationPolicy' => {
                '@class'           => 'org.apereo.cas.services.DefaultRegisteredServiceDelegatedAuthenticationPolicy',
                'allowedProviders' => [ 'java.util.ArrayList', [ $allowed_delegate ]],
            }
        }
    }
    $ldap_root = "${apereo_cas::ldap_group_cn},${apereo_cas::ldap_base_dn}"
    if $required_groups.empty() {
        $_access_strategy = { '@class' => "org.apereo.cas.services.${access_strategy}" }
    } else {
        $ldap_groups = $required_groups.map |$group| { "cn=${group},${ldap_root}" }
        $_access_strategy = {
            '@class'             => "org.apereo.cas.services.${access_strategy}",
            'requiredAttributes' => {
                '@class'   => 'java.util.HashMap',
                'memberOf' => [
                    'java.util.HashSet',
                    $ldap_groups,
                ],
            },
        }
    }
    $base_data = {
        '@class'                 => "org.apereo.cas.services.${service_class}",
        'name'                   => $title,
        'serviceId'              => $service_id,
        'attributeReleasePolicy' => { '@class' => "org.apereo.cas.services.${release_policy}" },
        'id'                     => $id,
        'accessStrategy'         => $_access_strategy + $delegate,
    } + $additional_params
    $data = $properties.empty ? {
        true    => $base_data,
        default => $base_data + { 'properties' => $properties },
    }
    file { "${apereo_cas::services_dir}/${title}-${id}.json":
        ensure  => file,
        content => $data.to_json(),
    }
}
