#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure GetAccountingEntriesTablesStructure(ParametersStructure, StorageAddress) Export
	
	SetPrivilegedMode(True);
	
	Entries = AccountingTemplatesPosting.GetAccountingEntriesTablesStructure(
		ParametersStructure.Document,
		ParametersStructure.Cancel,
		ParametersStructure.TypeOfAccounting,
		ParametersStructure.TemplatesArray,
		ParametersStructure.DoNotCheckTemplateValidityPeriod);
		
	SetPrivilegedMode(False);
		
	ResultData = New Structure;
	ResultData.Insert("TypeOfAccounting"	, ParametersStructure.TypeOfAccounting);
	ResultData.Insert("ChartOfAccounts"		, ParametersStructure.ChartOfAccounts);
	ResultData.Insert("PresentationCurrency", ParametersStructure.PresentationCurrency);
	ResultData.Insert("Entries"				, Entries);
	ResultData.Insert("Cancel"				, ParametersStructure.Cancel);
	
	PutToTempStorage(ResultData, StorageAddress);
	
EndProcedure

#EndRegion

#EndIf