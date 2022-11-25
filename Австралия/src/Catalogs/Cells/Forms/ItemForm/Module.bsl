#Region ProcedureFormEventHandlers

// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Object.Owner) 
		AND (Object.Owner.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
			OR Object.Owner.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting) Then
		
			Message = New UserMessage();
			Message.Text = NStr("en = 'Cannot use storage bins in a retail store.'; ru = 'Для структурной единицы данного типа нельзя использовать ячейки!';pl = 'Nie można używać pojemników w sklepie detalicznym.';es_ES = 'No se puede utilizar depósitos de almacenamiento en la tienda de venta al por menor.';es_CO = 'No se puede utilizar contenedores de almacenamiento en la tienda de venta al por menor.';tr = 'Bir perakende mağazasında depolar kullanılamaz.';it = 'Non è possibile usare contenitori di magazzino in un negozio per vendita al dettaglio.';de = 'Lagerplätze in einer Einzelhandelsfiliale können nicht verwendet werden.'");
			Message.Message();
			Cancel = True;
			
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion
