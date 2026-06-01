CLASS zcl_gsu26_metadata_comparator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_xml_diff_line,
        line_num TYPE i,
        status   TYPE string,
        content  TYPE string,
      END OF ty_xml_diff_line,
      tt_xml_diff TYPE STANDARD TABLE OF ty_xml_diff_line WITH DEFAULT KEY,

      BEGIN OF ty_struct_node,
        name   TYPE string,
        ntype  TYPE string,
        status TYPE string,
        indent TYPE i,
        note   TYPE string,
      END OF ty_struct_node,
      tt_struct TYPE STANDARD TABLE OF ty_struct_node WITH DEFAULT KEY,

      BEGIN OF ty_xml_node,
        node_key  TYPE string,
        node_type TYPE string,
        node_name TYPE string,
        raw_line  TYPE string,
        line_num  TYPE i,
      END OF ty_xml_node,
      tt_xml_nodes TYPE STANDARD TABLE OF ty_xml_node WITH DEFAULT KEY,

      BEGIN OF ty_compare_result,
        base_version_id    TYPE string,
        compare_version_id TYPE string,
        added              TYPE i,
        removed            TYPE i,
        changed            TYPE i,
        unchanged          TYPE i,
        struct_diff        TYPE tt_struct,
        xml_diff           TYPE tt_xml_diff,
      END OF ty_compare_result.

    CLASS-METHODS compare
      IMPORTING iv_base_xml      TYPE string
                iv_compare_xml   TYPE string
                iv_base_id       TYPE string
                iv_compare_id    TYPE string
      RETURNING VALUE(rs_result) TYPE ty_compare_result.

    CLASS-METHODS print
      IMPORTING is_result TYPE ty_compare_result.

  PRIVATE SECTION.

    CLASS-METHODS build_xml
      IMPORTING it_lines      TYPE string_table
      RETURNING VALUE(rv_xml) TYPE string.

    CLASS-METHODS parse_structural
      IMPORTING iv_xml          TYPE string
      RETURNING VALUE(rt_nodes) TYPE tt_struct.

    CLASS-METHODS parse_to_nodes
      IMPORTING iv_xml          TYPE string
      RETURNING VALUE(rt_nodes) TYPE tt_xml_nodes.

    CLASS-METHODS diff_struct
      IMPORTING it_base        TYPE tt_struct
                it_compare     TYPE tt_struct
      RETURNING VALUE(rt_diff) TYPE tt_struct.

    CLASS-METHODS diff_nodes
      IMPORTING it_base        TYPE tt_xml_nodes
                it_compare     TYPE tt_xml_nodes
      RETURNING VALUE(rt_diff) TYPE tt_xml_diff.

    CLASS-METHODS get_icon
      IMPORTING iv_status     TYPE string
      RETURNING VALUE(rv_ico) TYPE string.

ENDCLASS.


CLASS zcl_gsu26_metadata_comparator IMPLEMENTATION.



  METHOD compare.
    DATA(lt_base_struct)    = parse_structural( iv_base_xml ).
    DATA(lt_compare_struct) = parse_structural( iv_compare_xml ).

    DATA(lt_struct_diff) = diff_struct(
      it_base    = lt_base_struct
      it_compare = lt_compare_struct ).

    DATA(lt_base_nodes)    = parse_to_nodes( iv_base_xml ).
    DATA(lt_compare_nodes) = parse_to_nodes( iv_compare_xml ).

    DATA(lt_xml_diff) = diff_nodes(
      it_base    = lt_base_nodes
      it_compare = lt_compare_nodes ).

    DATA lv_added     TYPE i.
    DATA lv_removed   TYPE i.
    DATA lv_changed   TYPE i.
    DATA lv_unchanged TYPE i.

    LOOP AT lt_struct_diff ASSIGNING FIELD-SYMBOL(<n>).
      CASE <n>-status.
        WHEN 'added'.     lv_added     += 1.
        WHEN 'removed'.   lv_removed   += 1.
        WHEN 'changed'.   lv_changed   += 1.
        WHEN 'unchanged'. lv_unchanged += 1.
      ENDCASE.
    ENDLOOP.

    rs_result-base_version_id    = iv_base_id.
    rs_result-compare_version_id = iv_compare_id.
    rs_result-added              = lv_added.
    rs_result-removed            = lv_removed.
    rs_result-changed            = lv_changed.
    rs_result-unchanged          = lv_unchanged.
    rs_result-struct_diff        = lt_struct_diff.
    rs_result-xml_diff           = lt_xml_diff.
  ENDMETHOD.


  METHOD build_xml.
    DATA lv_line TYPE string.
    LOOP AT it_lines INTO lv_line.
      IF rv_xml IS INITIAL.
        rv_xml = lv_line.
      ELSE.
        rv_xml = rv_xml && cl_abap_char_utilities=>newline && lv_line.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD parse_structural.
    DATA lo_ixml   TYPE REF TO if_ixml.
    DATA lo_doc    TYPE REF TO if_ixml_document.
    DATA lo_parser TYPE REF TO if_ixml_parser.
    DATA lo_sf     TYPE REF TO if_ixml_stream_factory.
    DATA lo_node   TYPE REF TO if_ixml_node.
    DATA lo_iter   TYPE REF TO if_ixml_node_iterator.
    DATA lv_xstr   TYPE xstring.

    lv_xstr = cl_abap_codepage=>convert_to(
      source   = iv_xml
      codepage = `UTF-8` ).

    lo_ixml = cl_ixml=>create( ).
    lo_doc  = lo_ixml->create_document( ).
    lo_sf   = lo_ixml->create_stream_factory( ).

    DATA(lo_in) = lo_sf->create_istream_xstring( string = lv_xstr ).
    lo_parser = lo_ixml->create_parser(
      stream_factory = lo_sf
      istream        = lo_in
      document       = lo_doc ).

    IF lo_parser->parse( ) <> 0.
      RETURN.
    ENDIF.

    lo_iter = lo_doc->create_iterator( ).
    lo_node = lo_iter->get_next( ).

    WHILE lo_node IS NOT INITIAL.
      DATA(lv_node_name) = lo_node->get_name( ).

      CASE lv_node_name.
        WHEN 'EntityType'.
          DATA(lo_et)      = CAST if_ixml_element( lo_node ).
          DATA(lv_et_name) = lo_et->get_attribute( 'Name' ).
          IF lv_et_name IS NOT INITIAL.
            APPEND VALUE ty_struct_node(
              name   = lv_et_name
              ntype  = 'EntityType'
              status = 'unchanged'
              indent = 0 ) TO rt_nodes.

            DATA(lo_ci) = lo_node->create_iterator( ).
            DATA(lo_ch) = lo_ci->get_next( ).
            WHILE lo_ch IS NOT INITIAL.
              DATA(lv_ch_name) = lo_ch->get_name( ).
              IF lv_ch_name = 'Property'.
                DATA(lo_prop)      = CAST if_ixml_element( lo_ch ).
                DATA(lv_prop_name) = lo_prop->get_attribute( 'Name' ).
                DATA(lv_prop_type) = lo_prop->get_attribute( 'Type' ).
                DATA(lv_precision) = lo_prop->get_attribute( 'Precision' ).
                DATA(lv_maxlen)    = lo_prop->get_attribute( 'MaxLength' ).
                IF lv_prop_name IS NOT INITIAL.
                  DATA lv_note TYPE string.
                  IF lv_precision IS NOT INITIAL.
                    lv_note = |Type:{ lv_prop_type } Precision:{ lv_precision }|.
                  ELSEIF lv_maxlen IS NOT INITIAL.
                    lv_note = |Type:{ lv_prop_type } MaxLength:{ lv_maxlen }|.
                  ELSE.
                    lv_note = |Type:{ lv_prop_type }|.
                  ENDIF.
                  APPEND VALUE ty_struct_node(
                    name   = lv_prop_name
                    ntype  = 'Property'
                    status = 'unchanged'
                    indent = 1
                    note   = lv_note ) TO rt_nodes.
                ENDIF.
              ELSEIF lv_ch_name = 'NavigationProperty'.
                DATA(lo_nav)      = CAST if_ixml_element( lo_ch ).
                DATA(lv_nav_name) = lo_nav->get_attribute( 'Name' ).
                IF lv_nav_name IS NOT INITIAL.
                  APPEND VALUE ty_struct_node(
                    name   = lv_nav_name
                    ntype  = 'NavigationProperty'
                    status = 'unchanged'
                    indent = 1 ) TO rt_nodes.
                ENDIF.
              ENDIF.
              lo_ch = lo_ci->get_next( ).
            ENDWHILE.
          ENDIF.

        WHEN 'Association'.
          DATA(lo_assoc)      = CAST if_ixml_element( lo_node ).
          DATA(lv_assoc_name) = lo_assoc->get_attribute( 'Name' ).
          IF lv_assoc_name IS NOT INITIAL.
            APPEND VALUE ty_struct_node(
              name   = lv_assoc_name
              ntype  = 'Association'
              status = 'unchanged'
              indent = 0 ) TO rt_nodes.
          ENDIF.

        WHEN 'FunctionImport'.
          DATA(lo_fi)      = CAST if_ixml_element( lo_node ).
          DATA(lv_fi_name) = lo_fi->get_attribute( 'Name' ).
          IF lv_fi_name IS NOT INITIAL.
            APPEND VALUE ty_struct_node(
              name   = lv_fi_name
              ntype  = 'FunctionImport'
              status = 'unchanged'
              indent = 0 ) TO rt_nodes.
          ENDIF.
      ENDCASE.

      lo_node = lo_iter->get_next( ).
    ENDWHILE.
  ENDMETHOD.


  METHOD parse_to_nodes.
    DATA lo_ixml     TYPE REF TO if_ixml.
    DATA lo_doc      TYPE REF TO if_ixml_document.
    DATA lo_parser   TYPE REF TO if_ixml_parser.
    DATA lo_sf       TYPE REF TO if_ixml_stream_factory.
    DATA lo_node     TYPE REF TO if_ixml_node.
    DATA lo_iter     TYPE REF TO if_ixml_node_iterator.
    DATA lv_xstr     TYPE xstring.
    DATA lv_line_num TYPE i VALUE 1.

    lv_xstr = cl_abap_codepage=>convert_to(
      source   = iv_xml
      codepage = `UTF-8` ).

    lo_ixml = cl_ixml=>create( ).
    lo_doc  = lo_ixml->create_document( ).
    lo_sf   = lo_ixml->create_stream_factory( ).

    DATA(lo_in) = lo_sf->create_istream_xstring( string = lv_xstr ).
    lo_parser = lo_ixml->create_parser(
      stream_factory = lo_sf
      istream        = lo_in
      document       = lo_doc ).

    IF lo_parser->parse( ) <> 0.
      RETURN.
    ENDIF.

    lo_iter = lo_doc->create_iterator( ).
    lo_node = lo_iter->get_next( ).

    WHILE lo_node IS NOT INITIAL.
      IF lo_node->get_type( ) = if_ixml_node=>co_node_element.
        DATA(lo_el)    = CAST if_ixml_element( lo_node ).
        DATA(lv_nname) = lo_node->get_name( ).
        DATA(lv_ename) = lo_el->get_attribute( 'Name' ).

        IF ( lv_nname = 'EntityType'
          OR lv_nname = 'Property'
          OR lv_nname = 'NavigationProperty'
          OR lv_nname = 'Association'
          OR lv_nname = 'FunctionImport'
          OR lv_nname = 'ComplexType'
          OR lv_nname = 'Schema' )
        AND lv_ename IS NOT INITIAL.

          DATA(lv_key)  = lv_nname && ':' && lv_ename.

          DATA lv_raw       TYPE string.
          DATA lv_type      TYPE string.
          DATA lv_maxlen    TYPE string.
          DATA lv_precision TYPE string.
          DATA lv_scale     TYPE string.
          DATA lv_nullable  TYPE string.
          DATA lv_namespace TYPE string.
          DATA lv_from_role TYPE string.
          DATA lv_to_role   TYPE string.

          lv_raw       = |<{ lv_nname } Name="{ lv_ename }"|.
          lv_type      = lo_el->get_attribute( 'Type' ).
          lv_maxlen    = lo_el->get_attribute( 'MaxLength' ).
          lv_precision = lo_el->get_attribute( 'Precision' ).
          lv_scale     = lo_el->get_attribute( 'Scale' ).
          lv_nullable  = lo_el->get_attribute( 'Nullable' ).
          lv_namespace = lo_el->get_attribute( 'Namespace' ).
          lv_from_role = lo_el->get_attribute( 'FromRole' ).
          lv_to_role   = lo_el->get_attribute( 'ToRole' ).

          IF lv_namespace IS NOT INITIAL.
            lv_raw = lv_raw && | Namespace="{ lv_namespace }"|.
          ENDIF.
          IF lv_type IS NOT INITIAL.
            lv_raw = lv_raw && | Type="{ lv_type }"|.
          ENDIF.
          IF lv_maxlen IS NOT INITIAL.
            lv_raw = lv_raw && | MaxLength="{ lv_maxlen }"|.
          ENDIF.
          IF lv_precision IS NOT INITIAL.
            lv_raw = lv_raw && | Precision="{ lv_precision }"|.
          ENDIF.
          IF lv_scale IS NOT INITIAL.
            lv_raw = lv_raw && | Scale="{ lv_scale }"|.
          ENDIF.
          IF lv_nullable IS NOT INITIAL.
            lv_raw = lv_raw && | Nullable="{ lv_nullable }"|.
          ENDIF.
          IF lv_from_role IS NOT INITIAL.
            lv_raw = lv_raw && | FromRole="{ lv_from_role }"|.
          ENDIF.
          IF lv_to_role IS NOT INITIAL.
            lv_raw = lv_raw && | ToRole="{ lv_to_role }"|.
          ENDIF.

          IF lo_node->get_first_child( ) IS INITIAL.
            lv_raw = lv_raw && `/>`.
          ELSE.
            lv_raw = lv_raw && `>`.
          ENDIF.

          APPEND VALUE ty_xml_node(
            node_key  = lv_key
            node_type = lv_nname
            node_name = lv_ename
            raw_line  = lv_raw
            line_num  = lv_line_num
          ) TO rt_nodes.

          lv_line_num += 1.

        ENDIF.
      ENDIF.
      lo_node = lo_iter->get_next( ).
    ENDWHILE.
  ENDMETHOD.


  METHOD diff_struct.
    LOOP AT it_base ASSIGNING FIELD-SYMBOL(<b>).
      READ TABLE it_compare
        WITH KEY name  = <b>-name
                 ntype = <b>-ntype
        INTO DATA(ls_cmp).

      IF sy-subrc = 0.
        IF ls_cmp-note <> <b>-note.
          APPEND VALUE ty_struct_node(
            name   = <b>-name
            ntype  = <b>-ntype
            status = 'changed'
            indent = <b>-indent
            note   = |Was: { <b>-note } >>> Now: { ls_cmp-note }|
          ) TO rt_diff.
        ELSE.
          APPEND VALUE ty_struct_node(
            name   = <b>-name
            ntype  = <b>-ntype
            status = 'unchanged'
            indent = <b>-indent
            note   = <b>-note
          ) TO rt_diff.
        ENDIF.
      ELSE.
        READ TABLE it_compare
          WITH KEY name = <b>-name
          TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          APPEND VALUE ty_struct_node(
            name   = <b>-name
            ntype  = <b>-ntype
            status = 'changed'
            indent = <b>-indent
            note   = |Type changed: { <b>-note }|
          ) TO rt_diff.
        ELSE.
          APPEND VALUE ty_struct_node(
            name   = <b>-name
            ntype  = <b>-ntype
            status = 'removed'
            indent = <b>-indent
            note   = <b>-note
          ) TO rt_diff.
        ENDIF.
      ENDIF.
    ENDLOOP.

    LOOP AT it_compare ASSIGNING FIELD-SYMBOL(<c>).
      READ TABLE it_base
        WITH KEY name  = <c>-name
                 ntype = <c>-ntype
        TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        READ TABLE rt_diff
          WITH KEY name  = <c>-name
                   ntype = <c>-ntype
          TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          APPEND VALUE ty_struct_node(
            name   = <c>-name
            ntype  = <c>-ntype
            status = 'added'
            indent = <c>-indent
            note   = <c>-note
          ) TO rt_diff.
        ENDIF.
      ENDIF.
    ENDLOOP.

    SORT rt_diff BY status ASCENDING name ASCENDING.
  ENDMETHOD.


  METHOD diff_nodes.
    LOOP AT it_compare ASSIGNING FIELD-SYMBOL(<cn>).
      READ TABLE it_base
        WITH KEY node_key = <cn>-node_key
        INTO DATA(ls_base_node).

      IF sy-subrc = 0.
        IF ls_base_node-raw_line <> <cn>-raw_line.
          APPEND VALUE ty_xml_diff_line(
            line_num = ls_base_node-line_num
            status   = 'removed'
            content  = ls_base_node-raw_line
          ) TO rt_diff.
          APPEND VALUE ty_xml_diff_line(
            line_num = <cn>-line_num
            status   = 'added'
            content  = <cn>-raw_line
          ) TO rt_diff.
        ENDIF.
      ELSE.
        APPEND VALUE ty_xml_diff_line(
          line_num = <cn>-line_num
          status   = 'added'
          content  = <cn>-raw_line
        ) TO rt_diff.
      ENDIF.
    ENDLOOP.

    LOOP AT it_base ASSIGNING FIELD-SYMBOL(<bn>).
      READ TABLE it_compare
        WITH KEY node_key = <bn>-node_key
        TRANSPORTING NO FIELDS.
      IF sy-subrc <> 0.
        READ TABLE rt_diff
          WITH KEY line_num = <bn>-line_num
                   status   = 'removed'
          TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          APPEND VALUE ty_xml_diff_line(
            line_num = <bn>-line_num
            status   = 'removed'
            content  = <bn>-raw_line
          ) TO rt_diff.
        ENDIF.
      ENDIF.
    ENDLOOP.

    SORT rt_diff BY line_num ASCENDING.
  ENDMETHOD.


  METHOD print.
    DATA lv_linenum_str TYPE string.
    DATA lv_content     TYPE string.
    DATA lv_len         TYPE i.
    DATA lv_indent_str  TYPE string.

    WRITE: / '===================================================='.
    WRITE: / '  COMPARE VERSION RESULT'.
    WRITE: / '===================================================='.
    WRITE: / '  Base version    :', is_result-base_version_id.
    WRITE: / '  Compare version :', is_result-compare_version_id.
    WRITE: /.
    WRITE: / '--- Delta Summary ----------------------------------'.
    WRITE: / '  [+] Added     :', is_result-added.
    WRITE: / '  [-] Removed   :', is_result-removed.
    WRITE: / '  [~] Changed   :', is_result-changed.
    WRITE: / '  [=] Unchanged :', is_result-unchanged.
    WRITE: /.
    WRITE: / '--- Structural Diff --------------------------------'.
    WRITE: / '  Icon  Name                     Type           Status'.
    WRITE: / '  ----  -----------------------  -------------  -------'.

    LOOP AT is_result-struct_diff ASSIGNING FIELD-SYMBOL(<node>)
      WHERE status <> 'unchanged'.
      DATA(lv_ico) = get_icon( <node>-status ).
      lv_indent_str = COND #( WHEN <node>-indent > 0 THEN '  +- ' ELSE '' ).
      DATA(lv_display) = lv_indent_str && <node>-name.
      WRITE: / '  ', lv_ico, lv_display, 34 <node>-ntype, 50 <node>-status.
      IF <node>-note IS NOT INITIAL.
        WRITE: / '       >> Note:', <node>-note.
      ENDIF.
    ENDLOOP.
    WRITE: /.

    WRITE: / '--- XML Node Diff ----------------------------------'.
    WRITE: / '  Icon  Line  Status    Content'.
    WRITE: / '  ----  ----  --------  ----------------------------'.

    LOOP AT is_result-xml_diff ASSIGNING FIELD-SYMBOL(<xline>).
      DATA(lv_xico) = get_icon( <xline>-status ).
      lv_linenum_str = <xline>-line_num.
      lv_content = <xline>-content.
      lv_len = strlen( lv_content ).
      IF lv_len > 180.
        lv_content = lv_content(180).
      ENDIF.
      WRITE: / '  ', lv_xico, 'L:', lv_linenum_str,
               16 <xline>-status,
               28 lv_content.
    ENDLOOP.

    WRITE: /.
    WRITE: / '===================================================='.
    WRITE: / '  Compare completed.'.
    WRITE: / '===================================================='.
  ENDMETHOD.


  METHOD get_icon.
    rv_ico = SWITCH #( iv_status
      WHEN 'added'   THEN '[+]'
      WHEN 'removed' THEN '[-]'
      WHEN 'changed' THEN '[~]'
      ELSE                '[=]' ).
  ENDMETHOD.

ENDCLASS.
