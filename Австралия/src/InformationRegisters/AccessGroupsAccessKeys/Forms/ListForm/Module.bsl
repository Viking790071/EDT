
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
	
	// Conditional appearance.
	AppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	AppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	DecorationTextItem = AppearanceItem.Appearance.Items.Find("Text");
	DecorationTextItem.Value = NStr("ru = 'Разрешенная пустая группа доступа'; en = 'Allowed blank access group'; pl = 'Dozwolone pusta grupa dostępu';es_ES = 'Grupo de acceso permitido vacío';es_CO = 'Grupo de acceso permitido vacío';tr = 'Izin verilen boş erişim grubu';it = 'Gruppo di accesso vuoto consentito';de = 'Erlaubte leere Zugriffsgruppe'");
	DecorationTextItem.Use = True;
	
	FilterItem = AppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue  = New DataCompositionField("AccessGroup");
	FilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = Catalogs.AccessGroups.EmptyRef();
	FilterItem.Use  = True;
	
	FieldItem = AppearanceItem.Fields.Items.Add();
	FieldItem.Field = New DataCompositionField("AccessGroup");
	FieldItem.Use = True;
	
EndProcedure

#EndRegion
