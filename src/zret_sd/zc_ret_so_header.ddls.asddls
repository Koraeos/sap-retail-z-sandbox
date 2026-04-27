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

define view ZC_RET_SO_HEADER
  as select from zret_t_so as so
    left outer join zret_t_customer as cust on cust.customer_id = so.customer_id
{
  @UI.lineItem:       [{ position: 10, importance: #HIGH, label: 'Sales Document' }]
  @UI.identification: [{ position: 10, label: 'Sales Document' }]
  @UI.selectionField: [{ position: 10 }]
  key so.so_number,

  @UI.lineItem:       [{ position: 20, label: 'Created On' }]
  @UI.identification: [{ position: 20, label: 'Created On' }]
  so.so_date,

  @UI.lineItem:       [{ position: 30, importance: #HIGH, label: 'Customer ID' }]
  @UI.identification: [{ position: 30, label: 'Customer ID' }]
  @UI.selectionField: [{ position: 20 }]
  so.customer_id,

  @UI.lineItem:       [{ position: 40, importance: #HIGH, label: 'Customer Name' }]
  @UI.identification: [{ position: 40, label: 'Customer Name' }]
  cust.customer_name as customer_master_name,

  @UI.lineItem:       [{ position: 50, importance: #HIGH, label: 'Status' }]
  @UI.identification: [{ position: 50, label: 'Status' }]
  @UI.selectionField: [{ position: 30 }]
  so.status,

  @UI.lineItem:                   [{ position: 60, importance: #HIGH, label: 'Total Amount' }]
  @UI.identification:             [{ position: 60, label: 'Total Amount' }]
  @Semantics.amount.currencyCode: 'currency'
  so.total_amount,

  @UI.identification: [{ position: 70, label: 'Currency' }]
  so.currency,

  so.created_by,
  so.created_on,
  so.changed_by,
  so.changed_on
}
