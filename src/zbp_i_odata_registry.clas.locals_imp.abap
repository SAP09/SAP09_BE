CLASS lhc_OdataRegistry DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS setDerivedFields FOR DETERMINE ON SAVE
      IMPORTING keys FOR OdataRegistry~setDerivedFields.

    METHODS validateServiceType FOR VALIDATE ON SAVE
      IMPORTING keys FOR OdataRegistry~validateServiceType.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR OdataRegistry RESULT result.
ENDCLASS.

CLASS lhc_OdataRegistry IMPLEMENTATION.

  METHOD setDerivedFields.
    GET TIME STAMP FIELD DATA(lv_now).

    READ ENTITIES OF zi_odata_registry IN LOCAL MODE
      ENTITY OdataRegistry
      FIELDS ( ServiceId ServiceType VersionNo RegisteredBy RegisteredAt )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_registry).

    " ── Collect keys by type ────────────────────────────────
    DATA lt_v2_keys TYPE zcl_odata_registry_helper=>tt_v2_keys.
    DATA lt_v4_keys TYPE zcl_odata_registry_helper=>tt_v4_keys.

    LOOP AT lt_registry ASSIGNING FIELD-SYMBOL(<ls_registry>).
      CASE <ls_registry>-ServiceType.
        WHEN '001'.
          CHECK <ls_registry>-VersionNo IS NOT INITIAL. " validation handles this case
          APPEND VALUE #(
            object_name     = <ls_registry>-ServiceId
            service_version = <ls_registry>-VersionNo )
            TO lt_v2_keys.

        WHEN '002'.
          APPEND VALUE #( group_id = <ls_registry>-ServiceId )
            TO lt_v4_keys.
      ENDCASE.
    ENDLOOP.

    " ── 2 DB calls total ────────────────────────────────────
    " V2: 1 FAE bulk SELECT on /iwfnd/i_med_srh
    " V4: 1 SELECT per row (TADIR JOIN — FAE not possible), then TADIR+TDEVC join
    DATA(lt_v2_meta) = zcl_odata_registry_helper=>fetch_v2_metadata( lt_v2_keys ).
    DATA(lt_v4_meta) = zcl_odata_registry_helper=>fetch_v4_metadata( lt_v4_keys ).

    " ── Derive and write back ────────────────────────────────
    LOOP AT lt_registry ASSIGNING <ls_registry>.

      " Preserve RegisteredBy / RegisteredAt on updates
      DATA(lv_registered_by) = COND syuname(
        WHEN <ls_registry>-RegisteredBy IS INITIAL
        THEN sy-uname
        ELSE <ls_registry>-RegisteredBy ).

      DATA(lv_registered_at) = COND timestamp(
        WHEN <ls_registry>-RegisteredAt IS INITIAL
        THEN lv_now
        ELSE <ls_registry>-RegisteredAt ).

      CASE <ls_registry>-ServiceType.
        WHEN '001'.
          READ TABLE lt_v2_meta
            WITH KEY object_name     = <ls_registry>-ServiceId
                     service_version = <ls_registry>-VersionNo
            INTO DATA(ls_v2).
          CHECK sy-subrc = 0. " not found → validation will report the error

          MODIFY ENTITIES OF zi_odata_registry IN LOCAL MODE
            ENTITY OdataRegistry
            UPDATE FIELDS ( ServiceName VersionNo Namespace Status
                            RegisteredBy RegisteredAt LastChangeAt )
            WITH VALUE #( (
              %tky         = <ls_registry>-%tky
              ServiceName  = ls_v2-service_name
              VersionNo    = ls_v2-service_version
              Namespace    = ls_v2-namespace
              Status       = 'A'
              RegisteredBy = lv_registered_by
              RegisteredAt = lv_registered_at
              LastChangeAt = lv_now ) )
            REPORTED DATA(ls_rep_dummy).

        WHEN '002'.
          READ TABLE lt_v4_meta
            WITH KEY group_id = <ls_registry>-ServiceId
            INTO DATA(ls_v4).
          CHECK sy-subrc = 0. " not found → validation will report the error

          MODIFY ENTITIES OF zi_odata_registry IN LOCAL MODE
            ENTITY OdataRegistry
            UPDATE FIELDS ( ServiceName VersionNo Namespace Status
                            RegisteredBy RegisteredAt LastChangeAt )
            WITH VALUE #( (
              %tky         = <ls_registry>-%tky
              ServiceName  = ls_v4-service_name           " = group_id, by design
              VersionNo    = COND #(
                               WHEN <ls_registry>-VersionNo IS INITIAL
                               THEN '0001'
                               ELSE <ls_registry>-VersionNo )
              Namespace    = ls_v4-namespace              " from TADIR → TDEVC
              Status       = 'A'
              RegisteredBy = lv_registered_by
              RegisteredAt = lv_registered_at
              LastChangeAt = lv_now ) )
            REPORTED DATA(ls_rep_dummy2).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.
  METHOD validateServiceType.
    READ ENTITIES OF zi_odata_registry IN LOCAL MODE
      ENTITY OdataRegistry
      FIELDS ( ServiceId ServiceType VersionNo )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_registry).

    " ── Step 1: Structural checks + collect valid keys ──────
    DATA lt_v2_keys TYPE zcl_odata_registry_helper=>tt_v2_keys.
    DATA lt_v4_keys TYPE zcl_odata_registry_helper=>tt_v4_keys.

    LOOP AT lt_registry ASSIGNING FIELD-SYMBOL(<ls_registry>).
      CASE <ls_registry>-ServiceType.
        WHEN '001'.
          IF <ls_registry>-VersionNo IS INITIAL.
            APPEND VALUE #( %tky = <ls_registry>-%tky )
              TO failed-odataregistry.
            APPEND VALUE #(
              %tky               = <ls_registry>-%tky
              %msg               = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'VersionNo is required for OData V2 service type 001.' )
              %element-VersionNo = if_abap_behv=>mk-on )
              TO reported-odataregistry.
            CONTINUE. " skip DB check — nothing valid to look up
          ENDIF.

          APPEND VALUE #(
            object_name     = <ls_registry>-ServiceId
            service_version = <ls_registry>-VersionNo )
            TO lt_v2_keys.

        WHEN '002'.
          APPEND VALUE #( group_id = <ls_registry>-ServiceId )
            TO lt_v4_keys.

        WHEN OTHERS.
          APPEND VALUE #( %tky = <ls_registry>-%tky )
            TO failed-odataregistry.
          APPEND VALUE #(
            %tky                 = <ls_registry>-%tky
            %msg                 = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = |Unsupported service type { <ls_registry>-ServiceType }. Use 001 for OData V2 or 002 for OData V4.| )
            %element-ServiceType = if_abap_behv=>mk-on )
            TO reported-odataregistry.
      ENDCASE.
    ENDLOOP.

    " ── Step 2: 2 DB calls total ────────────────────────────
    DATA(lt_v2_hits) = zcl_odata_registry_helper=>fetch_existing_v2( lt_v2_keys ).
    DATA(lt_v4_hits) = zcl_odata_registry_helper=>fetch_existing_v4( lt_v4_keys ).

    " ── Step 3: Check in memory — no more DB calls ──────────
    LOOP AT lt_registry ASSIGNING <ls_registry>.
      CASE <ls_registry>-ServiceType.
        WHEN '001'.
          CHECK <ls_registry>-VersionNo IS NOT INITIAL. " already failed in step 1

          IF zcl_odata_registry_helper=>is_v2_found(
               iv_service_id = CONV #( <ls_registry>-ServiceId )
               iv_version_no = <ls_registry>-VersionNo
               it_hits       = lt_v2_hits ) = abap_false.
            APPEND VALUE #(
              %tky        = <ls_registry>-%tky
              %fail-cause = if_abap_behv=>cause-not_found )
              TO failed-odataregistry.
            APPEND VALUE #(
              %tky                 = <ls_registry>-%tky
              %msg                 = new_message_with_text(
                                       severity = if_abap_behv_message=>severity-error
                                       text     = |404: OData V2 object { <ls_registry>-ServiceId } version { <ls_registry>-VersionNo } was not found in /IWFND/I_MED_SRH.| )
              %element-ServiceName = if_abap_behv=>mk-on
              %element-VersionNo   = if_abap_behv=>mk-on )
              TO reported-odataregistry.
          ENDIF.

        WHEN '002'.
          IF zcl_odata_registry_helper=>is_v4_found(
               iv_service_id = CONV #( <ls_registry>-ServiceId )
               it_hits       = lt_v4_hits ) = abap_false.
            APPEND VALUE #(
              %tky        = <ls_registry>-%tky
              %fail-cause = if_abap_behv=>cause-not_found )
              TO failed-odataregistry.
            APPEND VALUE #(
              %tky                 = <ls_registry>-%tky
              %msg                 = new_message_with_text(
                                       severity = if_abap_behv_message=>severity-error
                                       text     = |404: OData V4 group ID { <ls_registry>-ServiceId } was not found in /IWFND/C_V4_MSGR.| )
              %element-ServiceName = if_abap_behv=>mk-on )
              TO reported-odataregistry.
          ENDIF.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.
  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(key).

      APPEND VALUE #(
        %tky    = key-%tky
        %update = if_abap_behv=>auth-allowed
        %delete = if_abap_behv=>auth-allowed
      ) TO result.

    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
