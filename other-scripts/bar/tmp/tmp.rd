oc apply -f cr-ibm-cp4ba-qa.yaml

###############################################################################
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2022. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
###############################################################################
# Needed DBs: ICN GCD BAWDOCS BAWTOS BAWDOS BAW AE

apiVersion: icp4a.ibm.com/v1
kind: ICP4ACluster
metadata:
  name: qaenvironment
  labels:
    app.kubernetes.io/instance: ibm-dba
    app.kubernetes.io/managed-by: ibm-dba
    app.kubernetes.io/name: ibm-dba
    release: 21.0.3

spec:
  appVersion: 21.0.3
  ibm_license: accept

  shared_configuration:
    show_sensitive_log: true
    no_log: false

    sc_deployment_fncm_license: "non-production"
    sc_deployment_baw_license: "non-production"
    sc_deployment_license: "non-production"

    sc_image_repository: cp.icr.io
    root_ca_secret: icp4a-root-ca
    external_tls_certificate_secret: 

    sc_deployment_patterns: "workflow"
    sc_optional_components: ""

    sc_deployment_context: "CP4A"
    sc_deployment_type: "Production"
    sc_deployment_platform: "OCP"
    sc_deployment_hostname_suffix: "{{ meta.namespace }}.apps.ocp.ibm.edu"
    sc_install_automation_base: true
    sc_deployment_profile_size: small

    sc_ingress_enable: false
    sc_ingress_tls_secret_name: 
#    trusted_certificate_list:
      

    storage_configuration:
      sc_slow_file_storage_classname: nfs-client
      sc_medium_file_storage_classname: nfs-client
      sc_fast_file_storage_classname: nfs-client
      sc_block_storage_classname: nfs-client

    sc_cpe_limited_storage: false
    sc_run_as_user:

    images:
      # keytool_job_container:
      #   repository: cp.icr.io/cp/cp4a/ums/dba-keytool-jobcontainer
      #   tag: 21.0.3-IF010
      # dbcompatibility_init_container:
      #   repository: cp.icr.io/cp/cp4a/aae/dba-dbcompatibility-initcontainer
      #   tag: 21.0.3-IF010
      # keytool_init_container:
      #   repository: cp.icr.io/cp/cp4a/ums/dba-keytool-initcontainer
      #   tag: 21.0.3-IF010
      # umsregistration_initjob:
      #   repository: cp.icr.io/cp/cp4a/aae/dba-umsregistration-initjob
      #   tag: 21.0.3-IF010
      pull_policy: IfNotPresent

    encryption_key_secret: icp4a-shared-encryption-key

    sc_content_initialization: true
    sc_content_verification: false

    image_pull_secrets:
      - admin.registrykey

  ldap_configuration:
    lc_selected_ldap_type: "IBM Security Directory Server"
    lc_ldap_server: "10.100.1.8"
    lc_ldap_port: "389"
    lc_bind_secret: ldap-bind-secret
    lc_ldap_base_dn: "dc=example,dc=com"
    lc_ldap_ssl_enabled: false
    lc_ldap_user_name_attribute: "*:cn"
    lc_ldap_user_display_name_attr: "cn"
    lc_ldap_group_base_dn: "dc=example,dc=com"
    lc_ldap_group_name_attribute: "*:cn"
    lc_ldap_group_display_name_attr: "cn"
    lc_ldap_group_membership_search_filter: "(|(&(objectclass=groupOfNames)(member={0}))(&(objectclass=groupOfUniqueNames)(uniqueMember={0})))"
    lc_ldap_group_member_id_map: "groupofnames:member"
    lc_ldap_recursive_search: false
    lc_ldap_max_search_results: 4500
    tds:
      lc_user_filter: "(&(cn=%v)(objectclass=person))"
      lc_group_filter: "(&(cn=%v)(|(objectclass=groupofnames)(objectclass=groupofuniquenames)(objectclass=groupofurls)))"

  datasource_configuration:
    dc_ssl_enabled: false

    dc_icn_datasource:
      dc_database_type: "db2"
      dc_common_icn_datasource_name: "ECMClientDS"
      database_servername: "10.100.1.2"
      database_port: "50000"
      database_name: "ICNDB3"
      connection_manager:
        min_pool_size: 0
        max_pool_size: 100
        max_idle_time: 1m
        reap_time: 2m
        purge_policy: EntirePool

    dc_gcd_datasource:
      dc_database_type: "db2"
      dc_common_gcd_datasource_name: "FNGCDDS"
      dc_common_gcd_xa_datasource_name: "FNGCDDSXA"
      database_servername: "10.100.1.2"
      database_name: "GCDDB3"
      database_port: "50000"
      connection_manager:
        min_pool_size: 0
        max_pool_size: 100
        max_idle_time: 1m
        reap_time: 2m
        purge_policy: EntirePool

    dc_os_datasources:
      - dc_database_type: "db2"
        dc_os_label: "bawdocs"
        dc_common_os_datasource_name: "BAWDOCSDS"
        dc_common_os_xa_datasource_name: "BAWDOCSDSXA"
        database_servername: "10.100.1.2"
        database_name: "BAWDOCS3"
        database_port: "50000"
      - dc_database_type: "db2"
        dc_os_label: "bawdos"
        dc_common_os_datasource_name: "BAWDOSDS"
        dc_common_os_xa_datasource_name: "BAWDOSDSXA"
        database_servername: "10.100.1.2"
        database_name: "BAWDOS3"
        database_port: "50000"
      - dc_database_type: "db2"
        dc_os_label: "bawtos"
        dc_common_os_datasource_name: "BAWTOSDS"
        dc_common_os_xa_datasource_name: "BAWTOSDSXA"
        database_servername: "10.100.1.2"
        database_name: "BAWTOS3"
        database_port: "50000"

  ##################################################################
  ########   Resource Registry configuration                ########
  ##################################################################
  resource_registry_configuration:
#    hostname: "rr-{{ shared_configuration.sc_deployment_hostname_suffix }}"
#    port: 443
    images:
      pull_policy: IfNotPresent
      # resource_registry:
      #   repository: cp.icr.io/cp/cp4a/aae/dba-etcd
      #   tag: 21.0.3-IF010
      
    admin_secret_name: resource-registry-admin-secret
#    replica_size: 3
    probe:
      liveness:
        initial_delay_seconds: 60
        period_seconds: 10
        timeout_seconds: 5
        success_threshold: 1
        failure_threshold: 3
      readiness:
        initial_delay_seconds: 10
        period_seconds: 10
        timeout_seconds: 5
        success_threshold: 1
        failure_threshold: 3
    # resource:
    #   limits:
    #     cpu: "500m"
    #     memory: "512Mi"
    #   requests:
    #     cpu: "100m"
    #     memory: "256Mi"
    auto_backup:
      enable: true
      minimal_time_interval: 300
      pvc_name: "{{ meta.name }}-dba-rr-pvc"
      log_pvc_name: 'cp4a-shared-log-pvc'
      dynamic_provision:
        enable: true
        size: 3Gi
        size_for_logstore:
        storage_class: "{{ shared_configuration.storage_configuration.sc_fast_file_storage_classname }}"

  ########################################################################
  ########   IBM Business Automation Navigator configuration      ########
  ########################################################################
  navigator_configuration:
    ban_secret_name: ibm-ban-secret
    ban_ext_tls_secret_name: 

    arch:
      amd64: "3 - Most preferred"

#    replica_count: 1

    image:
      # repository: cp.icr.io/cp/cp4a/ban/navigator-sso
      # tag: 21.0.3-IF010
      pull_policy: IfNotPresent
    log:
      format: json
    # resources:
    #   requests:
    #     cpu: 750m
    #     memory: 1024Mi
    #   limits:
    #     cpu: 1
    #     memory: 1536Mi

    auto_scaling:
      enabled: false
      max_replicas: 1
      min_replicas: 1
      target_cpu_utilization_percentage: 80

    icn_production_setting:
      timezone: Etc/UTC
      jvm_initial_heap_percentage: 40
      jvm_max_heap_percentage: 66

      jvm_customize_options:

      icn_jndids_name: ECMClientDS
      icn_schema: ICNDB3
      icn_table_space: ICNDB3
      allow_remote_plugins_via_http: false

    monitor_enabled: false
    logging_enabled: false

    datavolume:
      existing_pvc_for_icn_cfgstore: "icn-cfgstore"
      existing_pvc_for_icn_logstore: "icn-logstore"
      existing_pvc_for_icn_pluginstore: "icn-pluginstore"
      existing_pvc_for_icnvw_cachestore: "icn-vw-cachestore"
      existing_pvc_for_icnvw_logstore: "icn-vw-logstore"
      existing_pvc_for_icn_aspera: "icn-asperastore"

    probe:
      readiness:
        initial_delay_seconds: 120
        period_seconds: 5
        timeout_seconds: 10
        failure_threshold: 6
      liveness:
        initial_delay_seconds: 600
        period_seconds: 5
        timeout_seconds: 5
        failure_threshold: 6

  ########################################################################
  ########      IBM FileNet Content Manager configuration         ########
  ########################################################################
  ecm_configuration:
    fncm_secret_name: ibm-fncm-secret
    fncm_ext_tls_secret_name: 
    route_ingress_annotations:

    ####################################
    ## Start of configuration for CPE ##
    ####################################
    cpe:
      arch:
        amd64: "3 - Most preferred"

#      replica_count: 1

      image:
        # repository: cp.icr.io/cp/cp4a/fncm/cpe
        # tag: 21.0.3-IF010
        pull_policy: IfNotPresent

      log:
       format: json

      # resources:
      #   requests:
      #     cpu: 1
      #     memory: 1024Mi
      #   limits:
      #     cpu: 2
      #     memory: 3072Mi

      auto_scaling:
        enabled: false
        max_replicas: 1
        min_replicas: 1
        target_cpu_utilization_percentage: 80

      cpe_production_setting:
        time_zone: Etc/UTC
        jvm_initial_heap_percentage: 18
        jvm_max_heap_percentage: 80
        jvm_customize_options:

        gcd_jndi_name: FNGCDDS
        gcd_jndixa_name: FNGCDDSXA
        license_model: FNCM.PVUNonProd
        license: accept
        disable_fips: false

      monitor_enabled: false
      logging_enabled: false

      collectd_enable_plugin_write_graphite: false

      datavolume:
        existing_pvc_for_cpe_cfgstore: "cpe-cfgstore"
        existing_pvc_for_cpe_logstore: "cpe-logstore"
        existing_pvc_for_cpe_filestore: "cpe-filestore"
        existing_pvc_for_cpe_icmrulestore: "cpe-icmrulesstore"
        existing_pvc_for_cpe_textextstore: "cpe-textextstore"
        existing_pvc_for_cpe_bootstrapstore: "cpe-bootstrapstore"
        existing_pvc_for_cpe_fnlogstore: "cpe-fnlogstore"

      probe:
        readiness:
          initial_delay_seconds: 180
          period_seconds: 30
          timeout_seconds: 10
          failure_threshold: 6
        liveness:
          initial_delay_seconds: 600
          period_seconds: 30
          timeout_seconds: 5
          failure_threshold: 6

    ####################################
    ## Start of configuration for CSS ##
    ####################################
    css:
      arch:
        amd64: "3 - Most preferred"

      replica_count: 1

      image:
        # repository: cp.icr.io/cp/cp4a/fncm/css
        # tag: 21.0.3-IF010
        pull_policy: IfNotPresent

      log:
        format: json

      # resources:
      #   requests:
      #     cpu: 250m
      #     memory: 512Mi
      #   limits:
      #     cpu: 500m
      #     memory: 4096Mi

      css_production_setting:
        jvm_max_heap_percentage: 50
        license: accept

      monitor_enabled: false
      logging_enabled: false
      collectd_enable_plugin_write_graphite: false

      datavolume:
        existing_pvc_for_css_cfgstore: "css-cfgstore"
        existing_pvc_for_css_logstore: "css-logstore"
        existing_pvc_for_css_tmpstore: "css-tempstore"
        existing_pvc_for_index: "css-indexstore"
        existing_pvc_for_css_customstore: "css-customstore"

      probe:
        readiness:
          initial_delay_seconds: 60
          period_seconds: 10
          timeout_seconds: 10
          failure_threshold: 6
        liveness:
          initial_delay_seconds: 180
          period_seconds: 10
          timeout_seconds: 5
          failure_threshold: 6

    #####################################
    ## Start of configuration for CMIS ##
    #####################################
    cmis:
      arch:
        amd64: "3 - Most preferred"

#      replica_count: 1

      image:
        # repository: cp.icr.io/cp/cp4a/fncm/cmis
        # tag: 21.0.3-IF010
        pull_policy: IfNotPresent

      log:
        format: json

      # resources:
      #   requests:
      #     cpu: 500m
      #     memory: 256Mi
      #   limits:
      #     cpu: 1
      #     memory: 1536Mi

      auto_scaling:
        enabled: false
        max_replicas: 2
        min_replicas: 2
        target_cpu_utilization_percentage: 80

      cmis_production_setting:
        cpe_url:
        time_zone: Etc/UTC
        jvm_initial_heap_percentage: 40
        jvm_max_heap_percentage: 66
        jvm_customize_options:

        disable_fips: false
        ws_security_enabled: false
        checkout_copycontent: true
        default_maxitems: 25

        cvl_cache: true
        secure_metadata_cache: false
        filter_hidden_properties: true
        querytime_limit: 180
        resumable_queries_forrest: true
        escape_unsafe_string_characters: false
        max_soap_size: 180
        print_pull_stacktrace: false
        folder_first_search: false
        ignore_root_documents: false
        supporting_type_mutability: false

        license: accept

      monitor_enabled: false
      logging_enabled: false
      collectd_enable_plugin_write_graphite: false

      datavolume:
        existing_pvc_for_cmis_cfgstore: "cmis-cfgstore"
        existing_pvc_for_cmis_logstore: "cmis-logstore"

      probe:
        readiness:
          initial_delay_seconds: 90
          period_seconds: 10
          timeout_seconds: 10
          failure_threshold: 6
        liveness:
          initial_delay_seconds: 180
          period_seconds: 10
          timeout_seconds: 5
          failure_threshold: 6

  ########################################################################
  ######## IBM FileNet Content Manager Initialization configuration ######
  ########################################################################
  initialize_configuration:
    ic_domain_creation:
      domain_name: "CP4BADOM"
      encryption_key: "128"

    ic_ldap_creation:
      ic_ldap_admin_user_name:
        - "cp4badmin"
      ic_ldap_admins_groups_name:
        - "cp4badmins"
      ic_ldap_name: "ldap_custom"

    ic_obj_store_creation:
      object_stores:
        - oc_cpe_obj_store_display_name: "BAWDOCS"
          oc_cpe_obj_store_symb_name: "BAWDOCS"
          oc_cpe_obj_store_conn:
            dc_os_datasource_name: "BAWDOCSDS"
            dc_os_xa_datasource_name: "BAWDOCSDSXA"
          oc_cpe_obj_store_admin_user_groups:
            - "cp4badmins"
            - "cp4badmin"
          oc_cpe_obj_store_basic_user_groups:
            - "cp4bausers"
          oc_cpe_obj_store_enable_content_event_emitter: false
        - oc_cpe_obj_store_display_name: "BAWDOS"
          oc_cpe_obj_store_symb_name: "BAWDOS"
          oc_cpe_obj_store_conn:
            dc_os_datasource_name: "BAWDOSDS"
            dc_os_xa_datasource_name: "BAWDOSDSXA"
          oc_cpe_obj_store_admin_user_groups:
            - "cp4badmins"
            - "cp4badmin"
          oc_cpe_obj_store_basic_user_groups:
            - "cp4bausers"
          oc_cpe_obj_store_enable_content_event_emitter: false
        - oc_cpe_obj_store_display_name: "BAWTOS"
          oc_cpe_obj_store_symb_name: "BAWTOS"
          oc_cpe_obj_store_conn:
            dc_os_datasource_name: "BAWTOSDS"
            dc_os_xa_datasource_name: "BAWTOSDSXA"
          oc_cpe_obj_store_admin_user_groups:
            - "cp4badmins"
            - "cp4badmin"
            - "cp4bausers"
          oc_cpe_obj_store_enable_content_event_emitter: false
          oc_cpe_obj_store_enable_workflow: true
          oc_cpe_obj_store_workflow_region_name: "bawtos_region_name"
          oc_cpe_obj_store_workflow_region_number: 1
          oc_cpe_obj_store_workflow_data_tbl_space: "BAWTOS3_DATA_TBS"
          oc_cpe_obj_store_workflow_admin_group: "cp4badmins"
          oc_cpe_obj_store_workflow_config_group: "cp4bausers"
          oc_cpe_obj_store_workflow_pe_conn_point_name: "pe_conn_bawtos"

   #############################################################################
  ######## IBM Business Automation Application server  configurations  ########
  #############################################################################
  application_engine_configuration:
    - name: workspace
      images:
        pull_policy: IfNotPresent
        # solution_server:
        #   repository: cp.icr.io/cp/cp4a/aae/solution-server
        #   tag: 21.0.3-IF010
        # db_job:
        #   repository: cp.icr.io/cp/cp4a/aae/solution-server-helmjob-db
        #   tag: 21.0.3-IF010

      hostname: "{{ 'ae-workspace-' + shared_configuration.sc_deployment_hostname_suffix }}"
      port: 443

      admin_secret_name: "icp4adeploy-workspace-aae-app-engine-admin-secret"
      admin_user: "cp4badmin"
      external_tls_secret: 
      external_connection_timeout: 90s

#      replica_size: 1

      data_persistence:
        enable: false

      use_custom_jdbc_drivers: false
      service_type: Route

      autoscaling:
        enabled: false
        max_replicas: 2
        min_replicas: 2
        target_cpu_utilization_percentage: 80

      server_identifier: ""

      database:
        host: "10.100.1.2"
        name: "AEDB3"
        port: "50000"
        type: db2
        enable_ssl: false

        current_schema: DBASB
        initial_pool_size: 1
        max_pool_size: 100
        max_lru_cache_size: 1000
        max_lru_cache_age: 600000
        dbcompatibility_max_retries: 30
        dbcompatibility_retry_interval: 10
        custom_jdbc_pvc:

      log_level:
        node: warn
        browser: 2

      content_security_policy:
        enable: false
        whitelist:
        frame_ancestor:

      env:
        max_size_lru_cache_rr: 1000
        server_env_type: development
        purge_stale_apps_interval: 86400000
        apps_threshold: 100
        stale_threshold: 172800000
        service_threshold: 100
        service_stale_threshold: 172800000
        connection_timeout: 1200000
        uv_thread_pool_size: 40

      max_age:
        auth_cookie: "900000"
        csrf_cookie: "3600000"
        static_asset: "2592000"
        hsts_header: "2592000"

      probe:
        liveness:
          failure_threshold: 5
          initial_delay_seconds: 60
          period_seconds: 10
          success_threshold: 1
          timeout_seconds: 180
        readiness:
          failure_threshold: 5
          initial_delay_seconds: 10
          period_seconds: 10
          success_threshold: 1
          timeout_seconds: 180

      # resource_ae:
      #   limits:
      #     cpu: 1000m
      #     memory: 2Gi
      #   requests:
      #     cpu: 300m
      #     memory: 256Mi

      # resource_init:
      #   limits:
      #     cpu: 500m
      #     memory: 256Mi
      #   requests:
      #     cpu: 100m
      #     memory: 128Mi

      session:
        check_period: "3600000"
        duration: "1800000"
        max: "10000"
        resave: "false"
        rolling: "true"
        save_uninitialized: "false"
        use_external_store: "false"

#      tls:
#        tls_trust_list: []

      share_storage:
        enabled: true
        auto_provision:
          enabled: true
          storage_class: "{{ shared_configuration.storage_configuration.sc_fast_file_storage_classname }}"
          size: 20Gi

      log_storage:
        enabled: true
        pvc_name: 'cp4a-shared-log-pvc'
        log_file_size: '20M'
        log_rotate_size: 5
        auto_provision:
          enabled: true
          storage_class: "{{ shared_configuration.storage_configuration.sc_fast_file_storage_classname }}"
          size: '5Gi'

  ##############################################################################
  ########   IBM BAW configuration     ########
  ##############################################################################
  baw_configuration:
  - name: instance1
  #  service_type: "Route"
  # hostname: "{{ 'bawaut-' + shared_configuration.sc_deployment_hostname_suffix }}"
  #  port: 443
  #  nodeport: 30026

#    replicas: 1

    admin_user: "cp4badmin"
    admin_secret_name: "ibm-bawaut-admin-secret"
    capabilities: workflow

    monitor_enabled: false
    external_connection_timeout: ""
    external_tls_secret: 
    external_tls_ca_secret:

#    tls:
#      tls_secret_name: ibm-baw-tls - we don't have this secret yet
#      tls_trust_list: 
#      tls_trust_store: 

    image:
      # repository: cp.icr.io/cp/cp4a/bas/workflow-authoring
      # tag: 21.0.3-IF010
      pullPolicy: IfNotPresent

    pfs_bpd_database_init_job:
      # repository: cp.icr.io/cp/cp4a/baw/pfs-bpd-database-init-prod
      # tag: 21.0.3-IF010
      pullPolicy: IfNotPresent

    upgrade_job:
      # repository: cp.icr.io/cp/cp4a/baw/workflow-server-dbhandling
      # tag: 21.0.3-IF010
      pullPolicy: IfNotPresent

    bas_auto_import_job:
      # repository: cp.icr.io/cp/cp4a/baw/toolkit-installer
      # tag: 21.0.3-IF010
      pullPolicy: IfNotPresent

    ibm_workplace_job:
      # repository: cp.icr.io/cp/cp4a/baw/iaws-ibm-workplace
      # tag: 21.0.3-IF010
      pull_policy: IfNotPresent

    database:
      enable_ssl: false
      db_cert_secret_name:

      type: "db2"
      server_name: "10.100.1.2"
      database_name: "BAWDB3"
      port: "50000"
      secret_name: "ibm-bawaut-server-db-secret"

      jdbc_driver_files: 'db2jcc4.jar db2jcc_license_cu.jar'

      cm_max_pool_size: 200
      dbcheck:
        wait_time: 900
        interval_time: 15

    content_integration:
      init_job_image:
        # repository: cp.icr.io/cp/cp4a/baw/iaws-ps-content-integration
        # tag: 21.0.3-IF010
        pull_policy: IfNotPresent

      domain_name: "CP4BADOM"
      object_store_name: "BAWDOCS"
      cpe_admin_secret: "ibm-fncm-secret"

    case:
      init_job_image:
        # repository: cp.icr.io/cp/cp4a/baw/workflow-server-case-initialization
        # tag: 21.0.3-IF010
        pull_policy: IfNotPresent

      domain_name: "CP4BADOM"
      object_store_name_dos: "BAWDOS"
      object_store_name_tos: "BAWTOS"
      connection_point_name_tos: "pe_conn_bawtos"
      target_environment_name: "dev_env_connection_definition"

      network_shared_directory_pvc: "{{ navigator_configuration.datavolume.existing_pvc_for_icn_pluginstore | default('icn-pluginstore', true) }}"
      custom_package_names: ""
      custom_extension_names: ""

      #event_emitter:
       # date_sql:
        #logical_unique_id:
        #solution_list:
#        emitter_batch_size: 
#        process_pe_events: 

    # resources_init:
    #   limits:
    #     cpu: "500m"
    #     memory: 256Mi
    #   requests:
    #     cpu: "200m"
    #     memory: 128Mi

    # resources_init_heavy_job:
    #   limits:
    #     cpu: 1
    #     memory: 1536Mi
    #   requests:
    #     cpu: "500m"
    #     memory: 512Mi

    jms:
      image:
        # repository: cp.icr.io/cp/cp4a/baw/jms
        # tag: 21.0.3-IF010
        pull_policy: IfNotPresent
#      tls:
#        tls_secret_name: ibm-jms-tls-secret - we don't have this secret yet
      # resources:
      #   limits:
      #     memory: "2Gi"
      #     cpu: "1000m"
      #   requests:
      #     memory: "512Mi"
      #     cpu: "200m"
      storage:
        persistent: true
        size: "1Gi"
        use_dynamic_provisioning: true
        access_modes:
          - ReadWriteOnce
        storage_class: "{{ shared_configuration.storage_configuration.sc_fast_file_storage_classname }}"
      liveness_probe:
        initial_delay_seconds: 180
        period_seconds: 20
        timeout_seconds: 10
        failure_threshold: 3
        success_threshold: 1
      readiness_probe:
        initial_delay_seconds: 30
        period_seconds: 5
        timeout_seconds: 5
        failure_threshold: 6
        success_threshold: 1

    resources:
      limits:
        cpu: '4'
        memory: 6Gi
      requests:
        cpu: "500m"
        memory: 2250Mi

    probe:
      ws:
        liveness_probe:
          initial_delay_seconds: 300
          period_seconds: 10
          timeout_seconds: 10
          failure_threshold: 3
          success_threshold: 1
        readinessProbe:
          initial_delay_seconds: 240
          period_seconds: 5
          timeout_seconds: 5
          failure_threshold: 6
          success_threshold: 1

    logs:
      console_format: "json"
      console_log_level: "WARNING"
      console_source: "message,trace,accessLog,ffdc,audit"
      message_format: "SIMPLE"
      trace_format: "ENHANCED"
      trace_specification: "*=warning"
      max_files: 10
      max_filesize: 50

    storage:
      use_dynamic_provisioning: true
      existing_pvc_for_logstore: ""
      size_for_logstore: "10Gi"
      existing_pvc_for_dumpstore: ""
      size_for_dumpstore: "10Gi"
      existing_pvc_for_filestore: ""
      size_for_filestore: "10Gi"
      existing_pvc_for_indexstore: ""
      size_for_indexstore: "10Gi"

    autoscaling:
      enabled: false
      max_replicas: 1
      min_replicas: 1
      target_cpu_utilization_percentage: 80

    environment_config:
      show_task_prioritization_service_toggle: true
      always_run_task_prioritization_service: false

    federation_config:
      workflow_server:
          index_number_of_shards: 3
          index_number_of_replicas: 1
      case_manager:
        - object_store_name: BAWTOS
          index_number_of_shards: 3
          index_number_of_replicas: 1

#    jvm_customize_options: -Xmx10240m -Xmn4096m
#    liberty_custom_xml:
#    custom_xml_secret_name:
#    lombardi_custom_xml_secret_name:

 #   business_event:
 #     enable: false
 #     enable_task_record: false
 #     enable_task_api: false
 #     subscription:
 #       - {'app_name': '*','version': '*','component_type': '*','component_name': '*','element_type': '*','element_name': '*','nature': '*'}

  ########################################################################
  ########   IBM Process Federation Server configuration          ########
  ########################################################################
  pfs_configuration:
    hostname: "{{ 'pfs-' + shared_configuration.sc_deployment_hostname_suffix }}"
    port: 443
    service_type: Route

    image:
      # repository: cp.icr.io/cp/cp4a/baw/pfs-prod
      # tag: "21.0.3-IF010"
      pull_policy: IfNotPresent

#    replicas: 1

    service_account:
    anti_affinity: hard
    enable_notification_server: true
    enable_default_security_roles: true
    admin_secret_name: ibm-pfs-admin-secret
    config_dropins_overrides_secret: ""
    resources_security_secret: ""
    custom_libs_pvc: ""
    external_tls_secret: 
    external_tls_ca_secret:
    monitor_enabled: false

    tls:
      tls_secret_name:
      tls_trust_list:
      tls_trust_store:

    # resources:
    #   requests:
    #     cpu: 500m
    #     memory: 512Mi
    #   limits:
    #     cpu: 2
    #     memory: 4Gi

    liveness_probe:
      initial_delay_seconds: 300

    readiness_probe:
      initial_delay_seconds: 240

    saved_searches:
      index_name: ibmpfssavedsearches
      index_number_of_shards: 3
      index_number_of_replicas: 1
      index_batch_size: 100
      update_lock_expiration: 5m
      unique_constraint_expiration: 5m

    security:
      sso:
        domain_name:
        cookie_name: "ltpatoken2"
        ltpa:
          filename: "ltpa.keys"
          expiration: "120m"
          monitor_interval: "60s"
      ssl_protocol: SSL

    executor:
      max_threads: "80"
      core_threads: "40"

    rest:
      user_group_check_interval: "300s"
      system_status_check_interval: "60s"
      bd_fields_check_interval: "300s"

    custom_env_variables:
      names:
      #  - name: MY_CUSTOM_ENVIRONMENT_VARIABLE
      secret:

    logs:
      console_format: "json"
      console_log_level: "WARNING"
      console_source: "message,trace,accessLog,ffdc,audit"
      message_format: "SIMPLE"
      trace_format: "ENHANCED"
      trace_specification: "*=warning"
      storage:
        use_dynamic_provisioning: true
        size: 5Gi
        storage_class: "{{ shared_configuration.storage_configuration.sc_medium_file_storage_classname }}"
        existing_pvc_name: ""

    dba_resource_registry:
      lease_ttl: 120
      pfs_check_interval: 10
      pfs_connect_timeout: 10
      pfs_response_timeout: 30
      pfs_registration_key: /dba/appresources/IBM_PFS/PFS_SYSTEM
      # resources:
      #   limits:
      #     memory: '512Mi'
      #     cpu: '500m'
      #   requests:
      #     memory: '512Mi'
      #     cpu: '200m'
