type Profile::Netbox::Ganeti_sync_profile = Struct[{
    profile        => String[1],
    url            => Stdlib::Fqdn,
    site           => Wmflib::Sites,
    Optional[port] => Stdlib::Port,
}]
