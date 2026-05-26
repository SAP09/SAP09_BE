@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Trigger Type Value Help'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_TRIGGER_VH as select from zodata_trigger
{
    key trigger_id as TriggerId,
    description as Description
}
