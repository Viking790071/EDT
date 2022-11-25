#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler ChoiceDataReceivingProcessing.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
	// If the parameters of selection by products are linked, then we will get the selection data from the "UOM" catalog.
		StandardProcessing = False;
		ChoiceData = Catalogs.UOM.GetChoiceData(Parameters);
	Else
		NativeLanguagesSupportServer.ChoiceDataGetProcessing(
			ChoiceData,
			Parameters,
			StandardProcessing,
			Metadata.Catalogs.UOMClassifier);
	EndIf;
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#EndIf