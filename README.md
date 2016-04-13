# sideq
A CLI interface to the sidekiq api

# usage
    sideq --help

    Usage: sideq [options] command [subcommand]

    Commands and subcommands:
    stats                    Print sidekiq statistics
    queue list               List all known queues
    retry list               List contents of the retry set
    retry show jid [jid ...] Show details of entrie sin the retry set
    retry del jid [jid ...]  Delete entries from the retry set
    retry kill jid [jid ...] Move jobs from the retry set to the dead set
    retry now jid [jid ...]  Retry jobs in the retry set right now
    retry clear              Clears all entries in the retry set
    dead list                List contents of the dead set
    dead show jid [jid...]   Show details of entries in the dead set
    dead del jid [jid...]    Delete jobs from the dead set
    dead now jid [jid...]    Retry jobs from the dead set right now
    dead clear               Clears all entries of the dead set
    processes list           Lists all processes known to sidekiq
    processes quiet          Send the quiet signal to all sidekiq processes
    processes kill           Send the kill signal to all sidekiq processes
    processes clean          Clear dead process entries from the process list
    workers list             List all workers

    Options:
        -n, --database=redisdb           Number of the redis database
        -h, --host=hostname              Hostname of the redis instance
        -p, --port=port                  Portnumber of the redis instance
        -u, --url redis_url              URL to connect to (redis://host:port/db)
            --help                       Prints this help
