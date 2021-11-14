#! /bin/sh
###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2021. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
mv /usr/local/bin/podman /usr/local/bin/podman.bak
cat << 'EOF' > /usr/local/bin/podman
#! /bin/sh
true
EOF
chmod 755 /usr/local/bin/podman
