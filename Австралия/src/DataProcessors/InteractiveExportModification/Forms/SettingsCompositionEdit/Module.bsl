
#Region EventHandlers
//

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then 
		// Return when a form is received for analysis.
		Return;
	EndIf;
	
	FillPropertyValues(Object, Parameters.Object , , "AllDocumentsFilterComposer, AdditionalRegistration, AdditionalNodeScenarioRegistration");
	For Each Row In Parameters.Object.AdditionalRegistration Do
		FillPropertyValues(Object.AdditionalRegistration.Add(), Row);
	EndDo;
	For Each Row In Parameters.Object.AdditionalNodeScenarioRegistration Do
		FillPropertyValues(Object.AdditionalNodeScenarioRegistration.Add(), Row);
	EndDo;
	
	// Initializing composer manually.
	DataProcessorObject = FormAttributeToValue("Object");
	
	Data = GetFromTempStorage(Parameters.Object.AllDocumentsComposerAddress);
	DataProcessorObject.AllDocumentsFilterComposer = New DataCompositionSettingsComposer;
	DataProcessorObject.AllDocumentsFilterComposer.Initialize(
		New DataCompositionAvailableSettingsSource(Data.CompositionSchema));
	DataProcessorObject.AllDocumentsFilterComposer.LoadSettings(Data.Settings);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	CurrentSettingsItemPresentation = Parameters.CurrentSettingsItemPresentation;
	ReadSavedSettings();
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSettingsOptions
//

&AtClient
Procedure SettingsOptionsChoice(Item, RowSelected, Field, StandardProcessing)
	CurrentData = SettingVariants.FindByID(RowSelected);
	If CurrentData<>Undefined Then
		CurrentSettingsItemPresentation = CurrentData.Presentation;
	EndIf;
EndProcedure

&AtClient
Procedure SettingsOptionsBeforeAdd(Item, Cancel, Clone, Parent, IsFolder)
	Cancel = True;
EndProcedure

&AtClient
Procedure SettingsOptionsBeforeDelete(Item, Cancel)
	Cancel = True;
	
	SettingPresentation = Item.CurrentData.Presentation;
	
	TitleText = NStr("ru='Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
	QuestionText   = NStr("ru='Удалить настройку ""%1""?'; en = 'Do you want to delete ""%1"" settings?'; pl = 'Usuń ustawienie ""%1""?';es_ES = '¿Eliminar la configuración ""%1""?';es_CO = '¿Eliminar la configuración ""%1""?';tr = '""%1"" ayarı kaldırılsın mı?';it = 'Volete eliminare le impostazioni ""%1""?';de = 'Einstellung ""%1"" entfernen?'");
	
	QuestionText = StrReplace(QuestionText, "%1", SettingPresentation);
	
	AdditionalParameters = New Structure("SettingPresentation", SettingPresentation);
	NotifyDescription = New NotifyDescription("DeleteSettingsVariantRequestNotification", ThisObject, 
		AdditionalParameters);
	
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,,,TitleText);
EndProcedure

#EndRegion

#Region FormCommandHandlers
//

&AtClient
Procedure SaveSetting(Command)
	
	If IsBlankString(CurrentSettingsItemPresentation) Then
		CommonClientServer.MessageToUser(
			NStr("ru='Не заполнено имя для текущей настройки.'; en = 'Enter a name for the current settings.'; pl = 'Nazwa bieżącego ustawienia nie została wpisana.';es_ES = 'Nombre para la configuración actual no se ha introducido.';es_CO = 'Nombre para la configuración actual no se ha introducido.';tr = 'Mevcut ayarın adı girilmemiş.';it = 'Inserire un nome per le impostazioni correnti.';de = 'Der Name für die aktuelle Einstellung wurde nicht eingegeben.'"), , "CurrentSettingsItemPresentation");
		Return;
	EndIf;
		
	If SettingVariants.FindByValue(CurrentSettingsItemPresentation)<>Undefined Then
		TitleText = NStr("ru='Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
		QuestionText   = NStr("ru='Перезаписать существующую настройку ""%1""?'; en = 'Do you want to overwrite ""%1"" settings?'; pl = 'Przepisz istniejące ustawienie ""%1""?';es_ES = '¿Volver a grabar la configuración existente ""%1""?';es_CO = '¿Volver a grabar la configuración existente ""%1""?';tr = 'Mevcut ayarı yeniden yaz ""%1""?';it = 'Volete sovrascrivere le impostazioni ""%1""?';de = 'Bestehende Einstellung ""%1"" neu schreiben?'");
		QuestionText = StrReplace(QuestionText, "%1", CurrentSettingsItemPresentation);
		
		AdditionalParameters = New Structure("SettingPresentation", CurrentSettingsItemPresentation);
		NotifyDescription = New NotifyDescription("SaveSettingsVariantRequestNotification", ThisObject, 
			AdditionalParameters);
			
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,,,TitleText);
		Return;
	EndIf;
	
	// Saving without displaying a question
	SaveAndExecuteCurrentSettingSelection();
EndProcedure
	
&AtClient
Procedure MakeChoice(Command)
	ExecuteSelection(CurrentSettingsItemPresentation);
EndProcedure

#EndRegion

#Region Private
//

&AtServer
Function ThisObject(NewObject=Undefined)
	If NewObject=Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(NewObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Procedure DeleteSettingsServer(SettingPresentation)
	ThisObject().DeleteSettingsOption(SettingPresentation);
EndProcedure

&AtServer
Procedure ReadSavedSettings()
	ThisDataProcessor = ThisObject();
	
	VariantFilter = DataExchangeServer.InteractiveExportModificationVariantFilter(Object);
	SettingVariants = ThisDataProcessor.ReadSettingsListPresentations(Object.InfobaseNode, VariantFilter);
	
	ListItem = SettingVariants.FindByValue(CurrentSettingsItemPresentation);
	Items.SettingVariants.CurrentRow = ?(ListItem=Undefined, Undefined, ListItem.GetID())
EndProcedure

&AtServer
Procedure SaveCurrentSettings()
	ThisObject().SaveCurrentValuesInSettings(CurrentSettingsItemPresentation);
EndProcedure

&AtClient
Procedure ExecuteSelection(Presentation)
	If SettingVariants.FindByValue(Presentation)<>Undefined AND CloseOnChoice Then 
		NotifyChoice( New Structure("ChoiceAction, SettingPresentation", 3, Presentation) );
	EndIf;
EndProcedure

&AtClient
Procedure DeleteSettingsVariantRequestNotification(Result, AdditionalParameters) Export
	If Result<>DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DeleteSettingsServer(AdditionalParameters.SettingPresentation);
	ReadSavedSettings();
EndProcedure

&AtClient
Procedure SaveSettingsVariantRequestNotification(Result, AdditionalParameters) Export
	If Result<>DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	CurrentSettingsItemPresentation = AdditionalParameters.SettingPresentation;
	SaveAndExecuteCurrentSettingSelection();
EndProcedure

&AtClient
Procedure SaveAndExecuteCurrentSettingSelection()
	
	SaveCurrentSettings();
	ReadSavedSettings();
	
	CloseOnChoice = True;
	ExecuteSelection(CurrentSettingsItemPresentation);
EndProcedure;

#EndRegion
