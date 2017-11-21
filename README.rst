======================
rabbitmq-swarm-cluster
======================

This docker image is built to get a lightweight rabbitmq cluster without any
external dependencies. It is designed to work in docker swarm mode.


Basic Concept
=============

Once the rabbitmq-server is up and running the join.sh script will try to join
this server instance to a reachable peer. Available peers are determined via
nslookup to `tasks.<SERVICE_NAME>`. If no peer is available but this container
is matches `SLOT == MASTER_SLOT` the rabbitmq app will be just started and no
further joining arithmetic will be executed on this container.
