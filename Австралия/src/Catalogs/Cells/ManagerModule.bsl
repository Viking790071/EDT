#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	
	Return Result;
	
EndFunction

#EndRegion
	
#Region EventHandlers

// Event handler procedure ChoiceDataGetProcessor.
//
Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	If Parameters.Filter.Property("Owner")
		AND ValueIsFilled(Parameters.Filter.Owner)
		AND (Parameters.Filter.Owner.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		OR Parameters.Filter.Owner.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting) Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'Cannot use storage bins in a retail store.'; ru = 'Для структурной единицы данного типа нельзя использовать ячейки!';pl = 'Nie można używać pojemników w sklepie detalicznym.';es_ES = 'No se puede utilizar depósitos de almacenamiento en la tienda de venta al por menor.';es_CO = 'No se puede utilizar contenedores de almacenamiento en la tienda de venta al por menor.';tr = 'Bir perakende mağazasında depolar kullanılamaz.';it = 'Non è possibile usare contenitori di magazzino in un negozio per vendita al dettaglio.';de = 'Lagerplätze in einer Einzelhandelsfiliale können nicht verwendet werden.'");
		Message.Message();
		StandardProcessing = False;
		
	EndIf;
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.Cells);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure


#EndRegion

#EndIf
