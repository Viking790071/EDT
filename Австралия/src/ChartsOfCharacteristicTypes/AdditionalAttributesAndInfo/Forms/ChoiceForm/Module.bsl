
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.Property("IsAccessValueSelection") Then
		Parameters.IsAdditionalInfo = True;
	EndIf;
	
	If Parameters.IsAdditionalInfo <> Undefined Then
		IsAdditionalInfo = Parameters.IsAdditionalInfo;
		
		CommonClientServer.SetDynamicListFilterItem(
			List, "IsAdditionalInfo", IsAdditionalInfo, , , True);
	EndIf;
	
	If Parameters.SelectCommonProperty Then
		
		SelectionKind = "SelectCommonProperty";
		
		CommonClientServer.SetDynamicListFilterItem(
			List, "PropertySet", , DataCompositionComparisonType.NotFilled, , True);
		
		If IsAdditionalInfo = True Then
			AutoTitle = False;
			Title = NStr("ru = 'Выбор общего дополнительного сведения'; en = 'Select common additional information'; pl = 'Wybierz wspólne dodatkowe informacje';es_ES = 'Seleccionar la información adicional común';es_CO = 'Seleccionar la información adicional común';tr = 'Ortak ek bilgileri seçin';it = 'Selezionare comuni ulteriori informazioni';de = 'Wählen Sie allgemeine zusätzliche Informationen'");
		ElsIf IsAdditionalInfo = False Then
			AutoTitle = False;
			Title = NStr("ru = 'Выбор общего дополнительного реквизита'; en = 'Select common additional attribute'; pl = 'Wybierz wspólny dodatkowy atrybut';es_ES = 'Seleccionar el atributo adicional común';es_CO = 'Seleccionar el atributo adicional común';tr = 'Ortak ek nitelikleri seçin';it = 'Selezionare attributo aggiuntivo comune';de = 'Wählen Sie das allgemeine zusätzliche Attribut aus'");
		EndIf;
		
	ElsIf Parameters.SelectAdditionalValueOwner Then
		
		SelectionKind = "SelectAdditionalValueOwner";
		
		CommonClientServer.SetDynamicListFilterItem(
			List, "PropertySet", , DataCompositionComparisonType.Filled, , True);
		
		CommonClientServer.SetDynamicListFilterItem(
			List, "AdditionalValuesUsed", True, , , True);
		
		CommonClientServer.SetDynamicListFilterItem(
			List, "AdditionalValuesOwner", ,
			DataCompositionComparisonType.NotFilled, , True);
		
		AutoTitle = False;
		Title = NStr("ru = 'Выбор образца'; en = 'Select sample'; pl = 'Wybierz wzór';es_ES = 'Seleccionar el modelo';es_CO = 'Seleccionar el modelo';tr = 'Örnek seçin';it = 'Selezione del campione';de = 'Wählen Sie ein Beispiel aus'");
		
		Items.FormCreate.Visible = False;
		Items.FormCopy.Visible = False;
		Items.FormChange.Visible = False;
		Items.FormMarkForDeletion.Visible = False;
		
		Items.ListContextMenuCreate.Visible = False;
		Items.ListContextMenuCopy.Visible = False;
		Items.ListContextMenuChange.Visible = False;
		Items.ListContextMenuMarkForDeletion.Visible = False;
	EndIf;
	FillSelectedValues();
	
	AddFilterByPropertySets();
	
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
	
	Parameters.Filter.Property("PropertySet", PropertiesSetFilter);
EndProcedure

&AtServer
Procedure AddFilterByPropertySets()
	If TypeOf(Parameters.DisplayedPropertySets) = Type("Array")
		AND Parameters.DisplayedPropertySets.Count() <> 0 Then
		QueryCondition =
			"
			|WHERE
			|	PropertiesOverridable.PropertySet IN (&Sets)";
		
		ListProperties = Common.DynamicListPropertiesStructure();
		ListProperties.QueryText = List.QueryText + QueryCondition;
		Common.SetDynamicListProperties(Items.List,
			ListProperties);
		
		CommonClientServer.SetDynamicListParameter(
			List, "Sets", Parameters.DisplayedPropertySets, True);
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListValueChoice(Item, Value, StandardProcessing)
	
	If SelectionKind = "SelectCommonProperty" Then
		StandardProcessing = False;
		NotifyChoice(New Structure("CommonProperty", Value));
		
	ElsIf SelectionKind = "SelectAdditionalValueOwner" Then
		StandardProcessing = False;
		NotifyChoice(New Structure("AdditionalValuesOwner", Value));
	EndIf;
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone)
	
	Cancel = True;
	
	If NOT Items.FormCreate.Visible Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("IsAdditionalInfo", IsAdditionalInfo);
	
	If Item.CurrentData = Undefined Then
		PropertySet = PropertiesSetFilter;
	ElsIf Item.CurrentData.Property("RowGroup") Then
		PropertySet = Item.CurrentData.RowGroup.Key;
	ElsIf Item.CurrentData.Property("ParentRowGrouping") Then
		PropertySet = Item.CurrentData.ParentRowGrouping.Key;
	Else
		PropertySet = PropertiesSetFilter;
	EndIf;
	
	FormParameters.Insert("PropertySet", PropertySet);
	FormParameters.Insert("CurrentPropertiesSet", PropertySet);
	
	If Clone Then
		FormParameters.Insert("CopyingValue", Item.CurrentRow);
	Else
		FillingValues = New Structure;
		FormParameters.Insert("FillingValues", FillingValues);
	EndIf;
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm", FormParameters);
	
EndProcedure

&AtClient
Procedure ListBeforeChangeRow(Item, Cancel)
	
	Cancel = True;
	
	If NOT Items.FormCreate.Visible Then
		Return;
	EndIf;
	
	If Item.CurrentData <> Undefined Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Key", Item.CurrentRow);
		FormParameters.Insert("IsAdditionalInfo", IsAdditionalInfo);
		
		OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm", FormParameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillSelectedValues()
	
	If Parameters.Property("SelectedValues")
	   AND TypeOf(Parameters.SelectedValues) = Type("Array") Then
		
		SelectedItemsList.LoadValues(Parameters.SelectedValues);
	EndIf;
	
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Font");
	AppearanceColorItem.Value = New Font(, , True);
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("List.Ref");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.InList;
	DataFilterItem.RightValue = SelectedItemsList;
	DataFilterItem.Use  = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("Presentation");
	FieldAppearanceItem.Use = True;
	
EndProcedure

#EndRegion
