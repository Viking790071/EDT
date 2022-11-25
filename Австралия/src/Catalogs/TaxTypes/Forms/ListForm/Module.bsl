#Region FormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	If Not GetFunctionalOption("UseVAT") Then
		
		CommonClientServer.SetDynamicListFilterItem(
			List,
			"Ref",
			Catalogs.TaxTypes.VAT,
			DataCompositionComparisonType.NotEqual);
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion
