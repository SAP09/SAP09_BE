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
      FIELDS ( ServiceId ServiceName ServiceType VersionNo RegisteredBy RegisteredAt LastChangeAt )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_registry).

    LOOP AT lt_registry ASSIGNING FIELD-SYMBOL(<ls_registry>).
      DATA(lv_registered_by) = COND syuname( WHEN <ls_registry>-RegisteredBy IS INITIAL THEN sy-uname ELSE <ls_registry>-RegisteredBy ).
      DATA(lv_registered_at) = COND timestamp( WHEN <ls_registry>-RegisteredAt IS INITIAL THEN lv_now ELSE <ls_registry>-RegisteredAt ).

      CASE <ls_registry>-ServiceType.
        WHEN '001'.
          SELECT SINGLE service_name,
                        service_version,
                        namespace,
                        object_name
            FROM /iwfnd/i_med_srh
            WHERE object_name     = @<ls_registry>-ServiceId
              AND service_version = @<ls_registry>-VersionNo
            INTO @DATA(ls_v2).

          IF sy-subrc = 0.
            MODIFY ENTITIES OF zi_odata_registry IN LOCAL MODE
              ENTITY OdataRegistry
              UPDATE FIELDS ( ServiceName VersionNo Namespace Status RegisteredBy RegisteredAt LastChangeAt )
              WITH VALUE #(
                ( %tky         = <ls_registry>-%tky
                  ServiceName  = ls_v2-service_name
                  VersionNo    = ls_v2-service_version
                  Namespace    = ls_v2-namespace
                  Status       = 'A'
                  RegisteredBy = lv_registered_by
                  RegisteredAt = lv_registered_at
                  LastChangeAt = lv_now ) ).
          ENDIF.

        WHEN '002'.
          SELECT SINGLE group_id
            FROM /iwfnd/c_v4_msgr
            WHERE group_id = @<ls_registry>-ServiceId
            INTO @DATA(lv_group_id).

          IF sy-subrc = 0.
            SELECT SINGLE a~devclass,
                          b~namespace
              FROM tadir AS a
              INNER JOIN tdevc AS b ON a~devclass = b~devclass
              WHERE a~pgmid    = 'R3TR'
                AND a~object   = 'SRVB'
                AND a~obj_name = @lv_group_id
              INTO @DATA(ls_v4_namespace).

            MODIFY ENTITIES OF zi_odata_registry IN LOCAL MODE
              ENTITY OdataRegistry
              UPDATE FIELDS ( ServiceName VersionNo Namespace Status RegisteredBy RegisteredAt LastChangeAt )
              WITH VALUE #(
                ( %tky         = <ls_registry>-%tky
                  ServiceName  = lv_group_id
                  VersionNo    = COND #( WHEN <ls_registry>-VersionNo IS INITIAL THEN '0001' ELSE <ls_registry>-VersionNo )
                  Namespace    = ls_v4_namespace-namespace
                  Status       = 'A'
                  RegisteredBy = lv_registered_by
                  RegisteredAt = lv_registered_at
                  LastChangeAt = lv_now ) ).
          ENDIF.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateServiceType.
    READ ENTITIES OF zi_odata_registry IN LOCAL MODE
      ENTITY OdataRegistry
      FIELDS ( ServiceId ServiceName ServiceType VersionNo )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_registry).

    LOOP AT lt_registry ASSIGNING FIELD-SYMBOL(<ls_registry>).
      CASE <ls_registry>-ServiceType.
        WHEN '001'.
          IF <ls_registry>-VersionNo IS INITIAL.
            APPEND VALUE #( %tky = <ls_registry>-%tky ) TO failed-odataregistry.
            APPEND VALUE #(
              %tky = <ls_registry>-%tky
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = 'VersionNo is required for OData V2 service type 001.' )
              %element-VersionNo = if_abap_behv=>mk-on )
              TO reported-odataregistry.
            CONTINUE.
          ENDIF.

          SELECT SINGLE object_name
            FROM /iwfnd/i_med_srh
            WHERE object_name     = @<ls_registry>-ServiceId
              AND service_version = @<ls_registry>-VersionNo
            INTO @DATA(lv_v2_object_name).

          IF sy-subrc <> 0.
            APPEND VALUE #( %tky = <ls_registry>-%tky
                            %fail-cause = if_abap_behv=>cause-not_found )
              TO failed-odataregistry.
            APPEND VALUE #(
              %tky = <ls_registry>-%tky
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = |404: OData V2 object { <ls_registry>-ServiceId } version { <ls_registry>-VersionNo } was not found in /IWFND/I_MED_SRH.| )
              %element-ServiceName = if_abap_behv=>mk-on
              %element-VersionNo   = if_abap_behv=>mk-on )
              TO reported-odataregistry.
          ENDIF.

        WHEN '002'.
          SELECT SINGLE group_id
            FROM /iwfnd/c_v4_msgr
            WHERE group_id = @<ls_registry>-ServiceId
            INTO @DATA(lv_v4_group_id).

          IF sy-subrc <> 0.
            APPEND VALUE #( %tky = <ls_registry>-%tky
                            %fail-cause = if_abap_behv=>cause-not_found )
              TO failed-odataregistry.
            APPEND VALUE #(
              %tky = <ls_registry>-%tky
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = |404: OData V4 group ID { <ls_registry>-ServiceId } was not found in /IWFND/C_V4_MSGR.| )
              %element-ServiceName = if_abap_behv=>mk-on )
              TO reported-odataregistry.
          ENDIF.

        WHEN OTHERS.
          APPEND VALUE #( %tky = <ls_registry>-%tky ) TO failed-odataregistry.
          APPEND VALUE #(
            %tky = <ls_registry>-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = |Unsupported service type { <ls_registry>-ServiceType }. Use 001 for OData V2 or 002 for OData V4.| )
            %element-ServiceType = if_abap_behv=>mk-on )
            TO reported-odataregistry.
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
