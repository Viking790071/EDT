&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "IncomeAndExpensesByCashMethod");
	Variant.Insert("VariantKey", "IncomeAndExpensesDynamics");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
