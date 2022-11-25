#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetObjectAttributesBeingLocked() Export
	
	Return New Array;
	
EndFunction

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.ManufacturingActivities);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	StandardProcessing = False;
	
	If TrimAll(Data.OperationNumber) <> "" Then
		
		Presentation = TrimAll(Data.OperationNumber) + ", " + Data.Description;
		
	Else 
		
		Presentation = Data.Description;
		
	EndIf;
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	
	Fields.Add("OperationNumber");
	Fields.Add("Description");
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf