
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName", "SalesOrdersStatement");
	Variant.Insert("VariantKey", "StatementForExternalUsers");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure

#EndRegion