&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Variant = New Structure;
	Variant.Insert("ReportName",    "NetSales");
	Variant.Insert("VariantKey", "SalesDynamicsBySalesRep");
	
	DriveReportsClient.OpenReportOption(Variant);
	
EndProcedure
