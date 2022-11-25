#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Description = "" + ItemType + ": " + DescriptionForPrinting + ", ";
	For Each AdditionalAttribute In ItemTypeAttributes Do
		If Not ValueIsFilled(AdditionalAttribute.Value) Then
			Continue;
		EndIf;
		Description = Description + AdditionalAttribute.Value + ", ";
	EndDo;
	
	Description = Left(Description, StrLen(Description) - 2);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ItemType = Enums.FinancialReportItemsTypes.Group Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "DescriptionForPrinting");
	EndIf;
	
EndProcedure

#EndRegion

#EndIf