#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName", "NetSales");
	Variant.Insert("VariantKey", "GrossProfitByBundles");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure

#EndRegion