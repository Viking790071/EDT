
#Region ServiceProceduresAndFunctions

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorTextRegularFields	= StyleColors.TitleColorSettingsGroup;
	ColorTextRequiredFields	= StyleColors.TextRequiredFields;
	ColorTextGroupedFields	= StyleColors.TextGroupedFields;
	ColorTextSelectedFields	= StyleColors.TextSelectedFields;
	
	//Regular fields
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("ImportFieldsTree.ColorNumber");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= 0;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextRegularFields);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsFieldsGroupName");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsDerivedValueType");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsFieldName");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsFieldPresentation");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsColumnNumber");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Regular fields'; ru = 'Обычные поля';pl = 'Zwykłe pola';es_ES = 'Campos regulares';es_CO = 'Campos regulares';tr = 'Düzenli alanlar';it = 'Campi regolari';de = 'Normale Felder'");
	
	//Required fields
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("ImportFieldsTree.ColorNumber");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= 1;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextRequiredFields);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsFieldsGroupName");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsDerivedValueType");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsFieldName");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsFieldPresentation");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsColumnNumber");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Required fields'; ru = 'Обязательные поля';pl = 'Pola wymagane';es_ES = 'Campos requeridos';es_CO = 'Campos requeridos';tr = 'Zorunlu alanlar';it = 'Campi richiesti';de = 'Pflichtfelder'");
	
	//Grouped fields
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("ImportFieldsTree.ColorNumber");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= 2;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextGroupedFields);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsFieldsGroupName");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsDerivedValueType");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsFieldName");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsFieldPresentation");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsColumnNumber");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Grouped fields'; ru = 'Группируемые поля';pl = 'Pola zgrupowane';es_ES = 'Campos agrupados';es_CO = 'Campos agrupados';tr = 'Gruplanan alanlar';it = 'Campi raggruppati';de = 'Gruppierte Felder'");
	
	//Selected fields or group
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("ImportFieldsTree.ColorNumber");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= 3;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextSelectedFields);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsFieldsGroupName");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsDerivedValueType");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsFieldName");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsFieldPresentation");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("GroupsAndFieldsColumnNumber");
	FieldAppearance.Use = True;
	
	ItemAppearance.Presentation = NStr("en = 'Selected fields or group'; ru = 'Выбранные поля или группа';pl = 'Wybrane pola lub grupy';es_ES = 'Campos seleccionados o el grupo';es_CO = 'Campos seleccionados o el grupo';tr = 'Seçilen alanlar veya grup';it = 'Campi selezionati o gruppi';de = 'Ausgewählte Felder oder Gruppen'");
	
EndProcedure

&AtClient
Procedure FieldsGroupProcessing(Field, Cancel)
	
	If Not IsBlankString(Field.FieldsGroupName) Then
		
		Cancel = True;
		ShowMessageBox(, NStr("en = 'You can not select group.'; ru = 'Выбор групп не предусмотрен.';pl = 'Nie możesz wybrać grupy.';es_ES = 'Usted no puede seleccionar el grupo.';es_CO = 'Usted no puede seleccionar el grupo.';tr = 'Grup seçemezsiniz.';it = 'Non potete selezionare un gruppo';de = 'Sie können keine Gruppe auswählen.'"));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalAttributesFieldProcessing(Field, Cancel)
	
	If Field.FieldName = ValueCache.AdditionalAttributesFieldName Then
		
		Cancel = True;
		
		MaximumOfAdditionalAttributes = DataImportFromExternalSourcesOverridable.MaximumOfAdditionalAttributesTableDocument();
		If Parameters.DataLoadSettings.SelectedAdditionalAttributes.Count() >= MaximumOfAdditionalAttributes Then
			
			MessageText = NStr("en = 'A lot of additional attributes slows down the import process.
			                   |It is recommended to divide the load into several iterations.'; 
			                   |ru = 'Большое количество дополнительных реквизитов в загрузке существенно замедляет процесс. 
			                   |Рекомендуется разделить загрузку на несколько итераций.';
			                   |pl = 'Wiele dodatkowych atrybutów spowalnia proces importu.
			                   |Zaleca się podzielenie pobieranie na kilka iteracji.';
			                   |es_ES = 'Muchos atributos adicionales frenan el proceso de importación.
			                   |Se recomienda dividir la carga en variar iteraciones.';
			                   |es_CO = 'Muchos atributos adicionales frenan el proceso de importación.
			                   |Se recomienda dividir la carga en variar iteraciones.';
			                   |tr = 'Öznitelik sayısının çok olması içe aktarma işlemini yavaşlatır. 
			                   |Yüklemeyi birkaç kez iterasyona bölünmesi önerilir.';
			                   |it = 'Molti attributi aggiuntivi rallentano il processo di importazione.
			                   |E'' raccomandato di dividere il carico in diverse operazioni.';
			                   |de = 'Viele zusätzliche Attribute verlangsamen den Importvorgang.
			                   |Es wird empfohlen, die Last in mehrere Iterationen aufzuteilen.'");
			
			TitleText = StrTemplate(NStr("en = '%1 attributes selected'; ru = 'Выбрано %1 реквизита';pl = '%1 atrybuty wybrane';es_ES = '%1 atributos seleccionados';es_CO = '%1 atributos seleccionados';tr = '%1 öznitelik seçildi';it = '%1 attributi selezionati';de = '%1 Attribute ausgewählt'"), MaximumOfAdditionalAttributes);
			ShowMessageBox( , MessageText, 0, TitleText);
			Return;
			
		EndIf;
		
		Items.Pages.CurrentPage = Items.PageAdditionalAttributes;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteRequiredActionsAtServer(SelectedFieldName)

	FieldsTree = FormDataToValue(ImportFieldsTree, Type("ValueTree"));
	
	FilterParameters = New Structure("ColumnNumber", ValueCache.ColumnNumber);
	
	FoundRowsFieldsTree = FieldsTree.Rows.FindRows(FilterParameters, True);
	If FoundRowsFieldsTree.Count() > 0 Then
		
		For Each FieldsTreeRow In FoundRowsFieldsTree Do
			
			If FieldsTreeRow.FieldName <> SelectedFieldName Then
				
				FieldsTreeRow.ColumnNumber = 0;
				FieldsTreeRow.ColorNumber  = FieldsTreeRow.ColorNumberOriginal;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	PutToTempStorage(FieldsTree, Parameters.DataLoadSettings.FieldsTreeStorageAddress);

EndProcedure

&AtServer
Procedure FillImportFieldsTree(FieldsTree)
	
	ValueToFormAttribute(FieldsTree, "ImportFieldsTree");
	
EndProcedure

&AtServer
Procedure FillAdditionalAttributeTree()
	
	If Not Parameters.DataLoadSettings.Property("AdditionalAttributeDescription") Then
		
		Return;
		
	EndIf;
	
	AdditionalAttributeTree = FormAttributeToValue("AdditionalAttributes");
	
	OwnerRows = AdditionalAttributeTree.Rows;
	For Each Description In Parameters.DataLoadSettings.AdditionalAttributeDescription Do
		
		AdditionalAttribute = Description.Key;
		
		AdditionalAttributeOwner = OwnerRows.Find(AdditionalAttribute.PropertySet, "AdditionalAttributeOwner", False);
		If AdditionalAttributeOwner = Undefined Then
			
			AdditionalAttributeOwner = OwnerRows.Add();
			AdditionalAttributeOwner.AdditionalAttributeOwner	= AdditionalAttribute.PropertySet;
			AdditionalAttributeOwner.Presentation				= AdditionalAttribute.PropertySet.Description;
			AdditionalAttributeOwner.ItemAvailable				= True; // Always True for groups
			
		EndIf;
		
		NewRow = AdditionalAttributeOwner.Rows.Add();
		NewRow.AdditionalAttribute	= Description.Key;
		NewRow.Presentation			= String(Description.Key.Description);
		NewRow.ItemAvailable		= True;
		
	EndDo;
	
	NewRow = OwnerRows.Add();
	NewRow.AdditionalAttribute	= ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.EmptyRef();
	NewRow.Presentation			= ValueCache.ReturnFieldList;
	NewRow.ItemAvailable		= True;
	
	ValueToFormAttribute(AdditionalAttributeTree, "AdditionalAttributes");
	
EndProcedure

&AtClient
Function IsMaximumSelectedAdditionalAttributes(AdditionalAttributeItemCollection)
	
	MaximumAdditionalAttributes = DataImportFromExternalSourcesOverridable.MaximumOfAdditionalAttributesTableDocument();
	
	Return AdditionalAttributeItemCollection.Count() >= MaximumAdditionalAttributes;
	
EndFunction

&AtClient
Function AddAdditionalAttributeFieldInFieldTree(AdditionalAttributeItemCollection, AdditionalAttributeRow)
	
	AdditionalAttributeField = AdditionalAttributeItemCollection.Add();
	
	AdditionalAttributeField.FieldsGroupName		= "";
	AdditionalAttributeField.FieldName				= Parameters.DataLoadSettings.AdditionalAttributeDescription.Get(AdditionalAttributeRow.AdditionalAttribute);
	AdditionalAttributeField.DerivedValueType		= Undefined;
	AdditionalAttributeField.FieldPresentation		= AdditionalAttributeRow.Presentation;
	AdditionalAttributeField.ColorNumber			= 3;
	AdditionalAttributeField.ColorNumberOriginal	= 4;
	
	Return AdditionalAttributeField;
	
EndFunction

&AtClient
Function FindAdditionalAttributeFieldInFieldTree(AdditionalAttributeItemCollection, AdditionalAttributeRow)
	
	For Each AdditionalAttributeField In AdditionalAttributeItemCollection Do
		
		If AdditionalAttributeField.FieldName = 
			Parameters.DataLoadSettings.AdditionalAttributeDescription.Get(AdditionalAttributeRow.AdditionalAttribute) Then
			Break;
		EndIf;
		
	EndDo;
	
	Return AdditionalAttributeField;
	
EndFunction

&AtClient
Procedure ProcessAdditionalAttributeChoice(AdditionalAttributeRow)
	
	If AdditionalAttributeRow.GetItems().Count() > 0 Then
		ShowMessageBox(, NStr("en = 'You can not select group.'; ru = 'Выбор групп не предусмотрен.';pl = 'Nie możesz wybrać grupy.';es_ES = 'Usted no puede seleccionar el grupo.';es_CO = 'Usted no puede seleccionar el grupo.';tr = 'Grup seçemezsiniz.';it = 'Non potete selezionare un gruppo';de = 'Sie können keine Gruppe auswählen.'"));
		Return;
	EndIf;
	
	AdditionalAttributeGroup = Undefined;
	
	FirstLevelItems = ImportFieldsTree.GetItems();
	For Each TreeRow In FirstLevelItems Do
		
		If TreeRow.FieldName = ValueCache.AdditionalAttributesGroupName Then
			AdditionalAttributeGroup = TreeRow;
			Break;
		EndIf;
		
	EndDo;
	
	AdditionalAttributeItemCollection = AdditionalAttributeGroup.GetItems();
	If Parameters.DataLoadSettings.SelectedAdditionalAttributes.Get(AdditionalAttributeRow.AdditionalAttribute) = Undefined Then
		
		AdditionalAttributeField = AddAdditionalAttributeFieldInFieldTree(AdditionalAttributeItemCollection, AdditionalAttributeRow);
		
		If IsMaximumSelectedAdditionalAttributes(AdditionalAttributeItemCollection) Then
			AdditionalAttributeGroup.ColorNumber = 3;
		EndIf;
		
	Else
		AdditionalAttributeField = FindAdditionalAttributeFieldInFieldTree(AdditionalAttributeItemCollection, AdditionalAttributeRow);
	EndIf;
	
	RememberSelectionAndCloseForm(AdditionalAttributeField, AdditionalAttributeRow.AdditionalAttribute);
	
EndProcedure

&AtClient
Procedure RememberSelectionAndCloseForm(Field, AdditionalAttribute = Undefined)
	
	Result = New Structure;
	Result.Insert("Presentation", 			Field.FieldPresentation);
	Result.Insert("Value", 					Field.FieldName);
	Result.Insert("AdditionalAttribute",	AdditionalAttribute);
	
	ParentField = Field.GetParent();
	If Not ParentField = Undefined
		And Not IsBlankString(ParentField.FieldPresentation) Then
		
		Result.Presentation = StrTemplate("%1 (%2)", Result.Presentation, ParentField.FieldPresentation);
		
	EndIf;
	
	If IsBlankString(Field.FieldName) Then
		
		Result.Insert("CancelSelectionInColumn", Field.ColumnNumber);
		
	EndIf;
	
	ChoseSameField = (Field.ColumnNumber = ValueCache.ColumnNumber);
	If Not IsBlankString(Field.FieldName) Then
		
		Field.ColumnNumber	= ?(ChoseSameField, 0, ValueCache.ColumnNumber);
		Field.ColorNumber	= ?(ChoseSameField, Field.ColorNumberOriginal, 3);
		
	EndIf;
	
	ExecuteRequiredActionsAtServer(Field.FieldName);
	
	Close(Result);
	
EndProcedure

&AtServer
Function FindRowIdByFieldName(Subtree, Name)
	
	RowID = Undefined;
	For Each Row In Subtree Do
		
		If Row.FieldName = Name Then
			Return Row.GetID();
		EndIf;
		
		RowID = FindRowIdByFieldName(Row.GetItems(), Name);
		If RowID <> Undefined Then
			Break;
		EndIf;
		
	EndDo;
	
	Return RowID;
	
EndFunction

#EndRegion

#Region FormEvents

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	Var ColumnTitle;
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Parameters.Property("ColumnTitle", ColumnTitle) Then
		Title = NStr("en = 'Select field'; ru = 'Выбор поля';pl = 'Wybierz pole';es_ES = 'Seleccionar el campo';es_CO = 'Seleccionar el campo';tr = 'Alan seç';it = 'Selezionare campo';de = 'Feld auswählen'") + ?(IsBlankString(ColumnTitle), "", ": " + TrimAll(ColumnTitle));
	Else
		Raise NStr("en = 'You can not open the data processor without context.'; ru = 'Открытие обработки без контекста запрещено.';pl = 'Nie można otworzyć przetwarzania danych bez kontekstu.';es_ES = 'Usted no puede abrir el procesador de datos sin el contexto.';es_CO = 'Usted no puede abrir el procesador de datos sin el contexto.';tr = 'Veri işlemcisini bağlam olmadan açamazsınız.';it = 'Non potete aprire il processore dati senza un contesto.';de = 'Sie können den Datenprozessor nicht ohne Kontext öffnen.'");
	EndIf;
	
	// Conditional appearance
	SetConditionalAppearance();
	
	ValueCache = New Structure;
	ValueCache.Insert("AdditionalAttributesFieldName",	DataImportFromExternalSources.AdditionalAttributesForAddingFieldsName());
	ValueCache.Insert("ColumnNumber", 					Parameters.ColumnNumber);
	ValueCache.Insert("ReturnFieldList",	 			NStr("en = 'Back to the list of attributes'; ru = 'Назад к списку реквизитов';pl = 'Powrót do listy atrybutów';es_ES = 'Volver a la lista de atributos';es_CO = 'Volver a la lista de atributos';tr = 'Öznitelik listesine geri dön';it = 'Ritornare all''elenco degli attributi';de = 'Zurück zur Liste der Attribute'"));
	ValueCache.Insert("AdditionalAttributesGroupName",	DataImportFromExternalSources.AdditionalAttributesForAddingFieldsName());
	
	FieldsTree = GetFromTempStorage(Parameters.DataLoadSettings.FieldsTreeStorageAddress);
	FillImportFieldsTree(FieldsTree);
	FillAdditionalAttributeTree();
	
	Items.ImportFieldsTree.CurrentRow = FindRowIdByFieldName(ImportFieldsTree.GetItems(), Parameters.FieldName);
	
EndProcedure

#EndRegion

#Region FormAttributesEvents

&AtClient
Procedure ImportFiledsTableChoice(Item, SelectedRow, Field, StandardProcessing)
	
	Cancel = False;
	StandardProcessing = False;
	
	Field = ImportFieldsTree.FindByID(SelectedRow);
	
	FieldsGroupProcessing(Field, Cancel);
	AdditionalAttributesFieldProcessing(Field, Cancel);
	
	If Not Cancel Then
		
		RememberSelectionAndCloseForm(Field);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalAttributesSelection(Item, SelectedRow, Field, StandardProcessing)
	
	AdditionalAttributeRow = AdditionalAttributes.FindByID(SelectedRow);
	If AdditionalAttributeRow.Presentation = ValueCache.ReturnFieldList Then
		Items.Pages.CurrentPage = Items.PageFields;
	Else
		ProcessAdditionalAttributeChoice(AdditionalAttributeRow);
	EndIf;
	
	
EndProcedure

#EndRegion