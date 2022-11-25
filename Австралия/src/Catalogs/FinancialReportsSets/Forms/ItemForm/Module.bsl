
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
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

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ReportsTypesFinancialReportTypeOnChange(Item)
	
	Items.ReportsTypes.CurrentData.SettingsText = NStr("en = 'Set filters'; ru = 'Установить отбор';pl = 'Ustaw filtry';es_ES = 'Establecer los filtros';es_CO = 'Establecer los filtros';tr = 'Filtreleri ayarla';it = 'Impostare filtri';de = 'Filter einstellen'");
	
EndProcedure

&AtClient
Procedure DetailsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	CommonClient.ShowCommentEditingForm(
		Item.EditText, 
		ThisObject, 
		"Object.Details");
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion