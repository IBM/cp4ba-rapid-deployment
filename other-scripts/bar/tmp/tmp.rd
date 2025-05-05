PVC cp4a-shared-log-pvc

kind: PersistentVolumeClaim

apiVersion: v1

metadata:

  name: cp4a-shared-log-pvc

  namespace: ibm-cp4ba-2

spec:

  accessModes:

    - ReadWriteMany

  resources:

    requests:

      storage: 100Gi

  storageClassName: nfs-client

  volumeMode: Filesystem


PVC operator-shared-pvc

kind: PersistentVolumeClaim

apiVersion: v1

metadata:

  name: operator-shared-pvc

  namespace: ibm-cp4ba-2

spec:

  accessModes:

    - ReadWriteMany

  resources:

    requests:

      storage: 1Gi

  storageClassName: nfs-client

  volumeMode: Filesystem
