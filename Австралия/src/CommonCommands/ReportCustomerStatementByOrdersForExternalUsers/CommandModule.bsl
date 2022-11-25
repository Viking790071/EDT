
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName", "CustomerStatement");
	Variant.Insert("VariantKey", "StatementInCurrencyByOrdersExternalUser");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure

#EndRegion