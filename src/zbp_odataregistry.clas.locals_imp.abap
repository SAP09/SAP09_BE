*"* use this source file for the definition and implementation of
*"* local helper classes, interface definitions and type definitions

"──────────────────────────────────────────────────────────────────────────────
" LOCAL CLASS: lhc_Registry
" Handles behavior for ZI_ODATA_REGISTRY
"──────────────────────────────────────────────────────────────────────────────
CLASS lhc_Registry DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS:
      " Validations
      validateServiceName FOR VALIDATE ON SAVE
        IMPORTING keys FOR Registry~validateServiceName,

      validateServiceType FOR VALIDATE ON SAVE
        IMPORTING keys FOR Registry~validateServiceType,

      " Determinations
      setServiceId FOR DETERMINE ON MODIFY
        IMPORTING keys FOR Registry~setServiceId,

      setRegisteredByAt FOR DETERMINE ON MODIFY
        IMPORTING keys FOR Registry~setRegisteredByAt,

      " Custom action
      createVersion FOR ACTION
        IMPORTING keys FOR Registry~createVersion
        RESULT    result,

      " Authorization
      get_instance_authorizations FOR INSTANCE AUTHORIZATION
        IMPORTING keys REQUEST requested_authorizations
        RESULT    result.

ENDCLASS.

CLASS lhc_Registry IMPLEMENTATION.

  "──────────────────────────────────────────────────────────────────────────
  " DETERMINATION: setServiceId
  " Generates a UUID-based ServiceId on create if not yet set
  "──────────────────────────────────────────────────────────────────────────
  METHOD setServiceId.
    READ ENTITIES OF zi_odata_registry IN LOCAL MODE
      ENTITY Registry
        FIELDS ( ServiceId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_registry)
      FAILED DATA(failed).

    LOOP AT lt_registry ASSIGNING FIELD-SYMBOL(<ls_reg>)
         WHERE ServiceId IS INITIAL.
      MODIFY ENTITIES OF zi_odata_registry IN LOCAL MODE
        ENTITY Registry
          UPDATE FIELDS ( ServiceId )
          WITH VALUE #( ( %tky      = <ls_reg>-%tky
                          ServiceId = cl_system_uuid=>create_uuid_c32_static( ) ) ).
    ENDLOOP.
  ENDMETHOD.

  "──────────────────────────────────────────────────────────────────────────
  " DETERMINATION: setRegisteredByAt
  " Sets RegisteredBy = sy-uname and RegisteredAt = current UTC timestamp
  "──────────────────────────────────────────────────────────────────────────
  METHOD setRegisteredByAt.
    READ ENTITIES OF zi_odata_registry IN LOCAL MODE
      ENTITY Registry
        FIELDS ( RegisteredBy RegisteredAt )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_registry).

    LOOP AT lt_registry ASSIGNING FIELD-SYMBOL(<ls_reg>)
         WHERE RegisteredBy IS INITIAL.
      DATA(lv_ts) = cl_abap_context_info=>get_system_date( ) && cl_abap_context_info=>get_system_time( ).
      MODIFY ENTITIES OF zi_odata_registry IN LOCAL MODE
        ENTITY Registry
          UPDATE FIELDS ( RegisteredBy RegisteredAt )
          WITH VALUE #( ( %tky         = <ls_reg>-%tky
                          RegisteredBy = sy-uname
                          RegisteredAt = CONV #( lv_ts ) ) ).
    ENDLOOP.
  ENDMETHOD.

  "──────────────────────────────────────────────────────────────────────────
  " VALIDATION: validateServiceName
  " ServiceName must not be initial
  "──────────────────────────────────────────────────────────────────────────
  METHOD validateServiceName.
    READ ENTITIES OF zi_odata_registry IN LOCAL MODE
      ENTITY Registry
        FIELDS ( ServiceName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_registry).

    LOOP AT lt_registry ASSIGNING FIELD-SYMBOL(<ls_reg>).
      IF <ls_reg>-ServiceName IS INITIAL.
        APPEND VALUE #( %tky = <ls_reg>-%tky ) TO failed-registry.
        APPEND VALUE #( %tky              = <ls_reg>-%tky
                        %state_area       = 'VALIDATE_SERVICE_NAME'
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = 'Service Name must not be empty' )
                        %element-ServiceName = if_abap_behv=>mk-on ) TO reported-registry.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  "──────────────────────────────────────────────────────────────────────────
  " VALIDATION: validateServiceType
  " ServiceType must not be initial
  "──────────────────────────────────────────────────────────────────────────
  METHOD validateServiceType.
    READ ENTITIES OF zi_odata_registry IN LOCAL MODE
      ENTITY Registry
        FIELDS ( ServiceType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_registry).

    LOOP AT lt_registry ASSIGNING FIELD-SYMBOL(<ls_reg>).
      IF <ls_reg>-ServiceType IS INITIAL.
        APPEND VALUE #( %tky = <ls_reg>-%tky ) TO failed-registry.
        APPEND VALUE #( %tky               = <ls_reg>-%tky
                        %state_area        = 'VALIDATE_SERVICE_TYPE'
                        %msg               = new_message_with_text(
                                               severity = if_abap_behv_message=>severity-error
                                               text     = 'OData Type (V2/V4) must be specified' )
                        %element-ServiceType = if_abap_behv=>mk-on ) TO reported-registry.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  "──────────────────────────────────────────────────────────────────────────
  " ACTION: createVersion
  " Creates a new immutable version (snapshot) record for the service
  "──────────────────────────────────────────────────────────────────────────
  METHOD createVersion.
    " Read current registry data
    READ ENTITIES OF zi_odata_registry IN LOCAL MODE
      ENTITY Registry
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_registry).

    " Read existing versions to determine next SnapshotVersion number
    READ ENTITIES OF zi_odata_registry IN LOCAL MODE
      ENTITY Registry BY \_Version
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_versions).

    LOOP AT lt_registry ASSIGNING FIELD-SYMBOL(<ls_reg>).
      " Calculate next snapshot version number
      DATA(lv_max_ver) = REDUCE #(
        INIT max TYPE n LENGTH 6
        FOR  ver IN lt_versions
        WHERE ( ServiceId = <ls_reg>-ServiceId )
        NEXT max = COND #( WHEN ver-SnapshotVersion > max THEN ver-SnapshotVersion ELSE max )
      ).
      DATA(lv_new_ver) = lv_max_ver + 1.

      " Create the new version child entity
      MODIFY ENTITIES OF zi_odata_registry IN LOCAL MODE
        ENTITY Registry
          CREATE BY \_Version
          FIELDS ( SnapshotId SnapshotVersion SnapshotBy SnapshotAt TriggerType IsChanged )
          WITH VALUE #( ( %tky            = <ls_reg>-%tky
                          %target = VALUE #( (
                            SnapshotId      = cl_system_uuid=>create_uuid_c32_static( )
                            SnapshotVersion = lv_new_ver
                            SnapshotBy      = sy-uname
                            SnapshotAt      = cl_abap_context_info=>get_system_date( ) &&
                                              cl_abap_context_info=>get_system_time( )
                            TriggerType     = 'M'   " M = Manual
                            IsChanged       = abap_true
                          ) ) ) )
        REPORTED DATA(ls_reported).

      " Return the updated registry record as action result
      APPEND VALUE #( %tky = <ls_reg>-%tky ) TO result.
    ENDLOOP.
  ENDMETHOD.

  "──────────────────────────────────────────────────────────────────────────
  " AUTHORIZATION: get_instance_authorizations
  " Placeholder – extend with real authorization object checks as needed
  "──────────────────────────────────────────────────────────────────────────
  METHOD get_instance_authorizations.
    " No restrictions – grant all requested authorizations by default
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<key>).
      APPEND VALUE #(
        %tky                           = <key>-%tky
        %update                        = if_abap_behv=>auth-allowed
        %delete                        = if_abap_behv=>auth-allowed
        %action-createVersion          = if_abap_behv=>auth-allowed
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
