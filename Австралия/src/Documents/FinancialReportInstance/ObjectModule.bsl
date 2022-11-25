#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("Structure") Then
		FillPropertyValues(ThisObject, FillingData);
		If FillingData.Property("ReportPeriod") Then
			FillPropertyValues(ThisObject, FillingData.ReportPeriod);
		EndIf;
		If FillingData.Property("Filter") Then
			FillPropertyValues(ThisObject, FillingData.Filter);
		EndIf;
		If FillingData.Property("ReportResult") Then
			ReportResult = New ValueStorage(FillingData.ReportResult);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf