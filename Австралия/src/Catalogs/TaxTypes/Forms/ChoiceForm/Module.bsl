#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
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