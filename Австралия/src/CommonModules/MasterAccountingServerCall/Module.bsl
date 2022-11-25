
#Region Public

Function GetAccountInformation(Account) Export
	
	Return MasterAccounting.GetAccountInformationMap(Account);
	
EndFunction

Function RestoreOriginalEntries(Document, BasisDocument, TypeOfAccounting = Undefined, ChartOfAccounts = Undefined) Export
	
	Return MasterAccounting.RestoreOriginalEntries(Document, BasisDocument, TypeOfAccounting, ChartOfAccounts);
	
EndFunction

Procedure FillMiscFields(RecordSetMasterTable, Suffixes = Undefined) Export
	
	MasterAccounting.FillMiscFields(RecordSetMasterTable, Suffixes);
	
EndProcedure

Function GetEntriesNumber(Val Table) Export

	Return MasterAccounting.GetEntriesNumber(Table);
	
EndFunction

#EndRegion