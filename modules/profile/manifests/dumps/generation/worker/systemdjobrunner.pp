class profile::dumps::generation::worker::systemdjobrunner(
    $php = lookup('profile::dumps::generation_worker_cron_php'),
) {
    class { '::snapshot::systemdjobs':
        miscdumpsuser => 'dumpsgen',
        group         => 'www-data',
        filesonly     => false,
        php           => $php,
    }
}
