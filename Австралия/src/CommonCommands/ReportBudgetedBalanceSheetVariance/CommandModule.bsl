&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName", "BudgetedBalanceSheetVariance");
	Variant.Insert("VariantKey", "Default");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
