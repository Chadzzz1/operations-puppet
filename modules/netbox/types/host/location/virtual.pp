type Netbox::Host::Location::Virtual = Struct[{
    # should at some point have a Wmflib::Site
    site    => String[5,5],
    cluster => Stdlib::Fqdn,
}]
