
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Read = True;
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

&AtClient
Procedure UpdateAuxiliaryRegisterData(Command)
	
	HasChanges = False;
	
	UpdateAuxiliaryRegisterDataAtServer(HasChanges);
	
	If HasChanges Then
		Text = NStr("ru = 'Обновление выполнено успешно.'; en = 'The update is completed.'; pl = 'Aktualizacja zakończona pomyślnie.';es_ES = 'Actualización se ha realizado con éxito.';es_CO = 'Actualización se ha realizado con éxito.';tr = 'Güncelleme başarılı.';it = 'L''aggiornamento è stato completato.';de = 'Das Update war erfolgreich.'");
	Else
		Text = NStr("ru = 'Обновление не требуется.'; en = 'The update is not required.'; pl = 'Aktualizacja nie jest wymagana.';es_ES = 'No se requiere una actualización.';es_CO = 'No se requiere una actualización.';tr = 'Güncelleme gerekmiyor.';it = 'L''aggiornamento non è richiesto';de = 'Update ist nicht erforderlich.'");
	EndIf;
	
	ShowMessageBox(, Text);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	List.SettingsComposer.Settings.ConditionalAppearance.Items.Clear();
	
	AppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	AppearanceItem.Appearance.SetParameterValue("Text", NStr("ru = 'Для всех таблиц, кроме указанных'; en = 'For all tables except for specified ones'; pl = 'Dla wszystkich tablic oprócz określonych';es_ES = 'Para todas las tablas a excepción de las especificadas';es_CO = 'Para todas las tablas a excepción de las especificadas';tr = 'Belirtilenler dışındaki tüm tablolar için';it = 'Per tutte le tabelle tranne quelle specificate';de = 'Für alle Tabellen mit Ausnahme der angegebenen Tabellen'"));
	
	FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("Table");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = Catalogs.MetadataObjectIDs.EmptyRef();
	
	FieldItem = AppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("Table");
	
EndProcedure

&AtServer
Procedure UpdateAuxiliaryRegisterDataAtServer(HasChanges)
	
	SetPrivilegedMode(True);
	
	InformationRegisters.ObjectsRightsSettings.UpdateAuxiliaryRegisterData(HasChanges);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
