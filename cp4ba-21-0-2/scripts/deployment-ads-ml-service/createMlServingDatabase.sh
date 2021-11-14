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

set -x

mkdir /mnt/mlserving
chown postgres:postgres /mnt/mlserving

psql -c "create database mlserving template template0 encoding UTF8"
