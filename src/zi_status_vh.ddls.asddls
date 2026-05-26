@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Status Value Help'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_STATUS_VH as select from zodata_status
{
    key status_id as StatusId,
    description as Description
}
