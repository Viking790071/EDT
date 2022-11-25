
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	List.SettingsComposer.Settings.ConditionalAppearance.Items.Clear();
	
	
	AppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	AppearanceItem.Appearance.SetParameterValue("Text", NStr("ru = 'Проверка права Чтение'; en = 'Check the Read right'; pl = 'Kontrola prawa Odczyt';es_ES = 'Revisar el derecho de Leer';es_CO = 'Revisar el derecho de Leer';tr = 'Okuma hakkının kontrolü';it = 'Verificare il diritto Lettura';de = 'Überprüfen Sie das Leserecht'"));
	
	FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("IsTableRightCheck");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = True;
	
	FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("Clarification");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = Catalogs.MetadataObjectIDs.EmptyRef();
	
	FieldItem = AppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("Clarification");
	
	
	AppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	AppearanceItem.Appearance.SetParameterValue("Text", NStr("ru = 'Проверка права Изменение'; en = 'Check the Update right'; pl = 'Kontrola prawa Edycja';es_ES = 'Revisar el derecho de Editar';es_CO = 'Revisar el derecho de Editar';tr = 'Düzenleme hakkının kontrolü';it = 'Validazione diritto Modifica';de = 'Überprüfen Sie das Bearbeitungsrecht'"));
	
	FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("IsTableRightCheck");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = True;
	
	FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = New DataCompositionField("Clarification");
	FilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
	FilterItem.RightValue = Catalogs.MetadataObjectIDs.EmptyRef();
	
	FieldItem = AppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("Clarification");
	
EndProcedure

#EndRegion
