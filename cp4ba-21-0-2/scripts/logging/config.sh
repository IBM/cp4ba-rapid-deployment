#! /bin/sh


## Number of Elasticsearch nodes. For high availability use at least 3 nodes. 
paramElasticSearchNodeCount=3

## Storage class used to persist logging 
paramClusterLoggingStorageClass=ibmc-block-gold

## The maximum size of the buffer, which is the total size of the stage and the queue. 
## If the buffer size exceeds this value, Fluentd stops adding data to chunks and fails with an error. 
## All data not in chunks is lost.
paramFluentdBufferTotalLimitSize=8G


## The number of threads that perform chunk flushing. 
## Increasing the number of threads improves the flush throughput, which hides network latency.
paramFluentDBufferFlushThreadCount=4
