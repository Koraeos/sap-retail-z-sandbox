@AbapCatalog.sqlViewName: 'ZCRETSOHDR'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order header - consumption'

@UI.headerInfo: {
  typeName:       'Sales Order',
  typeNamePlural: 'Sales Orders',
  title:       { value: 'so_number' },
  description: { value: 'customer_master_name' }
}

@UI.facet: [
  {
    id:              'GeneralInfo',
    type:            #FIELDGROUP_REFERENCE,
    label:           'General Information',
    targetQualifier: 'GeneralInfo',
    position:        10
  },
  {
    id:              'Amounts',
    type:            #FIELDGROUP_REFERENCE,
    label:           'Amounts',
    targetQualifier: 'Amounts',
    position:        20
  },
  {
    id:              'Audit',
    type:            #FIELDGROUP_REFERENCE,
    label:           'Audit Trail',
    targetQualifier: 'Audit',
    position:        30
  }
]

define view ZC_RET_SO_HEADER
  as select from zret_t_so as so
    left outer join zret_t_customer as cust on cust.customer_id = so.customer_id
{
  @UI.lineItem:       [{ position: 10, importance: #HIGH, label: 'Sales Document' }]
  @UI.selectionField: [{ position: 10 }]
  @UI.fieldGroup:     [{ qualifier: 'GeneralInfo', position: 10, label: 'Sales Document' }]
  key so.so_number,

  @UI.lineItem:   [{ position: 20, label: 'Created On' }]
  @UI.fieldGroup: [{ qualifier: 'GeneralInfo', position: 20, label: 'Created On' }]
  so.so_date,

  @UI.lineItem:       [{ position: 30, importance: #HIGH, label: 'Customer ID' }]
  @UI.selectionField: [{ position: 20 }]
  @UI.fieldGroup:     [{ qualifier: 'GeneralInfo', position: 30, label: 'Customer ID' }]
  so.customer_id,

  @UI.lineItem:   [{ position: 40, importance: #HIGH, label: 'Customer Name' }]
  @UI.fieldGroup: [{ qualifier: 'GeneralInfo', position: 40, label: 'Customer Name' }]
  cust.customer_name as customer_master_name,

  @UI.lineItem:       [{ position: 50, importance: #HIGH, label: 'Status' }]
  @UI.selectionField: [{ position: 30 }]
  @UI.fieldGroup:     [{ qualifier: 'GeneralInfo', position: 50, label: 'Status' }]
  so.status,

  @UI.lineItem:                   [{ position: 60, importance: #HIGH, label: 'Total Amount' }]
  @UI.fieldGroup:                 [{ qualifier: 'Amounts', position: 10, label: 'Total Amount' }]
  @Semantics.amount.currencyCode: 'currency'
  so.total_amount,

  @UI.fieldGroup: [{ qualifier: 'Amounts', position: 20, label: 'Currency' }]
  so.currency,

  @UI.fieldGroup: [{ qualifier: 'Audit', position: 10, label: 'Created By' }]
  so.created_by,

  @UI.fieldGroup: [{ qualifier: 'Audit', position: 20, label: 'Created On' }]
  so.created_on,

  @UI.fieldGroup: [{ qualifier: 'Audit', position: 30, label: 'Changed By' }]
  so.changed_by,

  @UI.fieldGroup: [{ qualifier: 'Audit', position: 40, label: 'Changed On' }]
  so.changed_on
}
