#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Function EmptyTableAccountingEntriesData() Export 
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 0
	|	AccountingEntriesData.Period AS Period,
	|	AccountingEntriesData.Recorder AS Recorder,
	|	AccountingEntriesData.LineNumber AS LineNumber,
	|	AccountingEntriesData.Active AS Active,
	|	AccountingEntriesData.EntryType AS EntryType,
	|	AccountingEntriesData.Company AS Company,
	|	AccountingEntriesData.PresentationCurrency AS PresentationCurrency,
	|	AccountingEntriesData.VATID AS VATID,
	|	AccountingEntriesData.TaxCategory AS TaxCategory,
	|	AccountingEntriesData.TaxRate AS TaxRate,
	|	AccountingEntriesData.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	AccountingEntriesData.Department AS Department,
	|	AccountingEntriesData.Product AS Product,
	|	AccountingEntriesData.Variant AS Variant,
	|	AccountingEntriesData.Batch AS Batch,
	|	AccountingEntriesData.Warehouse AS Warehouse,
	|	AccountingEntriesData.Ownership AS Ownership,
	|	AccountingEntriesData.Project AS Project,
	|	AccountingEntriesData.Counterparty AS Counterparty,
	|	AccountingEntriesData.Contract AS Contract,
	|	AccountingEntriesData.CorrCounterparty AS CorrCounterparty,
	|	AccountingEntriesData.CorrContract AS CorrContract,
	|	AccountingEntriesData.AdvanceDocument AS AdvanceDocument,
	|	AccountingEntriesData.Order AS Order,
	|	AccountingEntriesData.SettlementCurrency AS SettlementCurrency,
	|	AccountingEntriesData.SalesTax AS SalesTax,
	|	AccountingEntriesData.TaxAgency AS TaxAgency,
	|	AccountingEntriesData.RowNumber AS RowNumber,
	|	AccountingEntriesData.Quantity AS Quantity,
	|	AccountingEntriesData.Amount AS Amount,
	|	AccountingEntriesData.SettlementsAmount AS SettlementsAmount,
	|	AccountingEntriesData.Tax AS Tax,
	|	AccountingEntriesData.SettlementsTax AS SettlementsTax,
	|	AccountingEntriesData.DeliveryPeriodStart AS DeliveryPeriodStart,
	|	AccountingEntriesData.DeliveryPeriodEnd AS DeliveryPeriodEnd
	|FROM
	|	InformationRegister.AccountingEntriesData AS AccountingEntriesData";
	
	Return Query.Execute().Unload();
	
EndFunction

#EndRegion 

#EndIf