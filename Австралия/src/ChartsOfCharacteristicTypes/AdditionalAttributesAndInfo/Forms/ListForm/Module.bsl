
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CommonClientServer.SetDynamicListParameter(
		List,
		"CommonPropertiesGroupPresentation",
		NStr("ru = 'Общие (для нескольких наборов)'; en = 'Common (for several sets)'; pl = 'Wspólne (dla kilku zestawów)';es_ES = 'Común (para varios conjuntos)';es_CO = 'Común (para varios conjuntos)';tr = 'Ortak (birkaç küme için)';it = 'Comune (per diverse serie)';de = 'Allgemein (für mehrere Sätze)'"),
		True);
	
	// Grouping properties to sets.
	DataGroup = List.SettingsComposer.Settings.Structure.Add(Type("DataCompositionGroup"));
	DataGroup.UserSettingID = "GroupPropertiesBySets";
	DataGroup.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	GroupFields = DataGroup.GroupFields;
	
	DataGroupItem = GroupFields.Items.Add(Type("DataCompositionGroupField"));
	DataGroupItem.Field = New DataCompositionField("PropertiesSetGroup");
	DataGroupItem.Use = True;
	
EndProcedure

#EndRegion
