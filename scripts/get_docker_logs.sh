#!/bin/bash

BASE_DOCKER_EXTRA="/var/log/extra/docker"

if command -v docker && systemctl is-active docker; then
    mkdir -p $BASE_DOCKER_EXTRA
    ALL_FILE=$BASE_DOCKER_EXTRA/docker_allinfo.log
    DOCKER_INFO_CMDS=(
        "docker ps --all --size"
        "docker images"
        "docker volume ls"
        "docker stats --all --no-stream"
        "docker info"
    )
    for cmd in "${DOCKER_INFO_CMDS[@]}"; do
        echo "+ $cmd" >> $ALL_FILE
        $cmd >> $ALL_FILE
    done

    for cont in $(docker ps | awk {'print $NF'} | grep -v NAMES); do
        INFO_DIR=$BASE_DOCKER_EXTRA/containers/${cont}
        mkdir -p $INFO_DIR
        INFO_FILE=$INFO_DIR/docker_info.log
        DOCKER_CONTAINER_INFO_CMDS=(
            "docker top $cont auxw"
            "docker exec $cont top -bwn1"
            "docker inspect $cont"
        )
        for cmd in "${DOCKER_CONTAINER_INFO_CMDS[@]}"; do
            echo "+ $cmd" >> $INFO_FILE
            $cmd >> $INFO_FILE
        done
        docker logs $cont > $INFO_DIR/stdout.log
        docker cp $cont:/var/lib/kolla/config_files/config.json $INFO_DIR/config.json
        # NOTE(flaper87): This should go away. Services should be
        # using a `logs` volume
        # Removing the following line as openstack infra needs our log size reduced
        # docker cp $cont:/var/log $INFO_DIR/log
        # NOTE(gfidente): Just copy Ceph
        if docker exec --user root $cont stat /var/log/ceph > /dev/null; then
            docker cp $cont:/var/log/ceph $INFO_DIR/log
        fi
        # Delete symlinks because they break log collection and are generally
        # not useful
        find $INFO_DIR -type l -delete
    done
    cp -r /var/lib/config-data/puppet-generated /var/log/config-data

    if [[ -d /var/lib/docker/volumes/logs/_data ]]; then
        cp -r /var/lib/docker/volumes/logs/_data $BASE_DOCKER_EXTRA/logs
    fi
fi
