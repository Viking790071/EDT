#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure RegisterSalesInvoicesBasedOnAccountsReceivableChange(TempTablesManager) Export
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT DISTINCT
	|	RegisterRecordsAccountsReceivableChange.Document AS Document
	|FROM
	|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
	|WHERE
	|	RegisterRecordsAccountsReceivableChange.Document REFS Document.SalesInvoice
	|	AND NOT RegisterRecordsAccountsReceivableChange.Document = VALUE(Document.SalesInvoice.EmptyRef)";
	
	RegisterInvoices(Query.Execute().Select());
	
EndProcedure

Procedure RegisterSupplierInvoicesBasedOnAccountsPayableChange(TempTablesManager) Export
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT DISTINCT
	|	RegisterRecordsSuppliersSettlementsChange.Document AS Document
	|FROM
	|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
	|WHERE
	|	RegisterRecordsSuppliersSettlementsChange.Document REFS Document.SupplierInvoice
	|	AND NOT RegisterRecordsSuppliersSettlementsChange.Document = VALUE(Document.SupplierInvoice.EmptyRef)";

	RegisterInvoices(Query.Execute().Select());
	
EndProcedure

#EndRegion

#Region Private

Procedure RegisterInvoices(Sel)
	
	While Sel.Next() Do
		
		RecordSet = InformationRegisters.TasksForUpdatingStatuses.CreateRecordSet();
		
		RecordSet.Filter.Document.Set(Sel.Document);
		
		Record = RecordSet.Add();
		Record.Document = Sel.Document;
		
		RecordSet.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf