#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function Cache() Export
	
	ThisRef = Enums.FinancialReportItemsTypes;
	ThisMetadata = Metadata.Enums.FinancialReportItemsTypes;
	Cache = New Structure;
	For Each Value In ThisMetadata.EnumValues Do
		Cache.Insert(Value.Name, ThisRef[Value.Name]);
	EndDo;
	Return Cache;
	
EndFunction

#EndRegion

#EndIf