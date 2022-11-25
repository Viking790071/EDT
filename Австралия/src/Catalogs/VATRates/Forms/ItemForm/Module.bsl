#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CommonClientServer.SetFormItemProperty(Items, "Rate",		"Visible", Not Object.NotTaxable);
	CommonClientServer.SetFormItemProperty(Items, "Calculated",	"Visible", Not Object.NotTaxable);
	
	CommonClientServer.SetFormItemProperty(Items, "NotTaxable",	"ReadOnly", Object.Predefined);
	CommonClientServer.SetFormItemProperty(Items, "Rate",		"ReadOnly", Object.Predefined);
	CommonClientServer.SetFormItemProperty(Items, "Calculated",	"ReadOnly", Object.Predefined);
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

&AtClient
// Procedure - event handler OnChange of the NotTaxable input fields.
//
Procedure NotTaxableOnChange(Item)
	
	If Object.NotTaxable Then
		
		Object.Rate		= 0;
		Object.Calculated	= False;
		
	EndIf;
	
	CommonClientServer.SetFormItemProperty(Items, "Rate",		"Visible", Not Object.NotTaxable);
	CommonClientServer.SetFormItemProperty(Items, "Calculated",	"Visible", Not Object.NotTaxable);
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion
