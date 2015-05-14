#!/bin/bash
##########################################################################
# Module:	mongodb_rs_init
# Description:	Initiates MongoDB replica set 
##########################################################################

ANSWERS=/root/bashstack/answers.txt

if [[ ! -f $ANSWERS ]] ; then
  echo "Answer file ($ANSWERS) does not exist.  Exiting."
else
  source $ANSWERS
fi

if [[ $ha == "y" ]]; then
  if [[ $(hostname -s) == "$mongo_bootstrap_node" ]]; then
    rm -f /root/mongo_replica_setup.js
    cat > /root/mongo_replica_setup.js << EOF
rs.initiate()
sleep(10000)
EOF

    for node in $mongo_nodes; do
    cat >> /root/mongo_replica_setup.js << EOF
      rs.add("$node");
EOF
    done

    mongo /root/mongo_replica_setup.js
    rm -f /root/mongo_replica_setup.js
  fi
fi



