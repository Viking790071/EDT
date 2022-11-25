
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;

	If Parameters.Property("ShowAdditionalAttributes") Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject,
			"AdditionalAttributeSets");
		Items.IsAdditionalInfoSets.Visible = False;
		
	ElsIf Parameters.Property("ShowAdditionalInfo") Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject,
			"AdditionalDataSets");
		Items.IsAdditionalInfoSets.Visible = False;
		IsAdditionalInfoSets = True;
	EndIf;
	
	FormColor = Items.Properties.BackColor;
	
	ApplySetsAndPropertiesAppearance();
	
	UpdateCommandsUsage();
	
	ConfigureSetsDisplay();
	
	If Not Common.SubsystemExists("StandardSubsystems.DuplicateObjectDetection") Then
		Items.DuplicateObjectDetection.Visible = False;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		Items.Move(Items.FormCommandBar, Items.FormCommandBarMobileClient);
		
		CommonClientServer.SetFormItemProperty(Items, "PropertySets", "Header", True);
		CommonClientServer.SetFormItemProperty(Items, "PropertySets", "AutoMaxHeight", False);
		CommonClientServer.SetFormItemProperty(Items, "PropertySets", "MaxHeight", 5);
		CommonClientServer.SetFormItemProperty(Items, "CopyAttribute", "OnlyInAllActions", True);
		CommonClientServer.SetFormItemProperty(Items, "PasteAttribute", "OnlyInAllActions", True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_AdditionalAttributesAndInfo"
	 OR EventName = "Write_ObjectPropertyValues"
	 OR EventName = "Write_ObjectPropertyValueHierarchy" Then
		
		// Upon writing a property, move the property to the appropriate group.
		// Upon writing a value, update the list of the top three values.
		OnChangeCurrentSetAtServer();
		
	ElsIf EventName = "Go_AdditionalDataAndAttributeSets" Then
		// Upon opening the form for editing properties of a certain metadata object, go to the set or set 
		// group of this metadata object.
		If TypeOf(Parameter) = Type("Structure") Then
			SelectSpecifiedRows(Parameter);
		EndIf;
		
	ElsIf EventName = "Write_ConstantsSet" Then
		
		If Source = "UseCommonAdditionalValues"
		 OR Source = "UseAdditionalCommonAttributesAndInfo" Then
			UpdateCommandsUsage();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure IsAdditionalInfoSetsOnChange(Item)
	
	ConfigureSetsDisplay();
	
EndProcedure

#EndRegion

#Region PropertySetsFormTableItemEventHandlers

&AtClient
Procedure PropertySetsOnActivateRow(Item)
	
	AttachIdleHandler("OnChangeCurrentSet", 0.1, True);
	
EndProcedure

&AtClient
Procedure PropertySetsBeforeChangeRow(Item, Cancel)
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertySetsDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
	
	If Items.PropertySets.RowData(Row).IsFolder Then
		DragParameters.Action = DragAction.Cancel;
	EndIf;
	
EndProcedure

&AtClient
Procedure PropertySetsDrag(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
	
	If DragParameters.Value.CommonValues Then
		ItemToDrag = DragParameters.Value.AdditionalValuesOwner;
	Else
		ItemToDrag = DragParameters.Value.Property;
	EndIf;
	
	If TypeOf(ItemToDrag) <> Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo") Then
		Return;
	EndIf;
	
	DestinationSet = Row;
	AddAttributeToSet(ItemToDrag, Row);
EndProcedure

#EndRegion

#Region PropertyFormTableItemEventHandlers

&AtClient
Procedure PropertiesOnActivateRow(Item)
	
	PropertiesSetCommandAvailability(ThisObject);
	
EndProcedure

&AtClient
Procedure PropertiesBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	If Clone Then
		Copy();
	Else
		Create();
	EndIf;
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesBeforeChangeRow(Item, Cancel)
	
	Change();
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesBeforeDelete(Item, Cancel)
	
	ChangeDeletionMark();
	
	Cancel = True;
	
EndProcedure

&AtClient
Procedure PropertiesChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	StandardProcessing = False;
	
	If TypeOf(ValueSelected) = Type("Structure") Then
		If ValueSelected.Property("AdditionalValuesOwner") Then
			
			FormParameters = New Structure;
			FormParameters.Insert("IsAdditionalInfo",      IsAdditionalInfoSets);
			FormParameters.Insert("CurrentPropertiesSet",            CurrentSet);
			FormParameters.Insert("AdditionalValuesOwner", ValueSelected.AdditionalValuesOwner);
			
			OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
				FormParameters, Items.Properties);
			
		ElsIf ValueSelected.Property("CommonProperty") Then
			
			ChangedSet = CurrentSet;
			If ValueSelected.Property("Drag") Then
				AddCommonPropertyByDragging(ValueSelected.CommonProperty);
			Else
				ExecuteCommandAtServer("AddCommonProperty", ValueSelected.CommonProperty);
				ChangedSet = DestinationSet;
			EndIf;
			
			Notify("Write_AdditionalDataAndAttributeSets",
				New Structure("Ref", ChangedSet), ChangedSet);
		Else
			SelectSpecifiedRows(ValueSelected);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure PropertiesDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure PropertiesDragStart(Item, DragParameters, Perform)
	// Moving of properties and attributes is not supported, copying is always performed.
	// The cursor should have an appropriate icon.
	DragParameters.AllowedActions = DragAllowedActions.Copy;
	DragParameters.Action           = DragAction.Copy;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Create(Command = Undefined)
	
	FormParameters = New Structure;
	FormParameters.Insert("PropertySet", CurrentSet);
	FormParameters.Insert("IsAdditionalInfo", IsAdditionalInfoSets);
	FormParameters.Insert("CurrentPropertiesSet", CurrentSet);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
		FormParameters, Items.Properties);
	
EndProcedure

&AtClient
Procedure AddFromSet(Command)
	
	FormParameters = New Structure;
	
	SelectedValues = New Array;
	FoundRows = Properties.FindRows(New Structure("Common", True));
	For each Row In FoundRows Do
		SelectedValues.Add(Row.Property);
	EndDo;
	
	If IsAdditionalInfoSets Then
		FormParameters.Insert("SelectCommonProperty", True);
	Else
		FormParameters.Insert("SelectAdditionalValueOwner", True);
	EndIf;
	
	FormParameters.Insert("SelectedValues", SelectedValues);
	FormParameters.Insert("IsAdditionalInfo", IsAdditionalInfoSets);
	FormParameters.Insert("CurrentPropertiesSet", CurrentSet);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Form.ItemForm",
		FormParameters, Items.Properties);
EndProcedure

&AtClient
Procedure Change(Command = Undefined)
	
	If Items.Properties.CurrentData <> Undefined Then
		// Opening the property form.
		FormParameters = New Structure;
		FormParameters.Insert("Key", Items.Properties.CurrentData.Property);
		FormParameters.Insert("CurrentPropertiesSet", CurrentSet);
		
		OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
			FormParameters, Items.Properties);
	EndIf;
	
EndProcedure

&AtClient
Procedure Copy(Command = Undefined, PasteFromClipboard = False)
	
	FormParameters = New Structure;
	CopyingValue = Items.Properties.CurrentData.Property;
	FormParameters.Insert("AdditionalValuesOwner", CopyingValue);
	FormParameters.Insert("CurrentPropertiesSet", CurrentSet);
	FormParameters.Insert("CopyingValue", CopyingValue);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm", FormParameters);
	
EndProcedure

&AtClient
Procedure AddAttributeToSet(AdditionalValuesOwner, Set = Undefined)
	
	FormParameters = New Structure;
	If Set = Undefined Then
		CurrentPropertiesSet = CurrentSet;
	Else
		CurrentPropertiesSet = Set;
		FormParameters.Insert("Drag", True);
	EndIf;
	
	FormParameters.Insert("CopyWithQuestion", True);
	FormParameters.Insert("AdditionalValuesOwner", AdditionalValuesOwner);
	FormParameters.Insert("IsAdditionalInfo", IsAdditionalInfoSets);
	FormParameters.Insert("CurrentPropertiesSet", CurrentPropertiesSet);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm", FormParameters, Items.Properties);
	
EndProcedure

&AtClient
Procedure MarkForDeletion(Command)
	
	ChangeDeletionMark();
	
EndProcedure

&AtClient
Procedure MoveUp(Command)
	
	ExecuteCommandAtServer("MoveUp");
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	ExecuteCommandAtServer("MoveDown");
	
EndProcedure

&AtClient
Procedure DuplicateObjectDetection(Command)
	ModuleDuplicateObjectDetectionClient = CommonClient.CommonModule("FindAndDeleteDuplicatesDuplicatesClient");
	DuplicateObjectDetectionFormName = ModuleDuplicateObjectDetectionClient.SearchAndDeletionOfDuplicatesDataProcessorFormName();
	OpenForm(DuplicateObjectDetectionFormName);
EndProcedure

&AtClient
Procedure CopySelectedAttribute(Command)
	AttributeToCopy = New Structure;
	AttributeToCopy.Insert("AttributeToCopy", Items.Properties.CurrentData.Property);
	AttributeToCopy.Insert("CommonValues", Items.Properties.CurrentData.CommonValues);
	AttributeToCopy.Insert("AdditionalValuesOwner", Items.Properties.CurrentData.AdditionalValuesOwner);
	
	Items.PasteAttribute.Enabled = True;
EndProcedure

&AtClient
Procedure PasteAttribute(Command)
	If AttributeToCopy.CommonValues Then
		AdditionalValuesOwner = AttributeToCopy.AdditionalValuesOwner;
	Else
		AdditionalValuesOwner = AttributeToCopy.AttributeToCopy;
	EndIf;
	
	AddAttributeToSet(AdditionalValuesOwner);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure ApplySetsAndPropertiesAppearance()
	
	// Appearance of the sets root.
	ConditionalAppearanceItem = PropertySets.ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Text");
	AppearanceColorItem.Value = NStr("ru = 'Наборы'; en = 'Sets'; pl = 'Zestawy';es_ES = 'Conjuntos';es_CO = 'Conjuntos';tr = 'Kümeler';it = 'serie';de = 'Sätze'");
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Ref");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.NotFilled;
	DataFilterItem.Use  = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("Presentation");
	FieldAppearanceItem.Use = True;
	
	// Appearance of unavailable set groups that by default are displayed by the platform as a part of group tree.
	ConditionalAppearanceItem = PropertySets.ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	AppearanceColorItem.Use = True;
	
	DataSelectionItemsGroup = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	DataSelectionItemsGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
	DataSelectionItemsGroup.Use = True;
	
	DataFilterItem = DataSelectionItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Ref");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.NotInList;
	DataFilterItem.RightValue = AvailableSetsList;
	DataFilterItem.Use  = True;
	
	DataFilterItem = DataSelectionItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Parent");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.NotInList;
	DataFilterItem.RightValue = AvailableSetsList;
	DataFilterItem.Use  = True;
	
	DataFilterItem = DataSelectionItemsGroup.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Ref");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Filled;
	DataFilterItem.Use  = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("Presentation");
	FieldAppearanceItem.Use = True;
	
	// Configuring required properties.
	ConditionalAppearanceItem = ConditionalAppearance.Items.Add();
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Font");
	AppearanceColorItem.Value = New Font(, , True);
	AppearanceColorItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue  = New DataCompositionField("Properties.RequiredToFill");
	DataFilterItem.ComparisonType   = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use  = True;
	
	FieldAppearanceItem = ConditionalAppearanceItem.Fields.Items.Add();
	FieldAppearanceItem.Field = New DataCompositionField("PropertiesTitle");
	FieldAppearanceItem.Use = True;
	
EndProcedure

&AtClient
Procedure SelectSpecifiedRows(Details)
	
	If Details.Property("Set") Then
		
		If TypeOf(Details.Set) = Type("String") Then
			ConvertStringsToReferences(Details);
		EndIf;
		
		If Details.IsAdditionalInfo <> IsAdditionalInfoSets Then
			IsAdditionalInfoSets = Details.IsAdditionalInfo;
			ConfigureSetsDisplay();
		EndIf;
		
		Items.PropertySets.CurrentRow = Details.Set;
		CurrentSet = Undefined;
		OnChangeCurrentSet();
		FoundRows = Properties.FindRows(New Structure("Property", Details.Property));
		If FoundRows.Count() > 0 Then
			Items.Properties.CurrentRow = FoundRows[0].GetID();
		Else
			Items.Properties.CurrentRow = Undefined;
		EndIf;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ConvertStringsToReferences(Details)
	
	Details.Insert("Set", Catalogs.AdditionalAttributesAndInfoSets.GetRef(
		New UUID(Details.Set)));
	
	Details.Insert("Property", ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.GetRef(
		New UUID(Details.Property)));
	
EndProcedure

&AtServer
Procedure UpdateCommandsUsage()
	
	If GetFunctionalOption("UseCommonAdditionalValues")
	 OR GetFunctionalOption("UseAdditionalCommonAttributesAndInfo") Then
		
		Items.PropertiesCreateOnly.Visible = False;
		Items.PropertiesAddSubmenu.Visible = True;
		
		Items.PropertiesContextMenuCreateOnly.Visible = False;
		Items.PropertiesContextMenuAddSubmenu.Visible = True
	Else
		Items.PropertiesCreateOnly.Visible = True;
		Items.PropertiesAddSubmenu.Visible = False;
		
		Items.PropertiesContextMenuCreateOnly.Visible = True;
		Items.PropertiesContextMenuAddSubmenu.Visible = False
	EndIf;
	
EndProcedure

&AtServer
Procedure ConfigureSetsDisplay()
	
	CreateCommand                      = Commands.Find("Create");
	CopyCommand                  = Commands.Find("Copy");
	ChangeCommand                     = Commands.Find("Change");
	MarkForDeletionCommand           = Commands.Find("MarkToDelete");
	MoveUpCommand             = Commands.Find("MoveUp");
	MoveDownCommand              = Commands.Find("MoveDown");
	
	If IsAdditionalInfoSets Then
		Title = NStr("ru = 'Дополнительные сведения'; en = 'Additional information'; pl = 'Informacje dodatkowe';es_ES = 'Información adicional';es_CO = 'Información adicional';tr = 'Ek bilgi';it = 'Informazioni aggiuntive';de = 'Weitere Informationen'");
		
		CreateCommand.ToolTip          = NStr("ru = 'Создать уникальное сведение'; en = 'Create unique information'; pl = 'Utwórz unikalne informacje';es_ES = 'Crear la información única';es_CO = 'Crear la información única';tr = 'Benzersiz bilgi oluştur';it = 'Creare informazioni uniche';de = 'Erstellen Sie einzigartige Informationen'");
		CreateCommand.Title          = NStr("ru = 'Новая'; en = 'New'; pl = 'Nowy';es_ES = 'Nuevo';es_CO = 'Nuevo';tr = 'Yeni';it = 'Nuovo';de = 'Neu'");
		CreateCommand.ToolTip          = NStr("ru = 'Создать уникальное сведение'; en = 'Create unique information'; pl = 'Utwórz unikalne informacje';es_ES = 'Crear la información única';es_CO = 'Crear la información única';tr = 'Benzersiz bilgi oluştur';it = 'Creare informazioni uniche';de = 'Erstellen Sie einzigartige Informationen'");
		
		CopyCommand.ToolTip        = NStr("ru = 'Создать новое сведение копированием текущего'; en = 'Create an information by copying the current one'; pl = 'Utwórz nowe informacje, kopiując istniejące';es_ES = 'Crear nueva información copiando aquella existente';es_CO = 'Crear nueva información copiando aquella existente';tr = 'Geçerli olanı kopyalayarak yeni bir bilgi oluştur';it = 'Crea un informazione attraverso la copia della corrente';de = 'Erstellen Sie neue Informationen, indem Sie die vorhandenen kopieren'");
		ChangeCommand.ToolTip           = NStr("ru = 'Изменить (или открыть) текущее сведение'; en = 'Change or open the current information'; pl = 'Zmień lub otwórz bieżące informacje';es_ES = 'Cambiar (o abrir) la información actual';es_CO = 'Cambiar (o abrir) la información actual';tr = 'Mevcut bilgiyi düzenle veya aç';it = 'Modifica o apri l''informazione corrente';de = 'Ändern (oder öffnen) Sie die aktuellen Informationen'");
		MarkForDeletionCommand.ToolTip = NStr("ru = 'Пометить текущее сведение на удаление (Del)'; en = 'Mark the current information for deletion (Del)'; pl = 'Zaznacz bieżące informacje do usunięcia (Del)';es_ES = 'Marcar la información actual para borrar (Del)';es_CO = 'Marcar la información actual para borrar (Del)';tr = 'Silinmek için geçerli bilgiyi işaretle (Del)';it = 'Contrassegna l''informazione corrente per l''eliminazione (Del)';de = 'Aktuelle Informationen zum Löschen markieren (Del)'");
		MoveUpCommand.ToolTip   = NStr("ru = 'Переместить текущее сведение вверх'; en = 'Move the current information up'; pl = 'Przenieś bieżące dane do góry';es_ES = 'Mover arriba los datos actuales';es_CO = 'Mover arriba los datos actuales';tr = 'Geçerli bilgiyi yukarı taşı';it = 'Sposta l''informazione corrente in alto';de = 'Verschieben Sie die aktuellen Daten nach oben'");
		MoveDownCommand.ToolTip    = NStr("ru = 'Переместить текущее сведение вниз'; en = 'Move the current information down'; pl = 'Przenieś bieżące informacje w dół';es_ES = 'Mover abajo la información actual';es_CO = 'Mover abajo la información actual';tr = 'Geçerli bilgiyi aşağı taşı';it = 'Spostare le informazioni correnti verso il basso';de = 'Verschieben Sie die aktuelle Information nach unten'");
		
		MetadataTabularSection =
			Metadata.Catalogs.AdditionalAttributesAndInfoSets.TabularSections.AdditionalInfo;
		
		Items.PropertiesTitle.Title = MetadataTabularSection.Attributes.Property.Synonym;
		Items.PropertiesTitle.ToolTip = MetadataTabularSection.Attributes.Property.ToolTip;
		
		Items.PropertiesRequired.Visible = False;
		
		Items.PropertiesValueType.ToolTip =
			NStr("ru = 'Типы значения, которое можно ввести при заполнении сведения.'; en = 'Types of value that can be entered upon information filling.'; pl = 'Typy wartości, które można wprowadzić przy wprowadzeniu informacji.';es_ES = 'Tipos de valores que pueden entrar al rellenar la información.';es_CO = 'Tipos de valores que pueden entrar al rellenar la información.';tr = 'Bilginin doldurulmasında girilebilecek değer türleri.';it = 'Tipi di valore che possone essere inseriti durante la compilazione informazioni.';de = 'Werttypen, die beim Ausfüllen der Informationen eingegeben werden können.'");
		
		Items.PropertiesSharedValues.ToolTip =
			NStr("ru = 'Сведение использует список значений сведения-образца.'; en = 'The information uses sample information values.'; pl = 'Informacje wykorzystują przykładową listę wartości.';es_ES = 'Lista de modelos de usos de la información de valores.';es_CO = 'Lista de modelos de usos de la información de valores.';tr = 'Bilgi, değerlerin örnek listesini kullanır.';it = 'L''informazione usa esempi di valori informazione.';de = 'Information verwendet eine Beispielwerteliste.'");
		
		Items.PropertiesShared.Title = NStr("ru = 'Общее'; en = 'Common'; pl = 'Wspólny';es_ES = 'Común';es_CO = 'Común';tr = 'Ortak';it = 'Comune';de = 'Allgemein'");
		Items.PropertiesShared.ToolTip = NStr("ru = 'Общее дополнительное сведение, которое используется в
		                                              |нескольких наборах дополнительных сведений.'; 
		                                              |en = 'Common additional information, which is used
		                                              |in several additional information sets.'; 
		                                              |pl = 'Wspólna informacja dodatkowa, która jest wykorzystywana w
		                                              |kilku zestawach informacji dodatkowych.';
		                                              |es_ES = 'Datos personalizados comunes en
		                                              | varios conjuntos de los datos adicionales.';
		                                              |es_CO = 'Datos personalizados comunes en
		                                              | varios conjuntos de los datos adicionales.';
		                                              |tr = 'Birkaç ek veri kümesinde kullanılan 
		                                              |ortak özel veriler.';
		                                              |it = 'Informazione aggiuntiva comune, che è utilizzata
		                                              |in diversi insiemi di informazioni aggiuntiva.';
		                                              |de = 'Allgemeine Zusatzinformationen, die in
		                                              |mehreren Sets von Zusatzinformationen verwendet werden.'");
	Else
		Title = NStr("ru = 'Дополнительные реквизиты'; en = 'Additional attributes'; pl = 'Dodatkowe atrybuty';es_ES = 'Atributos adicionales';es_CO = 'Atributos adicionales';tr = 'Ek öznitelikler';it = 'Attributi aggiuntivi';de = 'Zusätzliche Attribute'");
		CreateCommand.Title          = NStr("ru = 'Новая'; en = 'New'; pl = 'Nowy';es_ES = 'Nuevo';es_CO = 'Nuevo';tr = 'Yeni';it = 'Nuovo';de = 'Neu'");
		CreateCommand.ToolTip          = NStr("ru = 'Создать уникальный реквизит'; en = 'Create unique attribute'; pl = 'Utwórz unikalne pole';es_ES = 'Crear un campo único';es_CO = 'Crear un campo único';tr = 'Benzersiz bir alan oluştur';it = 'Crea un attributo univoco';de = 'Ein eindeutiges Feld erstellen'");
		
		CopyCommand.ToolTip        = NStr("ru = 'Создать новый реквизит копированием текущего'; en = 'Create an attribute by copying the current one'; pl = 'Utwórz nowy atrybut, kopiując bieżący';es_ES = 'Crear un atributo nuevo copiando el actual';es_CO = 'Crear un atributo nuevo copiando el actual';tr = 'Mevcut olanı kopyalayarak yeni özellik oluştur';it = 'Creare un attributo attraverso la copia di quello corrente';de = 'Erstellen Sie ein neues Attribut, indem Sie das aktuelle kopieren'");
		ChangeCommand.ToolTip           = NStr("ru = 'Изменить (или открыть) текущий реквизит'; en = 'Change or open the current attribute'; pl = 'Zmień lub otwórz bieżący atrybut';es_ES = 'Editar (o abrir) el campo actual';es_CO = 'Editar (o abrir) el campo actual';tr = 'Mevcut özelliği düzenle veya aç';it = 'Modifica o apri l''attributo corrente';de = 'Aktuelles Feld bearbeiten (oder öffnen)'");
		MarkForDeletionCommand.ToolTip = NStr("ru = 'Пометить текущий реквизит на удаление (Del)'; en = 'Mark the current attribute for deletion (Del)'; pl = 'Zaznacz bieżące pole do usunięcia (Del)';es_ES = 'Marcar el campo actual para borrar (Del)';es_CO = 'Marcar el campo actual para borrar (Del)';tr = 'Geçerli alanı silinmek üzere işaretle (Sil)';it = 'Contrassegna l''attributo corrente per l''eliminazione (Del)';de = 'Markiere das aktuelle Feld zum Löschen (Del)'");
		MoveUpCommand.ToolTip   = NStr("ru = 'Переместить текущий реквизит вверх'; en = 'Move the current attribute up'; pl = 'Przenieś bieżący atrybut w górę';es_ES = 'Mover arriba el atributo actual';es_CO = 'Mover arriba el atributo actual';tr = 'Mevcut özelliği yukarı taşı';it = 'Spostare l''attributo corrente in alto';de = 'Das aktuelle Attribut nach oben verschieben'");
		MoveDownCommand.ToolTip    = NStr("ru = 'Переместить текущий реквизит вниз'; en = 'Move the current attribute down'; pl = 'Przenieś bieżący atrybut w dół';es_ES = 'Mover abajo el atributo actual';es_CO = 'Mover abajo el atributo actual';tr = 'Mevcut özelliği aşağı taşı';it = 'Muovi l''attributo corrente in basso';de = 'Aktuelles Attribut nach unten verschieben'");
		
		MetadataTabularSection =
			Metadata.Catalogs.AdditionalAttributesAndInfoSets.TabularSections.AdditionalAttributes;
		
		Items.PropertiesTitle.Title = MetadataTabularSection.Attributes.Property.Synonym;
		Items.PropertiesTitle.ToolTip = MetadataTabularSection.Attributes.Property.ToolTip;
		
		Items.PropertiesRequired.Visible = True;
		Items.PropertiesRequired.ToolTip =
			Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.Attributes.RequiredToFill.ToolTip;
		
		Items.PropertiesValueType.ToolTip =
			NStr("ru = 'Типы значения, которое можно ввести при заполнении реквизита.'; en = 'Types of value that can be entered upon attribute filling.'; pl = 'Rodzaje wartości, które można wprowadzić przy wypełnianiu atrybutu.';es_ES = 'Tipos de valores que se puede introducir al rellenar en el atributo.';es_CO = 'Tipos de valores que se puede introducir al rellenar en el atributo.';tr = 'Özelliğin doldurulmasında girilebilecek değer türleri.';it = 'Tipi di valori che possono essere inseriti con la compilazione attributi.';de = 'Typen von Werten, die beim Ausfüllen des Attributs eingegeben werden können.'");
		
		Items.PropertiesSharedValues.ToolTip =
			NStr("ru = 'Реквизит использует список значений реквизита-образца.'; en = 'The attribute uses a list of sample attribute values.'; pl = 'Ten atrybut używa listy wartości atrybutu wzorcowego.';es_ES = 'El atributo utiliza la lista de valores de muestra de atributos.';es_CO = 'El atributo utiliza la lista de valores de muestra de atributos.';tr = 'Özellik, öznitelik-örnek değer listesini kullanır.';it = 'L''attributo usa un elenco di esempi di valore attributo.';de = 'Das Attribut verwendet die Attribut-Stichprobenwertliste.'");
		
		Items.PropertiesShared.Title = NStr("ru = 'Общее'; en = 'Common'; pl = 'Wspólny';es_ES = 'Común';es_CO = 'Común';tr = 'Ortak';it = 'Comune';de = 'Allgemein'");
		Items.PropertiesShared.ToolTip = NStr("ru = 'Общий дополнительный реквизит, который используется в
		                                              |нескольких наборах дополнительных реквизитов.'; 
		                                              |en = 'Common additional attribute, which is used
		                                              |in multiple sets of additional attributes.'; 
		                                              |pl = 'Wspólne pole niestandardowe używane
		                                              |w kilku niestandardowych zestawach pól.';
		                                              |es_ES = 'Un campo personalizado común utilizado en
		                                              | varios conjuntos de campos personalizados.';
		                                              |es_CO = 'Un campo personalizado común utilizado en
		                                              | varios conjuntos de campos personalizados.';
		                                              |tr = 'Birkaç özel alan kümesinde kullanılan 
		                                              |ortak özel alan.';
		                                              |it = 'Attributo aggiuntivo generale utilizzato
		                                              |in multipli set di attributi aggiuntivi.';
		                                              |de = 'Ein gemeinsames zusätzliches Attribut, das von
		                                              |mehreren Sets von zusätzlichen Attributen verwendet wird.'");
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Sets.Ref AS Ref
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets AS Sets
	|WHERE
	|	Sets.Parent = VALUE(Catalog.AdditionalAttributesAndInfoSets.EmptyRef)";
	
	Sets = Query.Execute().Unload().UnloadColumn("Ref");
	AvailableSets = New Array;
	AvailableSetsList.Clear();
	
	For each Ref In Sets Do
		SetPropertiesTypes = PropertyManagerInternal.SetPropertiesTypes(Ref, False);
		
		If IsAdditionalInfoSets
		   AND SetPropertiesTypes.AdditionalInfo
		 OR NOT IsAdditionalInfoSets
		   AND SetPropertiesTypes.AdditionalAttributes Then
			
			AvailableSets.Add(Ref);
			AvailableSetsList.Add(Ref);
		EndIf;
	EndDo;
	
	CommonClientServer.SetDynamicListParameter(
		PropertySets, "IsAdditionalInfoSets", IsAdditionalInfoSets, True);
	
	CommonClientServer.SetDynamicListParameter(
		PropertySets, "Sets", AvailableSets, True);
	
	OnChangeCurrentSetAtServer();
	
EndProcedure

&AtClient
Procedure OnChangeCurrentSet()
	
	If Items.PropertySets.CurrentData = Undefined Then
		If ValueIsFilled(CurrentSet) Then
			CurrentSet = Undefined;
			OnChangeCurrentSetAtServer();
		EndIf;
		
	ElsIf Items.PropertySets.CurrentData.Ref <> CurrentSet Then
		CurrentSet          = Items.PropertySets.CurrentData.Ref;
		CurrentSetIsGroup = Items.PropertySets.CurrentData.IsFolder;
		OnChangeCurrentSetAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeDeletionMark()
	
	If Items.Properties.CurrentData <> Undefined Then
		
		If IsAdditionalInfoSets Then
			If Items.Properties.CurrentData.Common Then
				QuestionText = NStr("ru ='Исключить текущее общее сведения из набора?'; en = 'Do you want to remove the current common additional information from the set?'; pl = 'Wykluczyć bieżące informacje wspólne z zestawu?';es_ES = '¿Excluir la información común actual del conjunto?';es_CO = '¿Excluir la información común actual del conjunto?';tr = 'Geçerli ortak bilgiler kümenin dışına bırakılsın mı?';it = 'Volete rimuovere l''informazione comune aggiuntiva dall''insieme?';de = 'Die aktuellen allgemeinen Informationen aus dem Set ausschließen?'");
				
			ElsIf Items.Properties.CurrentData.DeletionMark Then
				QuestionText = NStr("ru ='Снять с текущего сведения пометку на удаление?'; en = 'Do you want to clear the deletion mark from the current information?'; pl = 'Usunąć zaznaczenie do usunięcia dla aktualnej informacji?';es_ES = '¿Eliminar las marcas para borrar para la información actual?';es_CO = '¿Eliminar las marcas para borrar para la información actual?';tr = 'Mevcut bilgiler için silme işareti kaldırılsın mi?';it = 'Volete rimuovere il contrassegno per l''eliminazione dall''informazione corrente?';de = 'Löschzeichen für die aktuelle Information löschen?'");
			Else
				QuestionText = NStr("ru ='Пометить текущее сведение на удаление?'; en = 'Do you want to mark the current information for deletion?'; pl = 'Zaznaczyć aktualne informacje do usunięcia?';es_ES = '¿Marcar la información actual para borrar?';es_CO = '¿Marcar la información actual para borrar?';tr = 'Geçerli bilgi silinmek üzere işaretlensin mi?';it = 'Volete contrassegnare l''informazione corrente per l''eliminazione?';de = 'Aktuelle Informationen zum Löschen markieren?'");
			EndIf;
		Else
			If Items.Properties.CurrentData.Common Then
				QuestionText = NStr("ru ='Исключить текущий общий реквизит из набора?'; en = 'Do you want to remove the current common attribute from the set?'; pl = 'Wykluczyć bieżący wspólny atrybut z zestawu?';es_ES = '¿Excluir el atributo común actual del conjunto?';es_CO = '¿Excluir el atributo común actual del conjunto?';tr = 'Geçerli ortak nitelik kümenin dışına bırakılsın mı?';it = 'Rimuovere l''attributo generale corrente dal set?';de = 'Das aktuelle gemeinsame Attribut aus dem Set ausschließen?'");
				
			ElsIf Items.Properties.CurrentData.DeletionMark Then
				QuestionText = NStr("ru ='Снять с текущего реквизита пометку на удаление?'; en = 'Do you want to clear the deletion mark from the current attribute?'; pl = 'Usunąć zaznaczenie do usunięcia dla bieżącego atrybutu?';es_ES = '¿Eliminar las marcas para borrar para el atributo actual?';es_CO = '¿Eliminar las marcas para borrar para el atributo actual?';tr = 'Mevcut özellik için silme işareti kaldırılsın mi?';it = 'Volete rimuovere il contrassegno per l''eliminazione dall''attributo corrente?';de = 'Löschzeichen für das aktuelle Attribut löschen?'");
			Else
				QuestionText = NStr("ru ='Пометить текущий реквизит на удаление?'; en = 'Do you want to mark the current attribute for deletion?'; pl = 'Zaznaczyć bieżące pole do usunięcia?';es_ES = '¿Marcar el campo actual para borrar?';es_CO = '¿Marcar el campo actual para borrar?';tr = 'Geçerli alan silinmek üzere işaretlensin mi?';it = 'Volete contrassegnare l''attributo corrente per l''eliminazione?';de = 'Das aktuelle Feld zum Löschen markieren?'");
			EndIf;
		EndIf;
		
		ShowQueryBox(
			New NotifyDescription("ChangeDeletionMarkCompletion", ThisObject, CurrentSet),
			QuestionText, QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeDeletionMarkCompletion(Response, CurrentSet) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ExecuteCommandAtServer("EditDeletionMark");
	
	Notify("Write_AdditionalDataAndAttributeSets",
		New Structure("Ref", CurrentSet), CurrentSet);
	
EndProcedure

&AtServer
Procedure OnChangeCurrentSetAtServer()
	
	If ValueIsFilled(CurrentSet)
	   AND NOT CurrentSetIsGroup Then
		
		CurrentAvailability = True;
		If Items.Properties.BackColor <> Items.PropertySets.BackColor Then
			Items.Properties.BackColor = Items.PropertySets.BackColor;
		EndIf;
		UpdateCurrentSetPropertiesList(CurrentAvailability);
	Else
		CurrentAvailability = False;
		If Items.Properties.BackColor <> FormColor Then
			Items.Properties.BackColor = FormColor;
		EndIf;
		Properties.Clear();
	EndIf;
	
	If Items.Properties.ReadOnly = CurrentAvailability Then
		Items.Properties.ReadOnly = NOT CurrentAvailability;
	EndIf;
	
	PropertiesSetCommandAvailability(ThisObject);
	
	Items.PropertySets.Refresh();
	
EndProcedure

&AtClientAtServerNoContext
Procedure PropertiesSetCommandAvailability(Context)
	
	Items = Context.Items;
	
	CommonAvailability = NOT Items.Properties.ReadOnly;
	InsertAvailability = CommonAvailability AND (Context.AttributeToCopy <> Undefined);
	
	AvailabilityForString = CommonAvailability
		AND Context.Items.Properties.CurrentRow <> Undefined;
	
	// Customizing commands of command bar.
	Items.AddFromSet.Enabled           = CommonAvailability;
	Items.PropertiesCreate.Enabled            = CommonAvailability;
	Items.PropertiesCreateOnly.Enabled      = CommonAvailability;
	
	Items.PropertiesCopy.Enabled        = AvailabilityForString;
	Items.PropertiesChange.Enabled           = AvailabilityForString;
	Items.PropertiesMarkForDeletion.Enabled = AvailabilityForString;
	
	Items.PropertiesMoveUp.Enabled   = AvailabilityForString;
	Items.PropertiesMoveDown.Enabled    = AvailabilityForString;
	
	Items.CopyAttribute.Enabled         = AvailabilityForString;
	Items.PasteAttribute.Enabled           = InsertAvailability;
	
	// Customizing commands of context menu.
	Items.PropertiesContextMenuCreate.Enabled            = CommonAvailability;
	Items.PropertiesContextMenuCreateOnly.Enabled      = CommonAvailability;
	Items.PropertiesContextMenuAddFromSet.Enabled   = CommonAvailability;
	
	Items.PropertiesContextMenuCopy.Enabled        = AvailabilityForString;
	Items.PropertiesContextMenuChange.Enabled           = AvailabilityForString;
	Items.PropertiesContextMenuMarkForDeletion.Enabled = AvailabilityForString;
	
	Items.PropertiesContextMenuCopyAttribute.Enabled = AvailabilityForString;
	Items.PropertiesContextMenuPasteAttribute.Enabled   = InsertAvailability;
	
EndProcedure

&AtServer
Procedure UpdateCurrentSetPropertiesList(CurrentAvailability)
	
	Query = New Query;
	Query.SetParameter("Set", CurrentSet);
	
	Query.Text =
	"SELECT
	|	SetsProperties.LineNumber,
	|	SetsProperties.Property,
	|	SetsProperties.DeletionMark,
	|	ISNULL(Properties.Title, PRESENTATION(SetsProperties.Property)) AS Title,
	|	Properties.AdditionalValuesOwner,
	|	Properties.RequiredToFill,
	|	Properties.ValueType AS ValueType,
	|	CASE
	|		WHEN Properties.Ref IS NULL 
	|			THEN TRUE
	|		WHEN Properties.PropertySet = VALUE(Catalog.AdditionalAttributesAndInfoSets.EmptyRef)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Common,
	|	CASE
	|		WHEN SetsProperties.DeletionMark = TRUE
	|			THEN 4
	|		ELSE 3
	|	END AS PictureNumber
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS SetsProperties
	|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
	|		ON SetsProperties.Property = Properties.Ref
	|WHERE
	|	SetsProperties.Ref = &Set
	|
	|ORDER BY
	|	SetsProperties.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Sets.DataVersion AS DataVersion
	|FROM
	|	Catalog.AdditionalAttributesAndInfoSets AS Sets
	|WHERE
	|	Sets.Ref = &Set";
	
	If IsAdditionalInfoSets Then
		Query.Text = StrReplace(
			Query.Text,
			"Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes",
			"Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo");
	EndIf;
	
	BeginTransaction();
	Try
		QueryResults = Query.ExecuteBatch();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Items.Properties.CurrentRow = Undefined Then
		Row = Undefined;
	Else
		Row = Properties.FindByID(Items.Properties.CurrentRow);
	EndIf;
	CurrentProperty = ?(Row = Undefined, Undefined, Row.Property);
	
	Properties.Clear();
	
	If QueryResults[1].IsEmpty() Then
		CurrentAvailability = False;
		Return;
	EndIf;
	
	CurrentSetDataVersion = QueryResults[1].Unload()[0].DataVersion;
	
	Selection = QueryResults[0].Select();
	While Selection.Next() Do
		
		NewRow = Properties.Add();
		FillPropertyValues(NewRow, Selection);
		
		NewRow.CommonValues = ValueIsFilled(Selection.AdditionalValuesOwner);
		
		If Selection.ValueType <> NULL
		   AND PropertyManagerInternal.ValueTypeContainsPropertyValues(Selection.ValueType) Then
			
			NewRow.ValueType = String(New TypeDescription(
				Selection.ValueType,
				,
				"CatalogRef.ObjectPropertyValueHierarchy,
				|CatalogRef.ObjectsPropertiesValues"));
			
			Query = New Query;
			If ValueIsFilled(Selection.AdditionalValuesOwner) Then
				Query.SetParameter("Owner", Selection.AdditionalValuesOwner);
			Else
				Query.SetParameter("Owner", Selection.Property);
			EndIf;
			Query.Text =
			"SELECT TOP 4
			|	ObjectsPropertiesValues.Description AS Description
			|FROM
			|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
			|WHERE
			|	ObjectsPropertiesValues.Owner = &Owner
			|	AND NOT ObjectsPropertiesValues.IsFolder
			|	AND NOT ObjectsPropertiesValues.DeletionMark
			|
			|UNION
			|
			|SELECT TOP 4
			|	ObjectPropertyValueHierarchy.Description
			|FROM
			|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
			|WHERE
			|	ObjectPropertyValueHierarchy.Owner = &Owner
			|	AND NOT ObjectPropertyValueHierarchy.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT TOP 1
			|	TRUE AS TrueValue
			|FROM
			|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
			|WHERE
			|	ObjectsPropertiesValues.Owner = &Owner
			|	AND NOT ObjectsPropertiesValues.IsFolder
			|
			|UNION ALL
			|
			|SELECT TOP 1
			|	TRUE
			|FROM
			|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
			|WHERE
			|	ObjectPropertyValueHierarchy.Owner = &Owner";
			QueryResults = Query.ExecuteBatch();
			
			TopValues = QueryResults[0].Unload().UnloadColumn("Description");
			
			If TopValues.Count() = 0 Then
				If QueryResults[1].IsEmpty() Then
					ValuesPresentation = NStr("ru = 'Значения еще не введены'; en = 'Values are not entered yet'; pl = 'Nie wprowadzono żadnych wartości';es_ES = 'No hay valores entrados';es_CO = 'No hay valores entrados';tr = 'Değer girilmedi';it = 'I valori non sono ancora stati inseriti';de = 'Noch keine Werte eingegeben'");
				Else
					ValuesPresentation = NStr("ru = 'Значения помечены на удаление'; en = 'Values are marked for deletion'; pl = 'Wartości są zaznaczone do usunięcia';es_ES = 'Valores están marcados para borrar';es_CO = 'Valores están marcados para borrar';tr = 'Değerler silinmek üzere işaretlendi';it = 'I valori sono contrassegnati per l''eliminazione';de = 'Die Werte sind zum Löschen markiert'");
				EndIf;
			Else
				ValuesPresentation = "";
				Number = 0;
				For each Value In TopValues Do
					Number = Number + 1;
					If Number = 4 Then
						ValuesPresentation = ValuesPresentation + ",...";
						Break;
					EndIf;
					ValuesPresentation = ValuesPresentation + ?(Number > 1, ", ", "") + Value;
				EndDo;
			EndIf;
			ValuesPresentation = "<" + ValuesPresentation + ">";
			If ValueIsFilled(NewRow.ValueType) Then
				ValuesPresentation = ValuesPresentation + ", ";
			EndIf;
			NewRow.ValueType = ValuesPresentation + NewRow.ValueType;
		EndIf;
		
		If Selection.Property = CurrentProperty Then
			Items.Properties.CurrentRow =
				Properties[Properties.Count()-1].GetID();
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure AddCommonPropertyByDragging(PropertyToAdd)
	
	Lock = New DataLock;
	LockItem = Lock.Add("Catalog.AdditionalAttributesAndInfoSets");
	LockItem.SetValue("Ref", DestinationSet);
	
	Try
		LockDataForEdit(DestinationSet);
		BeginTransaction();
		Try
			Lock.Lock();
			LockDataForEdit(DestinationSet);
			
			SetDestinationObject = DestinationSet.GetObject();
			
			TabularSection = SetDestinationObject[?(IsAdditionalInfoSets,
				"AdditionalInfo", "AdditionalAttributes")];
			
			FoundRow = TabularSection.Find(PropertyToAdd, "Property");
			
			If FoundRow = Undefined Then
				NewRow = TabularSection.Add();
				NewRow.Property = PropertyToAdd;
				SetDestinationObject.Write();
				
			ElsIf FoundRow.DeletionMark Then
				FoundRow.DeletionMark = False;
				SetDestinationObject.Write();
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	Except
		UnlockDataForEdit(DestinationSet);
		Raise;
	EndTry;
	
	Items.PropertySets.Refresh();
	DestinationSet = Undefined;
	
EndProcedure

&AtServer
Procedure ExecuteCommandAtServer(Command, Parameter = Undefined)
	
	Lock = New DataLock;
	
	If Command = "EditDeletionMark" Then
		LockItem = Lock.Add("Catalog.AdditionalAttributesAndInfoSets");
		LockItem = Lock.Add("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo");
		LockItem = Lock.Add("Catalog.ObjectsPropertiesValues");
		LockItem = Lock.Add("Catalog.ObjectPropertyValueHierarchy");
	Else
		LockItem = Lock.Add("Catalog.AdditionalAttributesAndInfoSets");
		LockItem.SetValue("Ref", CurrentSet);
	EndIf;
	
	Try
		LockDataForEdit(CurrentSet);
		BeginTransaction();
		Try
			Lock.Lock();
			LockDataForEdit(CurrentSet);
			
			CurrentSetObject = CurrentSet.GetObject();
			If CurrentSetObject.DataVersion <> CurrentSetDataVersion Then
				OnChangeCurrentSetAtServer();
				If IsAdditionalInfoSets Then
					Raise
						NStr("ru = 'Действие не выполнено, так как состав дополнительных сведений
						           |был изменен другим пользователем.
						           |Новый состав дополнительных сведений прочитан.
						           |
						           |Повторите действие, если требуется.'; 
						           |en = 'The action is not performed as additional information
						           |was changed by another user.
						           |New additional information is read.
						           |
						           |Try again if required.'; 
						           |pl = 'Działanie nie zostało wykonane, ponieważ
						           | zawartość informacji dodatkowych została zmieniona przez innego użytkownika.
						           |Odczytano nową zawartość informacji dodatkowych.
						           |
						           |W razie potrzeby powtórz działanie.';
						           |es_ES = 'Acción no está realizada desde que el contenido de la información adicional 
						           |se ha cambiado por otro usuario.
						           |Nuevo contenido de la información adicional está leído.
						           |
						           |Reintentar la acción si es necesario.';
						           |es_CO = 'Acción no está realizada desde que el contenido de la información adicional 
						           |se ha cambiado por otro usuario.
						           |Nuevo contenido de la información adicional está leído.
						           |
						           |Reintentar la acción si es necesario.';
						           |tr = 'Ek bilgilerin 
						           |içeriği başka bir kullanıcı tarafından değiştirildiği için eylem gerçekleştirilemez. 
						           |Ek bilgilerin yeni içeriği hazır. 
						           |
						           |Gerekirse işlemi tekrarlayın';
						           |it = 'L''azione non è stata eseguita poiché l''informazione aggiuntiva
						           |è stata modificata da un altro utente.
						           |Lettura nuove informazioni aggiuntive in corso.
						           |
						           |Se necessario, ripetere l''operazione.';
						           |de = 'Die Aktion wurde nicht durchgeführt, da die Zusatzinformationen
						           |von einem anderen Benutzer geändert wurden.
						           |Der neue Satz von Zusatzinformationen wurde gelesen.
						           |
						           |Wiederholen Sie die Aktion bei Bedarf.'");
				Else
					Raise
						NStr("ru = 'Действие не выполнено, так как состав дополнительных реквизитов
						           |был изменен другим пользователем.
						           |Новый состав дополнительных реквизитов прочитан.
						           |
						           |Повторите действие, если требуется.'; 
						           |en = 'The action is not performed as additional attributes
						           |were changed by another user.
						           |New additional attributes are read.
						           |
						           |Try again if required.'; 
						           |pl = 'Działanie nie zostało wykonane, ponieważ dodatkowe atrybuty
						           |zostały zmienione przez innego użytkownika.
						           |Nowe dodatkowe atrybuty zostały odczytane.
						           |
						           |W razie potrzeby powtórz działanie.';
						           |es_ES = 'Acción no está realizada desde que el contenido de los requisitos adicionales 
						           |se ha cambiado por otro usuario.
						           |Nuevo contenido de los requisitos adicionales está leído.
						           |
						           |Reintentar la acción si es necesario.';
						           |es_CO = 'Acción no está realizada desde que el contenido de los requisitos adicionales 
						           |se ha cambiado por otro usuario.
						           |Nuevo contenido de los requisitos adicionales está leído.
						           |
						           |Reintentar la acción si es necesario.';
						           |tr = 'Ek bilgilerin 
						           |içeriği başka bir kullanıcı tarafından değiştirildiği için eylem gerçekleştirilemez. 
						           |Ek bilgilerin yeni içeriği hazır. 
						           |
						           |Gerekirse işlemi tekrarlayın.';
						           |it = 'L''azione non è stata eseguita poiché gli attributi aggiuntivi
						           | sono stati modificati da un altro utente.
						           |Lettura di nuovi attributi aggiuntivi in corso.
						           |
						           |Se necessario, ripetere l''operazione.';
						           |de = 'Die Aktion wurde nicht durchgeführt, da die Zusatzinformationen
						           |von einem anderen Benutzer geändert wurden.
						           |Der neue Satz von Zusatzinformationen wurde gelesen.
						           |
						           |Wiederholen Sie die Aktion bei Bedarf.'");
				EndIf;
			EndIf;
			
			TabularSection = CurrentSetObject[?(IsAdditionalInfoSets,
				"AdditionalInfo", "AdditionalAttributes")];
			
			If Command = "AddCommonProperty" Then
				FoundRow = TabularSection.Find(Parameter, "Property");
				
				If FoundRow = Undefined Then
					NewRow = TabularSection.Add();
					NewRow.Property = Parameter;
					CurrentSetObject.Write();
					
				ElsIf FoundRow.DeletionMark Then
					FoundRow.DeletionMark = False;
					CurrentSetObject.Write();
				EndIf;
			Else
				Row = Properties.FindByID(Items.Properties.CurrentRow);
				
				If Row <> Undefined Then
					Index = Row.LineNumber-1;
					
					If Command = "MoveUp" Then
						TopRowIndex = Properties.IndexOf(Row)-1;
						If TopRowIndex >= 0 Then
							Offset = Properties[TopRowIndex].LineNumber - Row.LineNumber;
							TabularSection.Move(Index, Offset);
						EndIf;
						CurrentSetObject.Write();
						
					ElsIf Command = "MoveDown" Then
						BottomRowIndex = Properties.IndexOf(Row)+1;
						If BottomRowIndex < Properties.Count() Then
							Offset = Properties[BottomRowIndex].LineNumber - Row.LineNumber;
							TabularSection.Move(Index, Offset);
						EndIf;
						CurrentSetObject.Write();
						
					ElsIf Command = "EditDeletionMark" Then
						Row = Properties.FindByID(Items.Properties.CurrentRow);
						
						If Row.Common Then
							TabularSection.Delete(Index);
							CurrentSetObject.Write();
							Properties.Delete(Row);
							If TabularSection.Count() > Index Then
								Items.Properties.CurrentRow = Properties[Index].GetID();
							ElsIf TabularSection.Count() > 0 Then
								Items.Properties.CurrentRow = Properties[Properties.Count()-1].GetID();
							EndIf;
						Else
							TabularSection[Index].DeletionMark = NOT TabularSection[Index].DeletionMark;
							CurrentSetObject.Write();
							
							ChangeDeletionMarkAndValuesOwner(
								CurrentSetObject.Ref,
								TabularSection[Index].Property,
								TabularSection[Index].DeletionMark);
						EndIf;
					EndIf;
				EndIf;
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	Except
		UnlockDataForEdit(CurrentSet);
		Raise;
	EndTry;
	
	OnChangeCurrentSetAtServer();
	
EndProcedure

&AtServer
Procedure ChangeDeletionMarkAndValuesOwner(CurrentSet, CurrentProperty, PropertyDeletionMark)
	
	OldValuesOwner = CurrentProperty;
	
	NewValuesMark   = Undefined;
	NewValuesOwner  = Undefined;
	
	PropertyObject = CurrentProperty.GetObject();
	
	If ValueIsFilled(PropertyObject.PropertySet) Then
		
		If PropertyDeletionMark Then
			// Upon marking a unique property:
			// - mark the property,
			// - if there are ones that were created by a template and not marked for deletion, then set a new 
			//   value owner and specify a new template for all properties, otherwise, mark all the values for 
			//   deletion.
			//   
			PropertyObject.DeletionMark = True;
			
			If NOT ValueIsFilled(PropertyObject.AdditionalValuesOwner) Then
				Query = New Query;
				Query.SetParameter("Property", PropertyObject.Ref);
				Query.Text =
				"SELECT
				|	Properties.Ref,
				|	Properties.DeletionMark
				|FROM
				|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
				|WHERE
				|	Properties.AdditionalValuesOwner = &Property";
				DataExported = Query.Execute().Unload();
				FoundRow = DataExported.Find(False, "DeletionMark");
				If FoundRow <> Undefined Then
					NewValuesOwner  = FoundRow.Ref;
					PropertyObject.AdditionalValuesOwner = NewValuesOwner;
					For each Row In DataExported Do
						CurrentObject = Row.Ref.GetObject();
						If CurrentObject.Ref = NewValuesOwner Then
							CurrentObject.AdditionalValuesOwner = Undefined;
						Else
							CurrentObject.AdditionalValuesOwner = NewValuesOwner;
						EndIf;
						CurrentObject.Write();
					EndDo;
				Else
					NewValuesMark = True;
				EndIf;
			EndIf;
			PropertyObject.Write();
		Else
			If PropertyObject.DeletionMark Then
				PropertyObject.DeletionMark = False;
				PropertyObject.Write();
			EndIf;
			// Upon removing a mark from a unique property:
			// - remove a mark from the property,
			// - if the property is created by sample, then if the template is marked for deletion, set a new 
			//   value owner or the current one for all properties and remove the deletion mark from the values
			//     
			//     
			//   otherwise, remove the deletion mark from values.
			If NOT ValueIsFilled(PropertyObject.AdditionalValuesOwner) Then
				NewValuesMark = False;
				
			ElsIf Common.ObjectAttributeValue(
			            PropertyObject.AdditionalValuesOwner, "DeletionMark") Then
				
				Query = New Query;
				Query.SetParameter("Property", PropertyObject.AdditionalValuesOwner);
				Query.Text =
				"SELECT
				|	Properties.Ref AS Ref
				|FROM
				|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
				|WHERE
				|	Properties.AdditionalValuesOwner = &Property";
				Array = Query.Execute().Unload().UnloadColumn("Ref");
				Array.Add(PropertyObject.AdditionalValuesOwner);
				NewValuesOwner = PropertyObject.Ref;
				For each CurrentRef In Array Do
					If CurrentRef = NewValuesOwner Then
						Continue;
					EndIf;
					CurrentObject = CurrentRef.GetObject();
					CurrentObject.AdditionalValuesOwner = NewValuesOwner;
					CurrentObject.Write();
				EndDo;
				OldValuesOwner = PropertyObject.AdditionalValuesOwner;
				PropertyObject.AdditionalValuesOwner = Undefined;
				PropertyObject.Write();
				NewValuesMark = False;
			EndIf;
		EndIf;
	EndIf;
	
	If NewValuesMark  = Undefined
	   AND NewValuesOwner = Undefined Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Owner", OldValuesOwner);
	Query.Text =
	"SELECT
	|	ObjectsPropertiesValues.Ref AS Ref,
	|	ObjectsPropertiesValues.DeletionMark AS DeletionMark
	|FROM
	|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
	|WHERE
	|	ObjectsPropertiesValues.Owner = &Owner
	|
	|UNION ALL
	|
	|SELECT
	|	ObjectPropertyValueHierarchy.Ref,
	|	ObjectPropertyValueHierarchy.DeletionMark
	|FROM
	|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
	|WHERE
	|	ObjectPropertyValueHierarchy.Owner = &Owner";
	
	DataExported = Query.Execute().Unload();
	
	If NewValuesOwner <> Undefined Then
		For each Row In DataExported Do
			CurrentObject = Row.Ref.GetObject();
			
			If CurrentObject.Owner <> NewValuesOwner Then
				CurrentObject.Owner = NewValuesOwner;
			EndIf;
			
			If CurrentObject.Modified() Then
				CurrentObject.DataExchange.Load = True;
				CurrentObject.Write();
			EndIf;
		EndDo;
	EndIf;
	
	If NewValuesMark <> Undefined Then
		For each Row In DataExported Do
			CurrentObject = Row.Ref.GetObject();
			
			If CurrentObject.DeletionMark <> NewValuesMark Then
				CurrentObject.DeletionMark = NewValuesMark;
			EndIf;
			
			If CurrentObject.Modified() Then
				CurrentObject.Write();
			EndIf;
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion
