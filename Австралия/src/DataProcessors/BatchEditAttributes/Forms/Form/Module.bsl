#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CheckPlatformVersionAndCompatibilityMode();
	
	Parameters.Property("AdditionalDataProcessorRef", AdditionalDataProcessorRef);
	
	LoadProcessingSettings();
	ContextCall = TypeOf(Parameters.ObjectsArray) = Type("Array");
	Items.FormBack.Visible = False;
	
	EditProhibitionIntegrated = Metadata.FindByFullName("CommonModule.ObjectAttributesLockClient") <> Undefined;
	
	If ContextCall Then
		ExecuteActionsOnContextOpen();
	Else
		Title = NStr("ru = 'Групповое изменение реквизитов'; en = 'Bulk attribute editing'; pl = 'Masowa edycja atrybutów';es_ES = 'Edición del atributo grueso';es_CO = 'Edición del atributo grueso';tr = 'Toplu özellik düzenleme';it = 'Modifica collettiva degli attributi';de = 'Massenattributbearbeitung'");
		FillObjectsTypesList();
	EndIf;
	
	FindUnlockAttributesForm();
	
	GenerateNoteOnConfiguredChanges();
	UpdateItemsVisibility();
	
	If Not ContextCall Then
		WindowOpeningMode = FormWindowOpeningMode.Independent;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper(FullFormName("AdditionalParameters")) Then
		
		RefillObjectAttributesStructure = False;
		If TypeOf(SelectedValue) = Type("Structure") Then
			Object.DeveloperMode = SelectedValue.DeveloperMode;
			DisableSelectionParameterConnections = SelectedValue.DisableSelectionParameterConnections;
			If IncludeSubordinateItems AND ProcessRecursively <> SelectedValue.ProcessRecursively Then
				ProcessRecursively = SelectedValue.ProcessRecursively;
				RefillObjectAttributesStructure = True;
				InitializeSettingsComposer();
			EndIf;
			Object.ChangeInTransaction = SelectedValue.ChangeInTransaction;
			Object.InterruptOnError  = SelectedValue.InterruptOnError;
			
			If Object.ShowInternalAttributes <> SelectedValue.ShowInternalAttributes Then
				Object.ShowInternalAttributes = SelectedValue.ShowInternalAttributes;
				RefillObjectAttributesStructure = True;
			EndIf;
			
			TransactionalBatchSetting          = SelectedValue.PortionSetting;
			TransactionalPercentageOfObjectsInBatch   = SelectedValue.ObjectsPercentageInPortion;
			TransactionalNumberOfObjectsInBatch     = SelectedValue.ObjectCountInPortion;
			
			If RefillObjectAttributesStructure AND Not IsBlankString(KindsOfObjectsToChange) Then
				SavedSettings = Undefined;
				LoadObjectMetadata(True, SavedSettings);
				If SavedSettings <> Undefined AND Object.OperationType <> "ExecuteAlgorithm" Then
					SetChangeSetting(SavedSettings);
				EndIf;
			EndIf;
			
			UpdateItemsVisibility();
			SaveSettings();
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure KindOfObjectsToChangeStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	NotifyDescription = New NotifyDescription("KindOfObjectsToChangeWhenSelected", ThisObject);
	FormParameters = New Structure;
	FormParameters.Insert("SelectedTypes", KindsOfObjectsToChange);
	FormParameters.Insert("ShowHiddenItems", Object.ShowInternalAttributes);
	OpenForm(FullFormName("SelectObjectsKind"), FormParameters, , , , , NotifyDescription);
EndProcedure

&AtClient
Procedure PresentationOfObjectsToChangeOnChange(Item)
	SelectedType = Items.PresentationOfObjectsToChange.ChoiceList.FindByValue(PresentationOfObjectsToChange);
	If SelectedType = Undefined Then
		For Each Type In Items.PresentationOfObjectsToChange.ChoiceList Do
			If StrFind(Lower(Type.Presentation), Lower(PresentationOfObjectsToChange)) = 1 Then
				SelectedType = Type;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	If SelectedType = Undefined Then
		PresentationOfObjectsToChange = PresentationOfObjectsToChange();
	Else
		PresentationOfObjectsToChange = SelectedType.Presentation;
		KindsOfObjectsToChange = SelectedType.Value;
		SelectedObjectsInContext.Clear();
		RebuildFormInterfaceForSelectedObjectKind();
	EndIf;
	
	Algorithm = PresentationOfObjectsToChange;
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	If Object.OperationType = "ExecuteAlgorithm" Then
		Items.OperationKindPages.CurrentPage = Items.ArbitraryAlgorithm;
		Items.FormChange.Title = NStr("ru = 'Выполнить'; en = 'Execute'; pl = 'Wykonaj';es_ES = 'Ejecutar';es_CO = 'Ejecutar';tr = 'Yürüt';it = 'Esegui';de = 'Ausführen'");
		Items.PreviouslyChangedAttributes.Visible = False;
		Items.Algorithms.Visible = True;
	Else
		Items.OperationKindPages.CurrentPage = Items.AttributesToChange;
		Items.FormChange.Title = NStr("ru = 'Изменить реквизиты'; en = 'Change attributes'; pl = 'Zmień atrybuty';es_ES = 'Cambiar atributos';es_CO = 'Cambiar atributos';tr = 'Özellikleri değiştir';it = 'Modificare gli attributi';de = 'Attribute ändern'");
		Items.PreviouslyChangedAttributes.Visible = True;
		Items.Algorithms.Visible = False;
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSettingsComposerSettingsFilter

&AtClient
Procedure UpdateLabel()
	UpdateLabelsServer();
EndProcedure

&AtServer
Procedure UpdateLabelsServer()
	UpdateSelectedCountLabel();
	GenerateNoteOnConfiguredChanges();
	Algorithm = PresentationOfObjectsToChange;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersObjectsThatCouldNotBeEdited

&AtClient
Procedure ObjectsThatCouldNotBeEditedBeforeRowChange(Item, Cancel)
	Cancel = True;
	If TypeOf(Item.CurrentData.Object) <> Type("String") Then
		ShowValue(, Item.CurrentData.Object);
	EndIf;
EndProcedure

&AtClient
Procedure ObjectsThatCouldNotBeEditedOnActivateRow(Item)
	If Item.CurrentData <> Undefined Then
		Reason = Item.CurrentData.Reason;
	EndIf;
EndProcedure

#EndRegion

#Region TableFormAttributeObjectEventHandlers

&AtClient
Procedure ObjectAttributesDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	If Field <> Undefined AND Field.Name = Items.ObjectAttributesValue.Name 
		AND ObjectAttributes.FindByID(Row).ValidTypes.ContainsType(Type("String"))
		AND Not StrStartsWith(ObjectAttributes.FindByID(Row).Value, "'") Then
		StandardProcessing = False;
	EndIf;
EndProcedure

&AtClient
Procedure ObjectAttributesDrag(Item, DragParameters, StandardProcessing, Row, Field)
	AttributeDetails = ObjectAttributes.FindByID(DragParameters.Value[0]);
	PasteTemplate = "[%1]";
	
	TextForInput = SubstituteParametersToString(PasteTemplate, AttributeDetails.Presentation);
	CurrentData = ObjectAttributes.FindByID(Row);
	If Not IsBlankString(CurrentData.Value) Then
		TextForInput = "+" + TextForInput;
	EndIf;
	CurrentData.Value = String(CurrentData.Value) + TextForInput;
	If Not StrStartsWith(TrimL(CurrentData.Value), "=") Then
		CurrentData.Value = "=" + CurrentData.Value;
	EndIf;
	CurrentData.Change = True;
EndProcedure

&AtClient
Procedure ObjectAttributesValueChoiceStart(Item, ChoiceData, StandardProcessing)
	CurrentData = Items.ObjectAttributes.CurrentData;
	If CurrentData.ValidTypes.Types().Count() = 1 AND CurrentData.ValidTypes.ContainsType(Type("String")) Then
		StandardProcessing = False;
		NotifyDescription = New NotifyDescription("ObjectAttributesValueChoiceCompletion", ThisObject, CurrentData);
		OpenForm(FullFormName("FormulaEdit"), ComposerParameters(CurrentData.Value), , , , ,
			NotifyDescription);
	EndIf;
EndProcedure

&AtClient
Function ExpressionsHaveErrors()
	Result = False;
	For Index = 0 To ObjectAttributes.Count() - 1 Do
		AttributeDetails = ObjectAttributes[Index];
		If AttributeDetails.Change AND TypeOf(AttributeDetails.Value) = Type("String") AND StrStartsWith(AttributeDetails.Value, "=") Then
			ErrorText = "";
			If ExpressionHasErrors(AttributeDetails.Value, ErrorText) Then
				Result = True;
				Message = New UserMessage;
				Message.Field = SubstituteParametersToString("ObjectAttributes[%1].Value", Format(Index, "NG=0"));
				Message.Text = ErrorText;
				Message.Message();
			EndIf;
		EndIf;
	EndDo;
	Return Result;
EndFunction

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Change(Command)
	
	If Object.OperationType = "ExecuteAlgorithm" Then
		
		CodeExecutionRights = AvailableCodeExecutionRights();
		
		If Not CodeExecutionRights.CodeExecutionAvailable Then
			Return;
		EndIf;
		
		If Not CodeExecutionRights.UnsafeModeCodeExecutionAvailable AND Object.ExecutionMode = 1 Then
			Object.ExecutionMode = 0; // Switching to safe mode
		EndIf;
		
	EndIf;
	
	ButtonPurpose = "Change";
	If ProcessingInProgress Then
		ButtonPurpose = "Abort";
	ElsIf ProcessingCompleted Or Items.Pages.CurrentPage = Items.ChangeObjects Then
		ButtonPurpose = "Close";
		If ObjectsThatCouldNotBeChanged.Count() > 0 Then
			ButtonPurpose = "Retry";
		EndIf;
	EndIf;
	
	If ButtonPurpose = "Close" Then
		Close();
		Return;
	EndIf;
	
	If ButtonPurpose = "Abort" Then
		CurrentChangeStatus.AbortChange = True;
		If Not TimeConsumingOperation.Status = "Completed" Then
			CompleteObjectChange();
		EndIf;
		Return;
	EndIf;
	
	If ButtonPurpose = "Change" Then
		If Not SelectedObjectsAvailable() Then
			ShowMessageBox(, NStr("ru = 'Не указаны элементы для изменения'; en = 'Items for change are not specified'; pl = 'Elementy do zmiany nie zostały określone';es_ES = 'Artículos para cambiar no están especificados';es_CO = 'Artículos para cambiar no están especificados';tr = 'Değişecek öğeler belirtilmedi';it = 'Elementi per il cambiamento, non sono specificati';de = 'Elemente für Änderungen sind nicht angegeben'"));
			Return;
		EndIf;
		
		If ExpressionsHaveErrors() Then
			Return;
		EndIf;
	
		If AvailableConfiguredFilters() Then
			ExecuteChangeFilterCheckCompleted();
		Else
			QuestionText = NStr("ru = 'Отбор не задан. Изменить все элементы?'; en = 'Filter is not set. Change all items?'; pl = 'Filtr nie jest ustawiony. Zmienić wszystkie elementy?';es_ES = 'Filtro no está establecido. ¿Cambiar todos artículos?';es_CO = 'Filtro no está establecido. ¿Cambiar todos artículos?';tr = 'Filtre ayarlanmadı. Tüm öğeler değişsin mi?';it = 'Il filtro non è impostato. Modificare tutti gli elementi?';de = 'Filter ist nicht eingestellt. Alle Elemente ändern?'");
			NotifyDescription = New NotifyDescription("ExecuteChangeFilterCheckCompleted", ThisObject);
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.OKCancel, , , NStr("ru = 'Изменение элементов'; en = 'Change items'; pl = 'Zmień elementy';es_ES = 'Cambiar los artículos';es_CO = 'Cambiar los artículos';tr = 'Öğeleri değiştir';it = 'Modifica degli elementi';de = 'Elemente ändern'"));
		EndIf;
		
		Return;
	EndIf;
	
	If ButtonPurpose = "Retry" Then
		ExecuteChangeChecksCompleted();
	EndIf;
	
EndProcedure

&AtClient
Procedure Back(Command)
	
	BackServer();
	
EndProcedure

&AtClient
Procedure ConfigureChangeParameters(Command)
	
	FormParameters = New Structure;
	
	FormParameters.Insert("ChangeInTransaction",    Object.ChangeInTransaction);
	FormParameters.Insert("ProcessRecursively", ProcessRecursively);
	FormParameters.Insert("InterruptOnError",     Object.InterruptOnError);
	FormParameters.Insert("PortionSetting",        TransactionalBatchSetting);
	FormParameters.Insert("ObjectsPercentageInPortion", TransactionalPercentageOfObjectsInBatch);
	FormParameters.Insert("ObjectCountInPortion",   TransactionalNumberOfObjectsInBatch);
	FormParameters.Insert("ProcessSubordinateItems",      IncludeSubordinateItems);
	FormParameters.Insert("ShowInternalAttributes",     Object.ShowInternalAttributes);
	FormParameters.Insert("ContextCall", ContextCall);
	FormParameters.Insert("DeveloperMode", Object.DeveloperMode);
	FormParameters.Insert("DisableSelectionParameterConnections", DisableSelectionParameterConnections);
	
	
	OpenForm(FullFormName("AdditionalParameters"), FormParameters, ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// ATTACHABLE HANDLERS

&AtClient
Procedure Attachable_ValueOnChange(Item)
	CurrentData = Item.Parent.CurrentData;
	CurrentData.Change = ValueIsFilled(CurrentData.Value);
	UpdateCountersOfAttributesToChange(Item.Parent);
	AttachIdleHandler("UpdateNoteAboutConfiguredChanges", 0.1, True);
EndProcedure

&AtClient
Procedure Attachable_OnChangeFlag(Item)
	UpdateCountersOfAttributesToChange(Item.Parent);
	AttachIdleHandler("UpdateNoteAboutConfiguredChanges", 0.1, True);
EndProcedure

&AtClient
Procedure Attachable_EnableSetting(Command)
	
	If StrStartsWith(Command.Name, "Algorithms") Then
		CommandLocation = Items.Algorithms;
		CommandNamePattern = CommandLocation.Name + "ChangesSetting";
		CommandIndex = Number(Mid(Command.Name, StrLen(CommandNamePattern) + 1));
		AlgorithmCode = AlgorithmsHistoryList[CommandIndex].Value;
		Algorithm = AlgorithmsHistoryList[CommandIndex].Presentation;
		GenerateNoteOnConfiguredChanges();
	Else
		CommandLocation = Items.PreviouslyChangedAttributes;
		CommandNamePattern = CommandLocation.Name + "ChangesSetting";
		CommandIndex = Number(Mid(Command.Name, StrLen(CommandNamePattern) + 1));
		SetChangeSetting(OperationsHistoryList[CommandIndex].Value);
		GenerateNoteOnConfiguredChanges();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_BeforeStartCHange(Item, Cancel)
	
	RestrictSelectableTypesAndSetValueChoiceParameters(Item);
	If (Item.CurrentItem = Items.ObjectAttributesValue
		Or Item.CurrentItem = Items.ObjectAttributesChange)
		AND Item.CurrentData.LockedAttribute Then
			Cancel = True;
			QuestionGoToUnlockAttributes(Item.CurrentData);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UpdateNoteAboutConfiguredChanges()
	GenerateNoteOnConfiguredChanges();
EndProcedure

&AtClient
Procedure ObjectAttributesValueChoiceCompletion(Formula, CurrentData) Export
	If Formula = Undefined Then
		Return;
	EndIf;
	If Not StrStartsWith(Formula, "=") Then
		Formula = "=" + Formula;
	EndIf;
	CurrentData.Value = Formula;
	CurrentData.Change = True;
EndProcedure

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	// Autonumbering information. This setting must always be the first to configure.
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ObjectAttributesValue.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Change");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.IsStandardAttribute");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Value");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	FilterGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup.GroupType = DataCompositionFilterItemsGroupType.OrGroup;
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Name");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = "Code";
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Name");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = "Number";
	
	Item.Appearance.SetParameterValue("Text", NoteOnAutonumbering);
	Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);
	
	// A locked attribute.
	
	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ObjectAttributesPresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.LockedAttribute");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", New Color(192, 192, 192));
	
	
	// Notes for linked attributes
	
	For Each Attribute In ObjectAttributes Do
		Item = ConditionalAppearance.Items.Add();
		
		ItemField = Item.Fields.Items.Add();
		ItemField.Field = New DataCompositionField(Items.ObjectAttributesValue.Name);

		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Name");
		ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
		ItemFilter.RightValue = Attribute.Name;
		
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Value");
		ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
		
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.Change");
		ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
		ItemFilter.RightValue = False;
		
		ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
		ItemFilter.LeftValue = New DataCompositionField("ObjectAttributes.ChoiceParameterLinksPresentation");
		ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
		
		Item.Appearance.SetParameterValue("Text", Attribute.ChoiceParameterLinksPresentation);
		Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);
	EndDo;
	
	For Each TabularSection In ObjectTabularSections Do
		For Each Attribute In ThisObject[TabularSection.Value] Do
			Item = ConditionalAppearance.Items.Add();
			
			ItemField = Item.Fields.Items.Add();
			ItemField.Field = New DataCompositionField(TabularSection.Value + "Value");

			ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
			ItemFilter.LeftValue = New DataCompositionField(TabularSection.Value + ".Name");
			ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
			ItemFilter.RightValue = Attribute.Name;
			
			ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
			ItemFilter.LeftValue = New DataCompositionField(TabularSection.Value + ".Value");
			ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
			
			ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
			ItemFilter.LeftValue = New DataCompositionField(TabularSection.Value + ".Change");
			ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
			ItemFilter.RightValue = False;
			
			ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
			ItemFilter.LeftValue = New DataCompositionField(TabularSection.Value + ".ChoiceParameterLinksPresentation");
			ItemFilter.ComparisonType = DataCompositionComparisonType.Filled;
			
			Item.Appearance.SetParameterValue("Text", Attribute.ChoiceParameterLinksPresentation);
			Item.Appearance.SetParameterValue("TextColor", WebColors.Gray);
		EndDo;
	EndDo;
	
EndProcedure

&AtClient
Procedure ExecuteChangeFilterCheckCompleted(QuestionResult = Undefined, AdditionalParameters = Undefined) Export
	
	If QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Not AvailableConfiguredChanges() AND Object.OperationType = "EnterValues" Then
		QuestionText = NStr("ru = 'Изменения не настроены. Выполнить перезапись элементов без изменений?'; en = 'Changes are not set. Rewrite the items without changes?'; pl = 'Zmiany nie są ustawione. Przepisz te elementy bez zmian?';es_ES = 'Cambios no están establecidos. ¿Volver a grabar los artículos sin cambiar?';es_CO = 'Cambios no están establecidos. ¿Volver a grabar los artículos sin cambiar?';tr = 'Değişiklikler ayarlanmadı. Öğeler değişiklik olmadan tekrar yazılsın mı?';it = 'Le modifiche non sono configurate. Vuoi sovrascrivere gli elementi senza modificarli?';de = 'Änderungen sind nicht festgelegt. Schreiben Sie die Elemente ohne Änderungen neu?'");
		NotifyDescription = New NotifyDescription("ExecuteChangeChecksCompleted", ThisObject);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.OKCancel, , , NStr("ru = 'Изменение элементов'; en = 'Change items'; pl = 'Zmień elementy';es_ES = 'Cambiar los artículos';es_CO = 'Cambiar los artículos';tr = 'Öğeleri değiştir';it = 'Modifica degli elementi';de = 'Elemente ändern'"));
	Else
		ExecuteChangeChecksCompleted();
	EndIf;
	
EndProcedure

&AtServer
Function AvailableConfiguredFilters()
	For Each FilterItem In SettingsComposer.Settings.Filter.Items Do
		If FilterItem.Use Then
			Return True;
		EndIf;
	EndDo;
	Return False;
EndFunction

&AtClient
Function FullFormName(Name)
	NameParts = StrSplit(FormName, ".");
	NameParts[3] = Name;
	Return StrConcat(NameParts, ".");
EndFunction

&AtServer
Procedure ExecuteActionsOnContextOpen()
	
	CaptionPattern = NStr("ru = 'Изменение выделенных элементов ""%1"" (%2)'; en = 'Change selected items ""%1"" (%2)'; pl = 'Zmień wybrane elementy ""%1"" (%2)';es_ES = 'Cambiar los artículos seleccionado ""%1"" (%2)';es_CO = 'Cambiar los artículos seleccionado ""%1"" (%2)';tr = 'Seçilmiş öğeleri seçin ""%1"" (%2)';it = 'Modifica elementi selezionati ""%1"" (%2)';de = 'Ändern Sie die ausgewählten Elemente ""%1"" (%2)'");
	
	ObjectsTypes = New ValueList;
	For Each PassedObject In Parameters.ObjectsArray Do
		MetadataObject = PassedObject.Metadata();
		ObjectName = MetadataObject.FullName();
		If ObjectsTypes.FindByValue(ObjectName) = Undefined Then
			ObjectsTypes.Add(ObjectName, MetadataObject.Presentation());
		EndIf;
	EndDo;
	
	TypePresentation = Parameters.ObjectsArray[0].Metadata().Presentation();
	If ObjectsTypes.Count() > 1 Then
		TypePresentation = "";
		CaptionPattern = NStr("ru = 'Изменение выделенных элементов (%2)'; en = 'Change selected items (%2)'; pl = 'Zmień wybrane elementy (%2)';es_ES = 'Cambiar los elementos seleccionados (%2)';es_CO = 'Cambiar los elementos seleccionados (%2)';tr = 'Seçilmiş öğeleri değiştir (%2)';it = 'Modifica elementi selezionati (%2)';de = 'Ändern der ausgewählten Elemente (%2)'");
	EndIf;
	
	ObjectCount = Parameters.ObjectsArray.Count();
	Title = SubstituteParametersToString(CaptionPattern, TypePresentation, ObjectCount);
	
	// Hiding all settings-related actions if there are no write permissions for settings.
	Items.PreviouslyChangedAttributes.Visible = AccessRight("SaveUserData", Metadata);
	
	KindsOfObjectsToChange = StrConcat(ObjectsTypes.UnloadValues(), ",");
	
	// Loading the history of operations for this object type.
	LoadOperationsHistory();
	FillPreviouslyChangedAttributesSubmenu();
	
	// Hierarchical object
	IncludeSubordinateItems = HierarchicalMetadataObject(Parameters.ObjectsArray[0]);
	FolderHierarchy = GroupsAndItemsHierarchy(Parameters.ObjectsArray[0]);
	
	SelectedObjectsInContext.LoadValues(Parameters.ObjectsArray);
	InitializeSettingsComposer();
	
	LoadObjectMetadata();
	
	PresentationOfObjectsToChange = PresentationOfObjectsToChange();
	UpdateSelectedCountLabel();
	
	Items.PresentationOfObjectsToChange.ReadOnly = True;
	
	// Arbitrary algorithms are not allowed during context calls.
	Items.OperationType.Visible = False;
EndProcedure

&AtClient
Procedure ExecuteChangeChecksCompleted(QuestionResult = Undefined, AdditionalParameters = Undefined) Export
	
	If QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	SettButtonsDuringChange(True);
	GoToChangeObjectsPage();
	ObjectsThatCouldNotBeChanged.Clear();
	
	AttachIdleHandler("ChangeObjects", 0.1, True);
	
EndProcedure

&AtServer
Function AvailableConfiguredChanges()
	Return AttributesToChange().Count() > 0 Or TabularSectionsToChange().Count() > 0;
EndFunction

&AtServer
Procedure AddChangeToHistory(ChangeStructure, ChangePresentation)
	
	// Change history settings are an array of structures with the following keys:
	// Change - array with the change structure.
	// Presentation - presentation of the setting to the user.
	
	If Object.OperationType = "ExecuteAlgorithm" Then
			Settings = CommonSettingsStorageLoad(
		"BatchEditObjects", 
		"AlgorithmsHistory/" + KindsOfObjectsToChange);
		
		If Settings = Undefined Then
			Settings = New Array;
		Else
			For Index = 0 To Settings.UBound() Do
				If Settings.Get(Index).Presentation = ChangePresentation Then
					Settings.Delete(Index);
					Break;
				EndIf;
			EndDo;
		EndIf;
		
		Settings.Insert(0, New Structure("Update, Presentation", ChangeStructure, ChangePresentation));
		
		If Settings.Count() > 20 Then
			Settings.Delete(19);
		EndIf;
		
		CommonSettingsStorageSave("BatchEditObjects", "AlgorithmsHistory/" + KindsOfObjectsToChange, Settings);
		
		LoadOperationsHistory();
		FillPreviouslyChangedAttributesSubmenu();

		Return;
	EndIf;
	
	Settings = CommonSettingsStorageLoad(
		"BatchEditObjects", 
		"ChangeHistory/" + KindsOfObjectsToChange);
	
	If Settings = Undefined Then
		Settings = New Array;
	Else
		For Index = 0 To Settings.UBound() Do
			If Settings.Get(Index).Presentation = ChangePresentation Then
				Settings.Delete(Index);
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Settings.Insert(0, New Structure("Update, Presentation", ChangeStructure, ChangePresentation));
	
	If Settings.Count() > 20 Then
		Settings.Delete(19);
	EndIf;
	
	CommonSettingsStorageSave("BatchEditObjects", "ChangeHistory/" + KindsOfObjectsToChange, Settings);
	
	LoadOperationsHistory();
	FillPreviouslyChangedAttributesSubmenu();
EndProcedure

&AtServer
Procedure LoadOperationsHistory()
	
	OperationsHistoryList.Clear();
	
	ChangeHistory = CommonSettingsStorageLoad("BatchEditObjects", "ChangeHistory/" + KindsOfObjectsToChange);
	If ChangeHistory <> Undefined AND TypeOf(ChangeHistory) = Type("Array") Then
		For Each Setting In ChangeHistory Do
			OperationsHistoryList.Add(Setting.Update, Setting.Presentation);
		EndDo;
	EndIf;
	
	AlgorithmsHistoryList.Clear();
	
	ChangeHistory = CommonSettingsStorageLoad("BatchEditObjects", "AlgorithmsHistory/" + KindsOfObjectsToChange);
	If ChangeHistory = Undefined Then
		Return;
	EndIf;
	
	For Each Setting In ChangeHistory Do
		AlgorithmsHistoryList.Add(Setting.Update, Setting.Presentation);
	EndDo;
	
EndProcedure

&AtClient
Procedure QuestionGoToUnlockAttributes(SelectedAttribute)
	
	Buttons = New ValueList;
	
	If ContextCall Then
		Buttons.Add(DialogReturnCode.Yes, NStr("ru = 'Перейти'; en = 'Navigate'; pl = 'Przejdź';es_ES = 'Navegar';es_CO = 'Navegar';tr = 'Geçiş yapın';it = 'Navigare';de = 'Navigieren'"));
		QuestionText = NStr("ru = 'Реквизит заблокирован, перейти к разблокированию реквизитов?'; en = 'The attribute has been locked.  Unlock attributes?'; pl = 'Atrybut został zablokowany. Odblokować atrybuty?';es_ES = 'El atributo se ha bloqueado. ¿Desbloquear los atributos?';es_CO = 'El atributo se ha bloqueado. ¿Desbloquear los atributos?';tr = 'Özellik kilitlendi. Özelliklerin kilidini açılsın mı?';it = 'L''attributo è stato bloccato. Sbloccare gli attributi?';de = 'Das Attribut wurde gesperrt. Attribute freischalten?'");
	Else
		Buttons.Add(DialogReturnCode.Yes, NStr("ru = 'Разблокировать'; en = 'Unlock'; pl = 'Odblokuj';es_ES = 'Desbloquear';es_CO = 'Desbloquear';tr = 'Blokeyi kaldır';it = 'Rimuovere blocco';de = 'Freischalten'"));
		QuestionText = SubstituteParametersToString(
			NStr("ru = 'Для того чтобы не допустить рассогласования данных в программе,
				|реквизит ""%1"" не доступен для редактирования.
				|
				|Перед тем, как разрешить его редактирование, рекомендуется оценить последствия,
				|проверив все места использования выбранных элементов в программе.
				|
				|Разблокировать реквизит ""%1"" для изменения?'; 
				|en = 'To prevent data inconsistency in the application, the ""%1"" attribute
				|cannot be edited.
				|
				|It is recommended that you review the effects before allowing its editing
				|by checking all usage locations of the selected items in the application.
				|
				|Unlock the ""%1"" attribute for changing?'; 
				|pl = 'Aby zapobiec niedopasowaniu danych w programie,
				|rekwizyt ""%1"" nie jest dostępny do edycji.
				|
				|Przed zezwoleniem na edycję, zaleca się ocenić konsekwencje,
				|sprawdzając wszystkie miejsca, w których wybrane elementy są używane w programie.
				|
				|Odblokować rekwizyt ""%1"" do zmiany?';
				|es_ES = 'Para evitar el desajuste de datos en la aplicación,
				| el requisito ""%1"" no es editable.
				|
				|Antes de permitir su edición, se recomienda evaluar las consecuencias
				|revisando todos los lugares del uso de los elementos seleccionados en el programa.
				|
				|¿Desbloquear el requisito ""%1"" para cambiar?';
				|es_CO = 'Para evitar el desajuste de datos en la aplicación,
				| el requisito ""%1"" no es editable.
				|
				|Antes de permitir su edición, se recomienda evaluar las consecuencias
				|revisando todos los lugares del uso de los elementos seleccionados en el programa.
				|
				|¿Desbloquear el requisito ""%1"" para cambiar?';
				|tr = 'Uygulamadaki verilerin yanlış hizalanmasını önlemek için, 
				|özellik %1 düzenlenemez. 
				|
				|Düzenlemesine izin vermeden önce, uygulamadaki "
" öğesinin tüm kullanım yerlerini kontrol ederek sonuçların değerlendirilmesi önerilir. 
				|
				|""%1"" alanı değişikliği için kilit kaldırılsın mı?';
				|it = 'Al fine di prevenire l''incoerenza dei dati nell''applicazione, il requisito ""%1""
				|non può essere modificato.
				|
				| Si consiglia di rivedere gli effetti prima di permetterne la modifica
				|controllando tutte le posizioni d''uso degli elementi selezionati nell''applicazione.
				|
				| Sbloccare il requisito ""%1"" per la modifica?';
				|de = 'Um zu verhindern, dass die Daten im Programm nicht übereinstimmen,
				|steht das Attribut ""%1"" nicht zur Bearbeitung zur Verfügung.
				|
				|Bevor Sie die Bearbeitung zulassen, wird empfohlen, die Auswirkungen abzuschätzen,
				|indem Sie alle Verwendungsorte der ausgewählten Elemente im Programm überprüfen.
				|
				|Möchten Sie das Attribut ""%1"" freischalten, um es zu ändern?'"),
			SelectedAttribute.Presentation);
	EndIf;
	
	Buttons.Add(DialogReturnCode.Cancel, NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'"));
	
	NotifyDescription = New NotifyDescription("QuestionGoToUnlockAttributesCompletion", ThisObject, SelectedAttribute);
	ShowQueryBox(NotifyDescription, QuestionText, Buttons, , DialogReturnCode.Yes, NStr("ru = 'Реквизит заблокирован'; en = 'Attribute is locked'; pl = 'Rekwizyt jest zablokowany';es_ES = 'Atributo está bloqueado';es_CO = 'Atributo está bloqueado';tr = 'Özellik kilitlendi';it = 'L''attributo è bloccato';de = 'Attribut ist gesperrt'"));
	
EndProcedure

&AtClient
Procedure QuestionGoToUnlockAttributesCompletion(QuestionResult, AttributeDetails) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		AllowEditAttributes(AttributeDetails);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetChoiceParametersServer(ChoiceParameters, ChoiceParametersArray)
	
	For Index = 1 To StrLineCount(ChoiceParameters) Do
		ChoiceParametersString      = StrGetLine(ChoiceParameters, Index);
		ChoiceParametersStringsArray = StrSplit(ChoiceParametersString, ";");
		FilterFieldName = TrimAll(ChoiceParametersStringsArray[0]);
		TypeName       = TrimAll(ChoiceParametersStringsArray[1]);
		XMLString     = TrimAll(ChoiceParametersStringsArray[2]);
		
		If Type(TypeName) = Type("FixedArray") Then
			Array = New Array;
			XMLStringArray = StrSplit(XMLString, "#");
			For Each Item In XMLStringArray Do
				ItemArray = StrSplit(Item, "*");
				ItemValue = XMLValue(Type(ItemArray[0]), ItemArray[1]);
				Array.Add(ItemValue);
			EndDo;
			Value = New FixedArray(Array);
		Else
			Value = XMLValue(Type(TypeName), XMLString);
		EndIf;
		
		ChoiceParametersArray.Add(New ChoiceParameter(FilterFieldName, Value));
	EndDo;
	
EndProcedure

&AtServerNoContext
Procedure SaveDataProcessorSettings(FullName, ChangeInTransaction, InterruptOnError,
			TransactionalBatchSetting, TransactionalPercentageOfObjectsInBatch, TransactionalNumberOfObjectsInBatch, ProcessRecursively)
	
	If Not AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("ChangeInTransaction",		ChangeInTransaction);
	SettingsStructure.Insert("InterruptOnError",		InterruptOnError);
	SettingsStructure.Insert("TransactionalBatchSetting",			TransactionalBatchSetting);
	SettingsStructure.Insert("TransactionalPercentageOfObjectsInBatch",	TransactionalPercentageOfObjectsInBatch);
	SettingsStructure.Insert("TransactionalNumberOfObjectsInBatch",	TransactionalNumberOfObjectsInBatch);
	SettingsStructure.Insert("ProcessRecursively",	ProcessRecursively);
	
	CommonSettingsStorageSave("DataProcessor.BatchEditObjects", FullName, SettingsStructure);
	
EndProcedure

&AtServer
Procedure LoadProcessingSettings()
	
	Object.ChangeInTransaction          = True;
	Object.InterruptOnError           = True;
	Object.OperationType                  = "EnterValues";
	TransactionalBatchSetting                   = 1;
	TransactionalPercentageOfObjectsInBatch            = 100;
	TransactionalNumberOfObjectsInBatch              = 1;
	ProcessRecursively              = False;
	Object.ShowInternalAttributes = False;
	
	SettingsStructure = CommonSettingsStorageLoad(
		"DataProcessor.BatchEditObjects",
		KindsOfObjectsToChange);
	
	If SettingsStructure <> Undefined Then
		Object.ChangeInTransaction = SettingsStructure.ChangeInTransaction;
		Object.InterruptOnError  = SettingsStructure.InterruptOnError;
		ProcessRecursively     = SettingsStructure.ProcessRecursively;
		If AccessRight("DataAdministration", Metadata) AND SettingsStructure.Property("ShowInternalAttributes") Then
			Object.ShowInternalAttributes = SettingsStructure.ShowInternalAttributes;
		Else
			Object.ShowInternalAttributes = False;
		EndIf;
	EndIf;
	
	CodeExecutionAvailable                    = CodeExecutionAvailable();
	Items.ArbitraryAlgorithm.Visible   = CodeExecutionAvailable;
	Items.OperationType.Visible            = CodeExecutionAvailable;

	UnsafeModeCodeExecutionAvailable = UnsafeModeCodeExecutionAvailable();
	Items.ExecutionMode.Visible        = UnsafeModeCodeExecutionAvailable;
	
EndProcedure

// Custom algorithms are not allowed in SaaS mode, base configurations, or without SystemAdministrator rights.
//
&AtServerNoContext
Function UnsafeModeCodeExecutionAvailable()
	If IsBaseConfigurationVersion()
		OR DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	If NOT AccessRight("Administration", Metadata) Then
		Return False;
	EndIf;
	
	Return True;
EndFunction

&AtServerNoContext
Function CodeExecutionAvailable()
	
	If DataSeparationEnabled() Then
		Return False;
	EndIf;
	
	Return True;
EndFunction

&AtServerNoContext
Function AvailableCodeExecutionRights()
	
	Result = New Structure();
	Result.Insert("UnsafeModeCodeExecutionAvailable", UnsafeModeCodeExecutionAvailable());
	Result.Insert("CodeExecutionAvailable", CodeExecutionAvailable());
	
	Return Result;
EndFunction

&AtClient
Procedure AllowEditAttributes(SelectedAttribute)
	
	If Not ContextCall Then
		SelectedAttribute.LockedAttribute = False;
		Return;
	EndIf;
	
	LockedAttributesRows = ObjectAttributes.FindRows(
		New Structure("LockedAttribute", True));
	
	If UnlockAttributesFormAvailable Then
		
		LockedAttributes = New Array;
		
		For Each OperationDescriptionString In LockedAttributesRows Do
			LockedAttributes.Add(OperationDescriptionString.Name);
		EndDo;
		
		FormParameters = New Structure;
		FormParameters.Insert("ChoiceMode", True);
		FormParameters.Insert("LockedAttributes", LockedAttributes);
		
		NotifyDescription = New NotifyDescription("OnUnlockAttributes", ThisObject);
		OpenForm(FullNameOfUnlockAttributesForm, FormParameters, ThisObject, , , , NotifyDescription);
		
	Else
		RefsArray = New Array;
		FillArrayOfObjectsToChange(RefsArray);
		
		AttributeSynonyms = New Array;
		
		For Each OperationDescriptionString In LockedAttributesRows Do
			AttributeSynonyms.Add(OperationDescriptionString.Presentation);
		EndDo;
		
		If SubsystemExists("StandardSubsystems.ObjectAttributesLock") Then
			ObjectAttributesLockClientModule = CommonModule("ObjectAttributesLockClient");
			If ObjectAttributesLockClientModule <> Undefined Then
				ObjectAttributesLockClientModule.CheckObjectRefs(
					New NotifyDescription(
						"AllowEditAttributesCompletion",
						ThisObject,
						LockedAttributesRows),
					RefsArray,
					AttributeSynonyms);
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowEditAttributesCompletion(Result, LockedAttributesRows) Export
	
	If Result <> True Then
		Return;
	EndIf;
	
	For Each OperationDescriptionString In LockedAttributesRows Do
		OperationDescriptionString.LockedAttribute = False;
	EndDo;
	
EndProcedure

&AtClient
Procedure GoToChangeObjectsPage()
	
	If Items.Pages.CurrentPage = Items.ChangesSetting Then
		Items.Pages.CurrentPage = Items.ChangeObjects;
	EndIf;
	
EndProcedure

&AtClient
Procedure SettButtonsDuringChange(StartChange)
	
	ProcessingInProgress = StartChange;

	Items.FormChange.Enabled = True;
	
	If StartChange Then
		Items.FormChange.Title = NStr("ru = 'Прервать'; en = 'Abort'; pl = 'Przerwij';es_ES = 'Anular';es_CO = 'Anular';tr = 'Durdur';it = 'Interrompi';de = 'Abbrechen'");
	Else
		If ObjectsThatCouldNotBeChanged.Count() > 0 Then
			Items.FormChange.Title = NStr("ru = 'Повторить изменение'; en = 'Change again'; pl = 'Zmień ponownie';es_ES = 'Cambiar de nuevo';es_CO = 'Cambiar de nuevo';tr = 'Tekrar değiştir';it = 'Modifica ancora';de = 'Ändern Sie erneut'");
		Else
			Items.FormChange.Title = NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeObjects()
	
	ClearMessages();
	CurrentChangeStatus = New Structure;
	ObjectsCountForProcessing = SelectedObjectsCount(True, True);
	
	If Object.ChangeInTransaction Then
		
		If TransactionalBatchSetting = 1 Then // Processing in one call.
			
			ShowUserNotification(NStr("ru = 'Изменение выделенных элементов'; en = 'Change selected items'; pl = 'Zmień wybrane elementy';es_ES = 'Cambiar los artículos seleccionados';es_CO = 'Cambiar los artículos seleccionados';tr = 'Seçilmiş öğeleri değiştir';it = 'Modifica gli elementi selezionati';de = 'Ändern Sie ausgewählte Artikel'"), ,NStr("ru = 'Пожалуйста подождите, обработка может занять некоторое время...'; en = 'Please wait. Data processor may take some time...'; pl = 'Proszę czekać. Przetwarzanie danych może zająć trochę czasu...';es_ES = 'Por favor, espere. Procesador de datos puede llevar algún tiempo...';es_CO = 'Por favor, espere. Procesador de datos puede llevar algún tiempo...';tr = 'Lütfen, bekleyin. Veri işlemcisi biraz zaman alabilir...';it = 'Si prega di attendere, l''elaborazione dati potrebbe richiedere un po ''...';de = 'Bitte warten. Der Datenprozessor kann einige Zeit benötigen...'"));
			ShowProcessedItemsPercentage = False;
			
			BatchSize = ObjectsCountForProcessing;
			
		Else
			
			ShowProcessedItemsPercentage = True;
			
			If TransactionalBatchSetting = 2 Then // In batches according to the object count.
				BatchSize = ?(TransactionalNumberOfObjectsInBatch < ObjectsCountForProcessing, 
									TransactionalNumberOfObjectsInBatch, ObjectsCountForProcessing);
			Else // In batches according to object percentage.
				BatchSize = Round(ObjectsCountForProcessing * TransactionalPercentageOfObjectsInBatch / 100);
				If BatchSize = 0 Then
					BatchSize = 1;
				EndIf;
			EndIf;
			
		EndIf;
	Else
		
		If ObjectsCountForProcessing >= NontransactionalBatchLimit() Then
			// The number of objects is fixed.
			BatchSize = GetDataAsNontransactionalBatchObjects();
		Else
			// The number of objects is a percentage of the total count.
			BatchSize = Round(ObjectsCountForProcessing * GetDataAsNontransactionalBatchPercentage() / 100);
			If BatchSize = 0 Then
				BatchSize = 1;
			EndIf;
		EndIf;
		
		Status(NStr("ru = 'Обрабатываются элементы...'; en = 'Processing items...'; pl = 'Przetwarzanie elementów...';es_ES = 'Procesando artículos...';es_CO = 'Procesando artículos...';tr = 'Öğeler işleniyor...';it = 'Elaborazione degli elementi...';de = 'Elemente bearbeiten...'"), 0, NStr("ru = 'Изменение выделенных элементов'; en = 'Change selected items'; pl = 'Zmień wybrane elementy';es_ES = 'Cambiar los artículos seleccionados';es_CO = 'Cambiar los artículos seleccionados';tr = 'Seçilmiş öğeleri değiştir';it = 'Modifica gli elementi selezionati';de = 'Ändern Sie ausgewählte Artikel'"));
		
		ShowProcessedItemsPercentage = True;
	EndIf;
	
	CurrentChangeStatus.Insert("ItemsAvailableForProcessing", True);
	// Position of the last processed item, where 1 is the first item.
	CurrentChangeStatus.Insert("CurrentPosition", 0);
	CurrentChangeStatus.Insert("ErrorsCount", 0);			// Initializing the error counter.
	CurrentChangeStatus.Insert("ChangedCount", 0);		// Initializing the counter for changed items.
	CurrentChangeStatus.Insert("StopChangeOnError", Object.InterruptOnError);
	CurrentChangeStatus.Insert("ObjectsCountForProcessing", ObjectsCountForProcessing);
	CurrentChangeStatus.Insert("PortionSize", BatchSize);
	CurrentChangeStatus.Insert("ShowProcessedItemsPercentage", ShowProcessedItemsPercentage);
	CurrentChangeStatus.Insert("AbortChange", False);
	
	AttachIdleHandler("ChangeObjectsBatch", 0.1, True);
	
	Items.Pages.CurrentPage = Items.WaitingForProcessing;
EndProcedure

&AtClient
Procedure ChangeObjectsBatch()
	
	ChangeAtServer(CurrentChangeStatus.StopChangeOnError);
	
	If TimeConsumingOperation.Status = "Completed" Then
		ProcessChangeResult(GetFromTempStorage(TimeConsumingOperation.ResultAddress));
	Else
		ModuleTimeConsumingOperationsClient = CommonModule("TimeConsumingOperationsClient");
		IdleParameters = ModuleTimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow = False;
		
		NotifyDescription = New NotifyDescription("OnCompleteChange", ThisObject);
		ModuleTimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, NotifyDescription, IdleParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteChange(Result, AdditionalParameters) Export
	If Result = Undefined Then
		BackServer();
		Return;
	EndIf;
	
	If Result.Status = "Error" Then
		BackServer();
		Raise Result.BriefErrorPresentation;
	EndIf;
	
	ProcessChangeResult(GetFromTempStorage(Result.ResultAddress));
EndProcedure

&AtClient
Procedure ProcessChangeResult(ChangeResult = Undefined, ContinueProcessing = Undefined)
	Var ErrorsCount, ChangedCount;
	
	If ContinueProcessing = Undefined Then
		ContinueProcessing = True;
	EndIf;
	
	While ContinueProcessing Do
		// Updating the table for already processed objects.
		FillProcessedObjectsStatus(ChangeResult, ErrorsCount, ChangedCount);
		
		CurrentChangeStatus.ErrorsCount = ErrorsCount + CurrentChangeStatus.ErrorsCount;
		CurrentChangeStatus.ChangedCount = ChangedCount + CurrentChangeStatus.ChangedCount;
		
		If NOT (CurrentChangeStatus.StopChangeOnError AND ChangeResult.HasErrors) Then
			Break;
		EndIf;
		
		// Rolling back the entire transaction if there were errors.
		If Object.ChangeInTransaction Then
			AttachIdleHandler("CompleteObjectChange", 0.1, True);
			Return; // Exiting the cycle and procedure.
		EndIf;
		
		QuestionText = NStr("ru = 'При изменении элементов (группы элементов) возникли ошибки.
			|Прервать изменение элементов и перейти к просмотру ошибок?'; 
			|en = 'Errors occurred while editing the items (item group). 
			|Abort the items editing and go to the list of errors?'; 
			|pl = 'Wystąpiły błędy podczas modyfikowania elementów (grupy elementów).
			|Zatrzymaj modyfikowanie elementów i przejdź do wyświetlania błędów?';
			|es_ES = 'Al cambiar los elementos (el grupo de elementos) se han ocurrido errores.
			|¿Interrumpir los cambios de los elemento y pasar a la revisión de los errores?';
			|es_CO = 'Al cambiar los elementos (el grupo de elementos) se han ocurrido errores.
			|¿Interrumpir los cambios de los elemento y pasar a la revisión de los errores?';
			|tr = 'Öğeler değiştirilirken hatalar oluştu (öğe grupları). 
			|Öğe değişikliklerini sonlandırmak ve görüntülenen hatalara devam etmek istiyor musunuz?';
			|it = 'Si sono registrati errori durante la modifica degli elementi (gruppo elemento).
			|Annulla la modifica elementi e vai all''elenco degli errori?';
			|de = 'Beim Ändern von Elementen (Elementgruppen) sind Fehler aufgetreten.
			|Unterbrechen Sie die Änderung von Elementen und gehen Sie zur Fehleransicht?'");
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.Abort, NStr("ru = 'Прервать'; en = 'Abort'; pl = 'Przerwij';es_ES = 'Anular';es_CO = 'Anular';tr = 'Durdur';it = 'Interrompi';de = 'Abbrechen'"));
		Buttons.Add(DialogReturnCode.Ignore, NStr("ru = 'Продолжить'; en = 'Continue'; pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continua';de = 'Weiter'"));
		Buttons.Add(DialogReturnCode.No, NStr("ru = 'Больше не спрашивать'; en = 'Do not ask again'; pl = 'Nie pytaj ponownie';es_ES = 'No preguntar más';es_CO = 'No preguntar más';tr = 'Bir daha sorma';it = 'Non chiedere di nuovo';de = 'Nicht noch einmal fragen'"));
		
		NotifyDescription = New NotifyDescription("ProcessChangeResultResponseReceived", ThisObject, ChangeResult);
		ShowQueryBox(NotifyDescription, QuestionText, Buttons, , DialogReturnCode.Abort, NStr("ru = 'Ошибки при изменении элементов'; en = 'Errors occurred when changing items'; pl = 'Wystąpiły błędy podczas zmiany elementów';es_ES = 'Errores ocurridos al cambiar los artículos';es_CO = 'Errores ocurridos al cambiar los artículos';tr = 'Öğeler değiştirildiğinde hatalar oluştu';it = 'Si sono verificati errori durante la modifica degli elementi';de = 'Beim Ändern von Elementen sind Fehler aufgetreten'"));
		Return;
	EndDo;
	
	CurrentChangeStatus.CurrentPosition = CurrentChangeStatus.CurrentPosition + CurrentChangeStatus.PortionSize;
	
	If CurrentChangeStatus.ShowProcessedItemsPercentage Then
		// Calculating the current percentage of processed objects.
		CurrentPercentage = Round(CurrentChangeStatus.CurrentPosition / CurrentChangeStatus.ObjectsCountForProcessing * 100);
		Status(NStr("ru = 'Обрабатываются элементы...'; en = 'Processing items...'; pl = 'Przetwarzanie elementów...';es_ES = 'Procesando artículos...';es_CO = 'Procesando artículos...';tr = 'Öğeler işleniyor...';it = 'Elaborazione degli elementi...';de = 'Elemente bearbeiten...'"), CurrentPercentage, NStr("ru = 'Изменение выделенных элементов'; en = 'Change selected items'; pl = 'Zmień wybrane elementy';es_ES = 'Cambiar los artículos seleccionados';es_CO = 'Cambiar los artículos seleccionados';tr = 'Seçilmiş öğeleri değiştir';it = 'Modifica gli elementi selezionati';de = 'Ändern Sie ausgewählte Artikel'"));
	EndIf;
	
	ItemsAvailableForProcessing = ?(CurrentChangeStatus.CurrentPosition < CurrentChangeStatus.ObjectsCountForProcessing, True, False);
	
	If ItemsAvailableForProcessing AND NOT CurrentChangeStatus.AbortChange Then
		AttachIdleHandler("ChangeObjectsBatch", 0.1, True);
	Else
		AttachIdleHandler("CompleteObjectChange", 0.1, True);
	EndIf;

EndProcedure

&AtClient
Procedure ProcessChangeResultResponseReceived(QuestionResult, ChangeResult) Export
	
	If QuestionResult = Undefined Or QuestionResult = DialogReturnCode.Abort Then
		AttachIdleHandler("CompleteObjectChange", 0.1, True);
		Return;
	ElsIf QuestionResult = DialogReturnCode.No Then
		CurrentChangeStatus.StopChangeOnError = False;
	EndIf;
	
	ProcessChangeResult(ChangeResult, False);
	
EndProcedure

&AtClient
Procedure CompleteObjectChange()
	
	SettButtonsDuringChange(False);
	FinalActionsOnChangeServer();
	
	For Each Type In TypesOfObjectsToChange() Do
		NotifyChanged(Type);
	EndDo;
	
	Notify("BulkObjectChangeCompletion");
	
	ProcessingCompleted = CurrentChangeStatus.ChangedCount = CurrentChangeStatus.ObjectsCountForProcessing;
	If ProcessingCompleted Then
		ShowUserNotification(NStr("ru = 'Изменение реквизитов элементов'; en = 'Change item attributes'; pl = 'Zmień atrybuty elementów';es_ES = 'Cambiar los atributos del artículo';es_CO = 'Cambiar los atributos del artículo';tr = 'Öğe özelliklerini değiştir';it = 'Cambiare gli attributi dell''elemento';de = 'Ändern Sie die Elementattribute'"), , 
			SubstituteParametersToString(NStr("ru = 'Изменены элементы (%1).'; en = 'Items are changed (%1).'; pl = 'Elementy zostały zmienione (%1).';es_ES = 'Artículos se han cambiado (%1).';es_CO = 'Artículos se han cambiado (%1).';tr = 'Öğeler değiştirildi (%1)';it = 'Elementi cambiati (%1).';de = 'Elemente werden geändert (%1).'"), CurrentChangeStatus.ChangedCount));
		GoToCompletedPage();
		Return;
	EndIf;
	
	Items.ObjectsThatCouldNotBeChangedGroup.Visible = ObjectsThatCouldNotBeChanged.Count() > 0;
	
	If ProcessingCompleted Then
		MessageTemplate = NStr("ru = 'Изменения выполнены во всех выбранных элементах (%2).'; en = 'Changes are made in all selected items (%2).'; pl = 'Zmiany są wprowadzane we wszystkich wybranych elementach (%2).';es_ES = 'Cambios se han hecho en todos los artículos seleccionados (%2).';es_CO = 'Cambios se han hecho en todos los artículos seleccionados (%2).';tr = 'Seçilen tüm öğelerde (%2) değişiklikler yapıldı.';it = 'Le modifiche sono fatte in tutti gli elementi selezionati (%2).';de = 'Änderungen werden an allen ausgewählten Elementen vorgenommen (%2).'");
	Else
		If Object.ChangeInTransaction Or CurrentChangeStatus.ChangedCount = 0 Then
			MessageTemplate = NStr("ru = 'Изменения не выполнены.'; en = 'Not changed.'; pl = 'Nie zmieniony.';es_ES = 'No cambiado.';es_CO = 'No cambiado.';tr = 'Değiştirildi.';it = 'Modifiche non implementate.';de = 'Nicht geändert.'");
		Else
			MessageTemplate = NStr("ru = 'Изменения выполнены частично.
										|Изменено: %1; Не удалось изменить: %3'; 
										|en = 'Not all the changes have been made.
										|Changed: %1; Cannot change: %3'; 
										|pl = 'Częściowo zmodyfikowane.
										|Zmodyfikowane: %1; Nie udało się zmodyfikować: %3';
										|es_ES = 'Modificado en parte.
										|Modificado: %1; Fallado a cambiar: %3';
										|es_CO = 'Modificado en parte.
										|Modificado: %1; Fallado a cambiar: %3';
										|tr = 'Kısmen değiştirilmiş. 
										|Değiştirildi:%1; Değiştirilemedi: %3';
										|it = 'Non tutti le modifiche sono state effettuate.
										|Modificati: %1; Non possibile modificare: %3';
										|de = 'Teilweise modifiziert.
										|Geändert: %1; Fehler beim Ändern: %3'");
		EndIf;
	EndIf;
	
	If Object.ChangeInTransaction AND Not ProcessingCompleted Then
		SkippedItemsCount = CurrentChangeStatus.ObjectsCountForProcessing - CurrentChangeStatus.ErrorsCount;
		If SkippedItemsCount > 0 AND Not CurrentChangeStatus.AbortChange Then
			TableRow = ObjectsThatCouldNotBeChanged.Add();
			TableRow.Object = SubstituteParametersToString(NStr("ru = '... и другие элементы (%1)'; en = '... and other items (%1)'; pl = '... i inne elementy (%1)';es_ES = '... y otros artículos (%1)';es_CO = '... y otros artículos (%1)';tr = '...ve diğer öğeler (%1)';it = '... e altri elementi (%1)';de = '... und andere Elemente (%1)'"), SkippedItemsCount);
			TableRow.Reason = NStr("ru = 'Пропущены, так как не были изменены один или более элементов.'; en = 'Skipped as one or more items were not changed.'; pl = 'Pominięte, ponieważ jeden lub więcej elementów nie zostało zmieniono.';es_ES = 'Saltado, porque uno o más artículos no se ha cambiado.';es_CO = 'Saltado, porque uno o más artículos no se ha cambiado.';tr = 'Bir veya daha fazla öğe değişmemiş olarak atlandı.';it = 'Saltato perchè uno o più articoli non sono stati modificati.';de = 'Übersprungen, wenn ein oder mehrere Elemente nicht geändert wurden.'");
		EndIf;
	EndIf;
	
	Items.ProcessingResultsLabel.Title = SubstituteParametersToString(
		MessageTemplate,
		CurrentChangeStatus.ChangedCount,
		CurrentChangeStatus.ObjectsCountForProcessing,
		CurrentChangeStatus.ErrorsCount);
		
	Items.FormBack.Visible = True;
	
	CurrentChangeStatus = Undefined;
	
EndProcedure

&AtServer
Procedure BackServer()
	
	Items.Pages.CurrentPage = Items.ChangesSetting;
	
	ProcessingCompleted = False;
	ObjectsThatCouldNotBeChanged.Clear();
	Items.FormBack.Visible = False;
	If Object.OperationType = "ExecuteAlgorithm" Then
		Items.FormChange.Title = NStr("ru = 'Выполнить'; en = 'Execute'; pl = 'Wykonaj';es_ES = 'Ejecutar';es_CO = 'Ejecutar';tr = 'Yürüt';it = 'Esegui';de = 'Ausführen'");
		Items.FormChange.ExtendedTooltip.Title = NStr("ru = 'Выполнить алгоритм'; en = 'Execute algorithm'; pl = 'Uruchom algorytm';es_ES = 'Realizar el algoritmo';es_CO = 'Realizar el algoritmo';tr = 'Algoritmayı yap';it = 'Esegui algoritmo';de = 'Ausführen des Algorithmus'");
	Else
		Items.FormChange.Title = NStr("ru = 'Изменить реквизиты'; en = 'Change attributes'; pl = 'Zmień atrybuty';es_ES = 'Cambiar atributos';es_CO = 'Cambiar atributos';tr = 'Özellikleri değiştir';it = 'Modificare gli attributi';de = 'Attribute ändern'");
	EndIf;
	
	UpdateLabelsServer();
	
EndProcedure

&AtServer
Procedure GoToCompletedPage()
	
	Items.Pages.CurrentPage = Items.AllDone;
	Items.DoneLabel.Title = SubstituteParametersToString(
		NStr("ru = 'Реквизиты выбранных элементов были изменены.
			|Всего изменено элементов: %1'; 
			|en = 'Attributes of selected items were changed. 
			|Total items changed: %1'; 
			|pl = 'Atrybuty wybranych elementów zostały zmienione.
			|Razem zmodyfikowanych przedmiotów:%1';
			|es_ES = 'Atributos de los artículos seleccionado se han cambiado.
			|Total de artículos modificados:%1';
			|es_CO = 'Atributos de los artículos seleccionado se han cambiado.
			|Total de artículos modificados:%1';
			|tr = 'Seçilen öğelerin özellikleri değiştirildi. 
			|Değiştirilen toplam öğe sayısı:%1';
			|it = 'Gli attributi degli elementi selezionati sono stati modificati. 
			|Totale elementi modificati: %1';
			|de = 'Attribute ausgewählter Objekte wurden geändert.
			|Insgesamt geänderte Elemente: %1'"), CurrentChangeStatus.ChangedCount);
	Items.FormChange.Title = NStr("ru = 'Готово'; en = 'Finish'; pl = 'Koniec';es_ES = 'Finalizar';es_CO = 'Finalizar';tr = 'Bitiş';it = 'Termina';de = 'Abschluss'");
	Items.FormBack.Visible = True;
	
EndProcedure

&AtServer
Function TypesOfObjectsToChange()
	Result = New Array;
	For Each ObjectsKind In StrSplit(KindsOfObjectsToChange, ",", False) Do
		ObjectManager = ObjectManagerByFullName(ObjectsKind);
		Result.Add(TypeOf(ObjectManager.EmptyRef()));
	EndDo;
	Return Result;
EndFunction

&AtServer
Procedure FinalActionsOnChangeServer()
	If TimeConsumingOperation.Property("JobID") Then
		ModuleTimeConsumingOperations = CommonModule("TimeConsumingOperations");
		ModuleTimeConsumingOperations.CancelJobExecution(TimeConsumingOperation.JobID);
	EndIf;
	
	Items.Pages.CurrentPage = Items.ChangeObjects;
	SaveCurrentChangeSettings();
EndProcedure

&AtServer
Procedure SaveCurrentChangeSettings()
	
	CurrentSettings = CurrentChangeSettings();
	If CurrentSettings <> Undefined Then
		AddChangeToHistory(CurrentSettings.ChangeDescription, CurrentSettings.ChangePresentation);
	EndIf;
	
EndProcedure

&AtServer
Function CurrentChangeSettings()
	
	If Object.OperationType = "ExecuteAlgorithm" Then
		Result = New Structure;
		Result.Insert("ChangeDescription", AlgorithmCode);
		Result.Insert("ChangePresentation", Algorithm);
		Return Result;
	EndIf;
	
	ChangeDescription = New Structure;
	OperationsCollection = ObjectAttributes.FindRows(New Structure("Change", True));
	
	PresentationTemplate = "[Field] = <Value>";
	ChangePresentation = "";
	
	AttributesChangeSetting = New Array;
	For Each OperationDescription In OperationsCollection Do
		ChangeStructure = New Structure;
		ChangeStructure.Insert("OperationKind", OperationDescription.OperationKind);
		ChangeStructure.Insert("AttributeName", OperationDescription.Name);
		ChangeStructure.Insert("Property", OperationDescription.Property);
		ChangeStructure.Insert("Value", OperationDescription.Value);
		AttributesChangeSetting.Add(ChangeStructure);
		
		ValueAsString = TrimAll(String(OperationDescription.Value));
		If IsBlankString(ValueAsString) Then
			ValueAsString = """""";
		EndIf;
		Update = StrReplace(PresentationTemplate, "[Field]", TrimAll(String(OperationDescription.Presentation)));
		Update = StrReplace(Update, "<Value>", ValueAsString);
		
		If Not IsBlankString(ChangePresentation) Then
			ChangePresentation = ChangePresentation + "; ";
		EndIf;
		ChangePresentation = ChangePresentation + Update;
	EndDo;
	ChangeDescription.Insert("Attributes", AttributesChangeSetting);
	
	TabularSectionChangeSetting = New Structure;
	For Each TabularSection In TabularSectionsToChange() Do
		If Not IsBlankString(ChangePresentation) Then
			ChangePresentation = ChangePresentation + "; ";
		EndIf;
		ChangePresentation = ChangePresentation + TabularSection.Key + " (";
		AttributesChangeSetting = New Array;
		AttributesRow = "";
		For Each Attribute In TabularSection.Value Do
			ChangeStructure = New Structure("Name,Value");
			FillPropertyValues(ChangeStructure, Attribute);
			AttributesChangeSetting.Add(ChangeStructure);
			
			Update = StrReplace(PresentationTemplate, "[Field]", TrimAll(String(Attribute.Presentation)));
			Update = StrReplace(Update, "<Value>", TrimAll(String(Attribute.Value)));
			
			If Not IsBlankString(AttributesRow) Then
				AttributesRow = AttributesRow + "; ";
			EndIf;
			AttributesRow = AttributesRow + Update;
		EndDo;
		ChangePresentation = ChangePresentation + AttributesRow + ")";
		TabularSectionChangeSetting.Insert(TabularSection.Key, AttributesChangeSetting);
	EndDo;
	
	ChangeDescription.Insert("TabularSections", TabularSectionChangeSetting);
	
	Result = Undefined;
	If ValueIsFilled(ChangePresentation) Then
		Result = New Structure;
		Result.Insert("ChangeDescription", ChangeDescription);
		Result.Insert("ChangePresentation", ChangePresentation);
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure FillProcessedObjectsStatus(ChangeResult, ErrorsCount, ChangedCount)
	
	ErrorsCount = 0;
	ChangedCount = 0;
	
	For Each ProcessedObjectStatus In ChangeResult.ProcessingState Do
		If Not IsBlankString(ProcessedObjectStatus.Value.ErrorCode) Then
			ErrorsCount = ErrorsCount + 1;
			
			ErrorRecord = ObjectsThatCouldNotBeChanged.Add();
			ErrorRecord.Object = ProcessedObjectStatus.Key;
			ErrorRecord.Reason = ProcessedObjectStatus.Value.ErrorMessage;
		Else
			ChangedCount = ChangedCount + 1;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function NextBatchOfObjectsForChange()
	
	SelectionStart = CurrentChangeStatus.CurrentPosition;
	SelectionEnd = CurrentChangeStatus.CurrentPosition + CurrentChangeStatus.PortionSize - 1;
	
	SelectedObjects = SelectedObjects();
	If SelectionEnd > SelectedObjects.Rows.Count() - 1 Then
		SelectionEnd = SelectedObjects.Rows.Count() - 1;
	EndIf;
	
	Result = New ValueTree;
	For Each Column In SelectedObjects.Columns Do
		Result.Columns.Add(Column.Name, Column.ValueType);
	EndDo;
	
	For Index = SelectionStart To SelectionEnd Do
		ObjectDetails = Result.Rows.Add();
		FillPropertyValues(ObjectDetails, SelectedObjects.Rows[Index]);
		For Each ObjectString In SelectedObjects.Rows[Index].Rows Do
			FillPropertyValues(ObjectDetails.Rows.Add(), ObjectString);
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function AttributesToChange(TabularSectionName = "ObjectAttributes")
	AttributesTable = ThisObject[TabularSectionName];
	Return ValueTableToArray(AttributesTable.Unload(New Structure("Change", True)));
EndFunction

&AtServer
Function TabularSectionsToChange()
	Result = New Structure;
	For Each TabularSection In ObjectTabularSections Do
		AttributesToChange = AttributesToChange(TabularSection.Value);
		If AttributesToChange.Count() > 0 Then
			TabularSectionName = Mid(TabularSection.Value, StrLen("TabularSection") + 1);
			Result.Insert(TabularSectionName, AttributesToChange);
		EndIf;
	EndDo;
	Return Result;
EndFunction

&AtServer
Procedure ChangeAtServer(Val StopChangeOnError)
	
	ObjectsToProcess = NextBatchOfObjectsForChange();
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	JobParameters = New Structure;
	JobParameters.Insert("ObjectsToProcess", New ValueStorage(ObjectsToProcess));
	JobParameters.Insert("StopChangeOnError", StopChangeOnError);
	JobParameters.Insert("ChangeInTransaction", DataProcessorObject.ChangeInTransaction);
	JobParameters.Insert("InterruptOnError", DataProcessorObject.InterruptOnError);
	JobParameters.Insert("OperationType", DataProcessorObject.OperationType);
	JobParameters.Insert("AlgorithmCode", AlgorithmCode);
	JobParameters.Insert("ExecutionMode", DataProcessorObject.ExecutionMode);
	JobParameters.Insert("ObjectWriteOption", ?(DataProcessorObject.ObjectWriteOption = 1, "DoNotWrite", "Write"));
	JobParameters.Insert("AdditionalAttributesUsed", DataProcessorObject.AdditionalAttributesUsed);
	JobParameters.Insert("AdditionalInfoUsed", DataProcessorObject.AdditionalInfoUsed);
	JobParameters.Insert("AttributesToChange", AttributesToChange());
	JobParameters.Insert("AvailableAttributes", ValueTableToArray(ObjectAttributes.Unload(, "Name,Presentation,OperationKind,Property")));
	JobParameters.Insert("TabularSectionsToChange", TabularSectionsToChange());
	JobParameters.Insert("ObjectsForChanging", New ValueStorage(SelectedObjects()));
	JobParameters.Insert("DeveloperMode", DataProcessorObject.DeveloperMode);
	
	IsExternalDataProcessor = Not Metadata.DataProcessors.Contains(DataProcessorObject.Metadata());
	If Not Object.ChangeInTransaction Or Not SubsystemExists("StandardSubsystems.Core") Then
		StorageAddress = PutToTempStorage(Undefined, UUID);
		DataProcessorObject.ChangeObjects(JobParameters, StorageAddress);
		TimeConsumingOperation = New Structure("Status, ResultAddress", "Completed", StorageAddress);
	Else
		ModuleTimeConsumingOperations = CommonModule("TimeConsumingOperations");
		ExecutionParameters = ModuleTimeConsumingOperations.BackgroundExecutionParameters(UUID);
		ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Групповое изменение элементов'; en = 'Bulk edit of items'; pl = 'Zbiorcza edycja elementów';es_ES = 'Edición masiva de artículos';es_CO = 'Edición masiva de artículos';tr = 'Toplu grup değişiklikleri';it = 'Modifica collettiva di elementi';de = 'Massenbearbeitung von Elementen'");
		ProcedureName = DataProcessorObject.Metadata().FullName() + ".ObjectModule.ChangeObjects";
		TimeConsumingOperation = ModuleTimeConsumingOperations.ExecuteInBackground(ProcedureName, JobParameters, ExecutionParameters);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillArrayOfObjectsToChange(RefsArray)
	
	For Each SelectedObject In SelectedObjects().Rows Do
		RefsArray.Add(SelectedObject.Ref);
	EndDo;
	
EndProcedure

&AtServerNoContext
Function HierarchicalMetadataObject(FirstObjectReference)
	
	ObjectKindByRef = ObjectKindByRef(FirstObjectReference);
	
	If ((ObjectKindByRef = "Catalog" OR ObjectKindByRef = "ChartOfCharacteristicTypes") AND FirstObjectReference.Metadata().Hierarchical)
	 OR (ObjectKindByRef = "ChartOfAccounts") Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

&AtServerNoContext
Function GroupsAndItemsHierarchy(FirstObjectReference)
	
	ObjectKindByRef = ObjectKindByRef(FirstObjectReference);
	
	Return (ObjectKindByRef = "Catalog" AND FirstObjectReference.Metadata().Hierarchical
		AND FirstObjectReference.Metadata().HierarchyType = Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems)
		Or (ObjectKindByRef = "ChartOfCharacteristicTypes" AND FirstObjectReference.Metadata().Hierarchical);
	
EndFunction

&AtClientAtServerNoContext
Function NontransactionalBatchLimit()
	
	Return 100; // If there are more than 100 objects to be changed, a fixed number of objects is changed at a time 
				 // — see
				 //  GetDataAsNontransactionalBatchObjects().
	
EndFunction

&AtClientAtServerNoContext
Function GetDataAsNontransactionalBatchPercentage()
	
	Return 10;	// If there are less than 100 objects to be changed, objects are changed in batches according to a 
				// certain percentage of the total count.
	
EndFunction

&AtClientAtServerNoContext
Function GetDataAsNontransactionalBatchObjects()
	
	Return 10;	// If there are more than 100 objects to be changed, objects are changed in batches of the same 
				// count.
				// 
	
EndFunction

&AtClient
Procedure ResetChangeSettings()
	For Each Attribute In ObjectAttributes Do
		Attribute.Value = Undefined;
		Attribute.Change = False;
	EndDo;
	
	For Each TabularSection In ObjectTabularSections Do
		For Each Attribute In ThisObject[TabularSection.Value] Do
			Attribute.Value = Undefined;
			Attribute.Change = False;
		EndDo;
	EndDo;	
EndProcedure

&AtClient
Procedure FilterSettingClick(Item)
	GoToFilterSettings();
EndProcedure

&AtClient
Procedure OnCloseSelectedObjectsForm(Settings, AdditionalParameters) Export
	If TypeOf(Settings) = Type("DataCompositionSettings") Then
		SettingsComposer.LoadSettings(Settings);
		UpdateLabel();
	EndIf;
EndProcedure

&AtServerNoContext
Function FilterSettings()
	Result = New Structure;
	Result.Insert("RefreshList", False);
	Result.Insert("IncludeTabularSectionsInSelection", False);
	Result.Insert("RestrictSelection", False);
	Return Result;
EndFunction

&AtServer
Function SelectedObjects(FilterSettings = Undefined, ErrorMessageText = "")
	
	If FilterSettings = Undefined Then
		FilterSettings = FilterSettings();
	EndIf;
	
	UpdateList = FilterSettings.RefreshList;
	IncludeTabularSectionsInSelection = FilterSettings.IncludeTabularSectionsInSelection;
	RestrictSelection = FilterSettings.RestrictSelection;
	
	If Not UpdateList AND Not RestrictSelection AND Not IsBlankString(SelectedItemsListAddress) Then
		Return GetFromTempStorage(SelectedItemsListAddress);
	EndIf;
		
	Result = New ValueTree;
	
	If Not IsBlankString(KindsOfObjectsToChange) Then
		DataProcessorObject = FormAttributeToValue("Object");
		QueryText = DataProcessorObject.QueryText(KindsOfObjectsToChange, RestrictSelection);
		DataCompositionSchema = DataCompositionSchema(QueryText);
		
		DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
		SchemaURL = PutToTempStorage(DataCompositionSchema, UUID);
		DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(SchemaURL));
		DataCompositionSettingsComposer.LoadSettings(SettingsComposer.Settings);
		If IncludeTabularSectionsInSelection Then
			SetResultOutputStructureSetting(DataCompositionSettingsComposer.Settings, IncludeTabularSectionsInSelection);
		EndIf;
		
		If ObjectsThatCouldNotBeChanged.Count() > 0 AND Not Object.ChangeInTransaction Then // Repeating for unchanged objects.
			FilterItem = DataCompositionSettingsComposer.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
			FilterItem.LeftValue = New DataCompositionField("Ref");
			FilterItem.ComparisonType = DataCompositionComparisonType.InList;
			FilterItem.RightValue = New ValueList;
			FilterItem.RightValue.LoadValues(ObjectsThatCouldNotBeChanged.Unload().UnloadColumn("Object"));
		EndIf;
		
		Result = New ValueTree;
		TemplateComposer = New DataCompositionTemplateComposer;
		Try
			DataCompositionTemplate = TemplateComposer.Execute(DataCompositionSchema,
				DataCompositionSettingsComposer.Settings, , , Type("DataCompositionValueCollectionTemplateGenerator"));
		Except
			ErrorMessageText = BriefErrorDescription(ErrorInfo());
			Return Result;
		EndTry;
			
		DataCompositionProcessor = New DataCompositionProcessor;
		DataCompositionProcessor.Initialize(DataCompositionTemplate);

		OutputProcessor = New DataCompositionResultValueCollectionOutputProcessor;
		OutputProcessor.SetObject(Result);
		OutputProcessor.Output(DataCompositionProcessor);
		If Not RestrictSelection Then
			SelectedItemsListAddress = PutToTempStorage(Result, UUID);
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SetResultOutputStructureSetting(Settings, ForChange = False)
	
	Settings.Structure.Clear();
	Settings.Selection.Items.Clear();
	
	DataCompositionGroup = Settings.Structure.Add(Type("DataCompositionGroup"));
	DataCompositionGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
	DataCompositionGroup.Use = True;
	
	GroupField = DataCompositionGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
	GroupField.Field = New DataCompositionField("Ref");
	GroupField.Use = True;
	
	ComboBox = Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
	ComboBox.Field = New DataCompositionField("Ref");
	ComboBox.Use = True;
	
	If ForChange Then
		DataProcessorObject = FormAttributeToValue("Object");
		CommonObjectsAttributes = DataProcessorObject.CommonObjectsAttributes(KindsOfObjectsToChange);
		For Each TabularSection In CommonObjectsAttributes.TabularSections Do
			TabularSectionName = TabularSection.Key;
			
			TableGroup = DataCompositionGroup.Structure.Add(Type("DataCompositionGroup"));
			TableGroup.Selection.Items.Add(Type("DataCompositionAutoSelectedField"));
			TableGroup.Use = True;
			
			GroupField = TableGroup.GroupFields.Items.Add(Type("DataCompositionGroupField"));
			GroupField.Field = New DataCompositionField(TabularSectionName + ".LineNumber");
			GroupField.Use = True;
			
			ComboBox = Settings.Selection.Items.Add(Type("DataCompositionSelectedField"));
			ComboBox.Field = New DataCompositionField(TabularSectionName + ".LineNumber");
			ComboBox.Use = True;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Function SelectedObjectsCount(Recalculate = False, ForChange = False, ErrorMessageText = "")
	FilterSettings = FilterSettings();
	FilterSettings.RefreshList = Recalculate;
	FilterSettings.IncludeTabularSectionsInSelection = ForChange;
	
	Return SelectedObjects(FilterSettings, ErrorMessageText).Rows.Count();
EndFunction

&AtServer
Function DataCompositionSchema(QueryText)
	
	DataCompositionSchema = New DataCompositionSchema;
	
	DataSource = DataCompositionSchema.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "local";
	
	DataSet = DataCompositionSchema.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.DataSource = "DataSource1";
	DataSet.AutoFillAvailableFields = True;
	DataSet.Query = QueryText;
	DataSet.Name = "DataSet1";
	
	Return DataCompositionSchema;
	
EndFunction

&AtClient
Procedure KindOfObjectsToChangeWhenSelected(Val SelectedObjects, AdditionalParameters) Export
	If SelectedObjects <> Undefined AND KindsOfObjectsToChange <> SelectedObjects Then
		KindsOfObjectsToChange = StrConcat(SelectedObjects, ",");
		SelectedObjectsInContext.Clear();
		RebuildFormInterfaceForSelectedObjectKind();
		Items.ObjectAttributesAlgorithm.RowFilter = New FixedStructure(New Structure("OperationKind", "1"));
	EndIf;
EndProcedure

&AtServer
Procedure RebuildFormInterfaceForSelectedObjectKind()
	InitializeFormSettings();
	UpdateItemsVisibility();
	GenerateNoteOnConfiguredChanges();
EndProcedure

&AtServer
Procedure InitializeFormSettings()
	InitializeSettingsComposer();
	LoadObjectMetadata();
	FindUnlockAttributesForm();
	LoadOperationsHistory();
	FillPreviouslyChangedAttributesSubmenu();
	PresentationOfObjectsToChange = PresentationOfObjectsToChange();
	UpdateLabelsServer();
EndProcedure

&AtServer
Function PresentationOfObjectsToChange()
	TypesPresentation = New Array;
	For Each MetadataObjectName In StrSplit(KindsOfObjectsToChange, ",", False) Do
		MetadataObject = Metadata.FindByFullName(MetadataObjectName);
		TypesPresentation.Add(MetadataObject.Presentation());
	EndDo;
		
	Result = StrConcat(TypesPresentation, ", ");
	Return Result;
EndFunction

&AtServer
Procedure InitializeSettingsComposer()
	DataProcessorObject = FormAttributeToValue("Object");
	QueryText = DataProcessorObject.QueryText(KindsOfObjectsToChange);
	DataCompositionSchema = DataCompositionSchema(QueryText);
	SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(PutToTempStorage(DataCompositionSchema, UUID)));
	SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
	
	If SelectedObjectsInContext.Count() > 0 Then
		If Parameters.Property("SettingsComposer") AND TypeOf(Parameters.SettingsComposer) = Type("DataCompositionSettingsComposer") Then
			ComposerSettings = Parameters.SettingsComposer.GetSettings();
			SettingsComposer.LoadSettings(ComposerSettings);
			SettingsComposer.Settings.ConditionalAppearance.Items.Clear();
			
			TemplateComposer = New DataCompositionTemplateComposer;
			Try
				TemplateComposer.Execute(DataCompositionSchema, SettingsComposer.Settings,,, 
					Type("DataCompositionValueCollectionTemplateGenerator"));
			Except
				SettingsComposer.LoadSettings(DataCompositionSchema.DefaultSettings);
			EndTry;
		EndIf;
		
		FilterItem = SettingsComposer.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("Ref");
		If IncludeSubordinateItems AND ProcessRecursively Then
			FilterItem.ComparisonType = DataCompositionComparisonType.InListByHierarchy;
		Else
			FilterItem.ComparisonType = DataCompositionComparisonType.InList;
		EndIf;
		FilterItem.RightValue = New ValueList;
		FilterItem.RightValue.LoadValues(SelectedObjectsInContext.UnloadValues());
	
	EndIf;
	
	SetResultOutputStructureSetting(SettingsComposer.Settings);
	
EndProcedure

&AtServer
Procedure ClearObjectDetails()
	FormAttributesBeingDeleted = New Array;
	For Each TabularSection In ObjectTabularSections Do
		FormAttributesBeingDeleted.Add(TabularSection.Value);
		Items.Delete(Items.Find("Page" + TabularSection.Value));
	EndDo;
	ChangeAttributes(, FormAttributesBeingDeleted);
	ObjectTabularSections.Clear();
EndProcedure

&AtServer
Procedure LoadObjectMetadata(SaveCurrentChangeSettings = False, SavedSettings = Undefined)
	
	If SaveCurrentChangeSettings Then
		CurrentSettings =  CurrentChangeSettings();
		If CurrentSettings <> Undefined Then
			SavedSettings = CurrentSettings.ChangeDescription;
		EndIf;
	EndIf;
	
	ClearObjectDetails();
	
	LockedAttributes = LockedAttributes();
	AttributesToSkip = AttributesToSkip();
	DisabledAttributes = DisabledAttributes();
	
	DataProcessorObject = FormAttributeToValue("Object");
	CommonObjectsAttributes = DataProcessorObject.CommonObjectsAttributes(KindsOfObjectsToChange);
	
	FillObjectAttributes(LockedAttributes, AttributesToSkip, DisabledAttributes, CommonObjectsAttributes.Attributes);
	FillObjectsTabularSections(LockedAttributes, AttributesToSkip, DisabledAttributes, CommonObjectsAttributes.TabularSections);
	
	GenerateNoteAboutAutonumbering();
	SetConditionalAppearance();
EndProcedure

&AtServer
Procedure GenerateNoteAboutAutonumbering()
	
	Autonumbering = Undefined;
	For Each TypeName In StrSplit(KindsOfObjectsToChange, ",", False) Do
		MetadataObject = Metadata.FindByFullName(TypeName);
		
		If Metadata.ExchangePlans.Contains(MetadataObject) 
			Or Metadata.ChartsOfCalculationTypes.Contains(MetadataObject)
			Or Metadata.ChartsOfAccounts.Contains(MetadataObject) Then
				Autonumbering = Undefined;
				Break;
		EndIf;
		
		If Autonumbering = Undefined Then
			Autonumbering = MetadataObject.Autonumbering;
			Continue;
		EndIf;
		
		If Autonumbering AND Not MetadataObject.Autonumbering Then
			Autonumbering = Undefined;
			Break;
		EndIf;
	EndDo;
	
	If Autonumbering = Undefined Then
		NoteOnAutonumbering = "";
	ElsIf Autonumbering Then
		NoteOnAutonumbering = NStr("ru = '<Установить автоматически>'; en = '<Set automatically>'; pl = '<Zainstaluj automatycznie>';es_ES = '<Instalar automáticamente>';es_CO = '<Set automatically>';tr = '<Otomatik olarak yap>';it = '<Imposta automaticamente>';de = 'Automatisch setzen'");
	Else
		NoteOnAutonumbering = NStr("ru = '<Очистить>'; en = '<Clear>'; pl = '<Wyczyść>';es_ES = '<Limpiar>';es_CO = '<Clear>';tr = '<Temizle>';it = '<Cancella>';de = 'Bereinigen'");
	EndIf;
	
EndProcedure

&AtServer
Function LockSupported(ObjectName)
	
	If SubsystemExists("StandardSubsystems.ObjectAttributesLock") Then
		ModuleObjectAttributesLockInternal = CommonModule("ObjectAttributesLockInternal");
		Return ModuleObjectAttributesLockInternal.LockSupported(ObjectName);
	EndIf;
	
	Return False;
	
EndFunction

&AtServer
Function LockedAttributes()
	Result = New Array;
	
	For Each ObjectsKind In StrSplit(KindsOfObjectsToChange, ",", False) Do
		If SSLVersionMatchesRequirements() Then
			If LockSupported(ObjectsKind) Then
				ObjectManager = ObjectManagerByFullName(ObjectsKind);
				AttributesToLockDetails = ObjectManager.GetObjectAttributesToLock();
			EndIf;
		Else
			// Checking if there are lockable attributes ("Disable changing object attributes" subsystem) in 
			// case of no-SSL or old-SSL configurations.
			ObjectManager = ObjectManagerByFullName(ObjectsKind);
			Try
				AttributesToLockDetails = ObjectManager.GetObjectAttributesToLock();
			Except
				// Method not found
				AttributesToLockDetails = Undefined;
			EndTry;
		EndIf;
	
		If AttributesToLockDetails <> Undefined Then
			For Each AttributeToLockDetails In AttributesToLockDetails Do
				AttributeName = TrimAll(StrSplit(AttributeToLockDetails, ";")[0]);
				If Result.Find(AttributeName) = Undefined Then
					Result.Add(AttributeName);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

&AtServerNoContext
Function ObjectManagerMethodsForEditingAttributes(ObjectName)
	
	ModuleSubsystemIntegrationSSL = CommonModule("SSLSubsystemsIntegration");
	ModuleBatchObjectModificationOverridable = CommonModule("BatchEditObjectsOverridable");
	If ModuleSubsystemIntegrationSSL = Undefined Or ModuleBatchObjectModificationOverridable = Undefined Then
		Return New Array;
	EndIf;
	
	ObjectsWithLockedAttributes = New Map;
	ModuleSubsystemIntegrationSSL.OnDefineObjectsWithEditableAttributes(ObjectsWithLockedAttributes);
	ModuleBatchObjectModificationOverridable.OnDefineObjectsWithEditableAttributes(ObjectsWithLockedAttributes);
	
	InformationOnObjectManager = ObjectsWithLockedAttributes[ObjectName];
	If InformationOnObjectManager = Undefined Then
		Return "Unsupported";
	EndIf;
	AvailableMethods = StrSplit(InformationOnObjectManager, Chars.LF, False);
	Return AvailableMethods;
	
EndFunction

&AtServer
Function AttributesToSkip()
	
	If Object.ShowInternalAttributes Then
		Return New Array;
	EndIf;
	
	Result = New Array;
	For Each KindOfObjectsToChange In StrSplit(KindsOfObjectsToChange, ",", False) Do
	
		SSLVersionMatchesRequirements = SSLVersionMatchesRequirements();
		If SSLVersionMatchesRequirements Then
			AvailableMethods = ObjectManagerMethodsForEditingAttributes(KindOfObjectsToChange);
			If TypeOf(AvailableMethods) = Type("Array") AND (AvailableMethods.Count() = 0
				Or AvailableMethods.Find("AttributesToSkipInBatchProcessing") <> Undefined) Then
					ObjectManager = ObjectManagerByFullName(KindOfObjectsToChange);
					ToSkip = ObjectManager.AttributesToSkipInBatchProcessing();
			Else 
				ToSkip = New Array;
			EndIf;
		Else
			// Checking if there are non-editable attributes in case of no-SSL or old-SSL configurations.
			// 
			ObjectManager = ObjectManagerByFullName(KindOfObjectsToChange);
			Try
				ToSkip = ObjectManager.AttributesToSkipInBatchProcessing();
			Except
				// Method not found
				ToSkip = New Array;
			EndTry;
		EndIf;
			
		If ToSkip.Count() > 0 Then
			Return ToSkip;
		EndIf;
		
		If SSLVersionMatchesRequirements Then
			If TypeOf(AvailableMethods) = Type("Array") AND (AvailableMethods.Count() = 0
				Or AvailableMethods.Find("AttributesToEditInBatchProcessing") <> Undefined) Then 
					If ObjectManager = Undefined Then
						ObjectManager = ObjectManagerByFullName(KindOfObjectsToChange);
					EndIf;
					ToEdit = ObjectManager.AttributesToEditInBatchProcessing();
			Else
				ToEdit = Undefined;
			EndIf;
		Else
			// Checking if there are editable attributes in case of no-SSL or old-SSL configurations.
			// 
			Try
				ToEdit = ObjectManager.AttributesToEditInBatchProcessing();
			Except
				ToEdit = Undefined;
			EndTry;
		EndIf;

		If ToEdit = Undefined Or ToEdit.Find("*") <> Undefined Then
			Return ToSkip;
		EndIf;
		
		MetadataObject = Metadata.FindByFullName(KindOfObjectsToChange);
		For Each AttributeDetails In MetadataObject.StandardAttributes Do
			ToSkip.Add(AttributeDetails.Name);
		EndDo;
		
		For Each AttributeDetails In MetadataObject.Attributes Do
			ToSkip.Add(AttributeDetails.Name);
		EndDo;
		
		For Each TabularSection In MetadataObject.TabularSections Do
			If ToEdit.Find(TabularSection.Name + ".*") <> Undefined Then
				Break;
			EndIf;
			For Each Attribute In TabularSection.Attributes Do
				ToSkip.Add(TabularSection.Name + "." + Attribute.Name);
			EndDo;
		EndDo;
		
		For Each NameOfAttributeToEdit In ToEdit Do
			Index = ToSkip.Find(NameOfAttributeToEdit);
			If Index = Undefined Then
				Continue;
			EndIf;
			ToSkip.Delete(Index);
		EndDo;
		
		For Each Attribute In ToSkip Do
			If Result.Find(Attribute) = Undefined Then
				Result.Add(Attribute);
			EndIf;
		EndDo;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function DisabledAttributes()
	Result = New Array;
	If Object.ShowInternalAttributes Then
		Return Result;
	EndIf;
	
	For Each TypeName In StrSplit(KindsOfObjectsToChange, ",", False) Do
		MetadataObject = Metadata.FindByFullName(TypeName);
		DisabledAttributes = GetEditFilterByType(MetadataObject);
		
		AttributesDisabledByFunctionalOptions = New ValueTable;
		AttributesDisabledByFunctionalOptions.Columns.Add("AttributeName",  New TypeDescription("String"));
		
		For Each FODetails In Metadata.FunctionalOptions Do
			If StrSplit(FODetails.Location.FullName(), ".")[0] = "Constant" Then
				FOValue = GetFunctionalOption(FODetails.Name);
				If TypeOf(FOValue) = Type("Boolean") AND FOValue = True Then
					Continue;
				EndIf;
			Else
				// Omitting attributes included in parameterized functional options.
				Continue;
			EndIf;
			
			For Each MOAttribute In MetadataObject.Attributes Do
				If FODetails.Content.Contains(MOAttribute) Then
					NewRow = AttributesDisabledByFunctionalOptions.Add();
					NewRow.AttributeName = MOAttribute.Name;
				EndIf;
			EndDo;
			
			For Each TabularSection In MetadataObject.TabularSections Do
				If FODetails.Content.Contains(TabularSection) Then
					NewRow = AttributesDisabledByFunctionalOptions.Add();
					NewRow.AttributeName = TabularSection.Name + ".*";
				EndIf;
			EndDo;
		EndDo;
		
		AttributesDisabledByFunctionalOptions.GroupBy("AttributeName");
		
		For Each AttributeDisabledByFO In AttributesDisabledByFunctionalOptions Do
			DisabledAttributes.Add(AttributeDisabledByFO.AttributeName);
		EndDo;
		
		For Each Attribute In DisabledAttributes Do
			If Result.Find(Attribute) = Undefined Then
				Result.Add(Attribute);
			EndIf;
		EndDo;
	EndDo;
		
	Return Result;
EndFunction

&AtServer
Procedure FillObjectsTabularSections(LockedAttributes, AttributesToSkip, DisabledAttributes, AvailableTabularSections)
	
	KindsOfObjectsToChangeList = StrSplit(KindsOfObjectsToChange, ",", False);
	ObjectName = KindsOfObjectsToChangeList[0];
	
	MetadataObject = Metadata.FindByFullName(ObjectName);
	
	// Creating attributes for tabular sections.
	NewFormAttributes = New Array;
	
	TableColumns = AttributesTableColumnDescriptions();
	
	ObjectTables = New Structure;
	ObjectTabularSections.Clear();
	For Each TabularSectionDetails In MetadataObject.TabularSections Do
		If Not AvailableTabularSections.Property(TabularSectionDetails.Name) Then
			Continue;
		EndIf;
			
		If Not AccessRight("Edit", TabularSectionDetails) Then
			Continue;
		EndIf;
		// Tabular section filters
		If AttributesToSkip.Find(TabularSectionDetails.Name + ".*") <> Undefined Then
			Continue;
		EndIf;
		If DisabledAttributes.Find(TabularSectionDetails.Name + ".*") <> Undefined Then
			Continue;
		EndIf;
		
		EditableAttributes = EditableAttributes(TabularSectionDetails, AttributesToSkip,
			DisabledAttributes, AvailableTabularSections[TabularSectionDetails.Name]);
			
		If EditableAttributes.Count() = 0 Then
			Continue;
		EndIf;
		
		AttributeName = "TabularSection" + TabularSectionDetails.Name;
		ValueTable = New FormAttribute(AttributeName, New TypeDescription("ValueTable"), , TabularSectionDetails.Presentation());
		NewFormAttributes.Add(ValueTable);
		
		For Each ColumnDetails In TableColumns Do 
			TableAttribute = New FormAttribute(ColumnDetails.Name, ColumnDetails.Type, ValueTable.Name, ColumnDetails.Presentation);
			NewFormAttributes.Add(TableAttribute);
		EndDo;
		
		ObjectTables.Insert(AttributeName, TabularSectionDetails);
		ObjectTabularSections.Add(AttributeName, TabularSectionDetails.Presentation());
	EndDo;
	ChangeAttributes(NewFormAttributes);
	
	For Each ObjectTable In ObjectTables Do
		AttributeName = ObjectTable.Key;
		PageName = "Page" + AttributeName;
		Page = Items.Add(PageName, Type("FormGroup"), Items.ObjectComposition);
		Page.Type = FormGroupType.Page;
		TabularSectionDetails = ObjectTable.Value;
		Page.Title = TabularSectionDetails.Presentation();
		
		// Creating items for tabular sections.
		FormTable = Items.Add(AttributeName, Type("FormTable"), Page);
		FormTable.TitleLocation = FormItemTitleLocation.None;
		FormTable.DataPath = AttributeName;
		FormTable.CommandBarLocation = FormItemCommandBarLabelLocation.None;
		FormTable.Title = TabularSectionDetails.Presentation();
		FormTable.SetAction("BeforeRowChange", "Attachable_BeforeStartCHange");
		FormTable.ChangeRowOrder = False;
		FormTable.ChangeRowSet = False;
		FormTable.RowsPicture = OperationsKindsPicture();
		FormTable.RowPictureDataPath = AttributeName + ".OperationKind";
		FormTable.Height = 5;
		
		For Each ColumnDetails In TableColumns Do 
			If ColumnDetails.FieldKind = Undefined Then
				Continue;
			EndIf;
			AttributeName = ColumnDetails.Name;
			ItemName = FormTable.Name + AttributeName;
			TableColumn = Items.Add(ItemName, Type("FormField"), FormTable);
			If ColumnDetails.Picture <> Undefined Then
				TableColumn.TitleLocation = FormItemTitleLocation.None;
				TableColumn.HeaderPicture = ColumnDetails.Picture;
			EndIf;
			TableColumn.DataPath = ObjectTable.Key + "." + AttributeName;
			TableColumn.Type = ColumnDetails.FieldKind;
			TableColumn.EditMode = ColumnEditMode.EnterOnInput;
			TableColumn.ReadOnly = ColumnDetails.ReadOnly;
			If ColumnDetails.Actions <> Undefined Then
				For Each Action In ColumnDetails.Actions Do
					TableColumn.SetAction(Action.Key, Action.Value);
				EndDo;
			EndIf;
		EndDo;
		
		EditableAttributes = EditableAttributes(TabularSectionDetails, AttributesToSkip,
			DisabledAttributes, AvailableTabularSections[TabularSectionDetails.Name]);
			
		For Each AttributeDetails In EditableAttributes Do
			Attribute = ThisObject[ObjectTable.Key].Add();
			Attribute.Name = AttributeDetails.Name;
			Attribute.Presentation = ?(IsBlankString(AttributeDetails.Presentation()), AttributeDetails.Name, AttributeDetails.Presentation());
			Attribute.ValidTypes = AttributeDetails.Type;
			Attribute.ChoiceParameterLinks = ChoiceParameterLinksAsString(AttributeDetails.ChoiceParameterLinks);
			Attribute.ChoiceParameters = ChoiceParametersAsString(AttributeDetails.ChoiceParameters);
			Attribute.OperationKind = 1;
			Attribute.ChoiceParameterLinksPresentation = ChoiceParameterLinksPresentation(AttributeDetails.ChoiceParameterLinks, MetadataObject);
		EndDo;
	EndDo;
	
EndProcedure

&AtServer
Function EditableAttributes(TabularSectionDetails, AttributesToSkip, DisabledAttributes, AvailableAttributes)
	
	Result = New Array;
	
	For Each AttributeDetails In TabularSectionDetails.Attributes Do
		If AvailableAttributes.Find(AttributeDetails.Name) = Undefined Then
			Continue;
		EndIf;
		
		If Not AccessRight("Edit", AttributeDetails) Then
			Continue;
		EndIf;
		// Tabular section attribute filters.
		If AttributesToSkip.Find(TabularSectionDetails.Name + "." + AttributeDetails.Name) <> Undefined Then
			Continue;
		EndIf;
		If DisabledAttributes.Find(TabularSectionDetails.Name + "." + AttributeDetails.Name) <> Undefined Then
			Continue;
		EndIf;
		
		Result.Add(AttributeDetails);
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function AttributesTableColumnDescriptions()
	
	TableColumns = New ValueTable;
	TableColumns.Columns.Add("Name");
	TableColumns.Columns.Add("Type");
	TableColumns.Columns.Add("Presentation");
	TableColumns.Columns.Add("FieldKind");
	TableColumns.Columns.Add("Actions");
	TableColumns.Columns.Add("ReadOnly", New TypeDescription("Boolean"));
	TableColumns.Columns.Add("Picture");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Name";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Presentation";
	ColumnDetails.Type = New TypeDescription("String");
	ColumnDetails.Presentation = NStr("ru = 'Реквизит'; en = 'Attribute'; pl = 'Atrybut';es_ES = 'Atributo';es_CO = 'Atributo';tr = 'Öznitelik';it = 'Attributo';de = 'Attribut'");
	ColumnDetails.FieldKind = FormFieldType.InputField;
	ColumnDetails.ReadOnly = True;
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Change";
	ColumnDetails.Type = New TypeDescription("Boolean");
	ColumnDetails.FieldKind = FormFieldType.CheckBoxField;
	ColumnDetails.Picture = PictureLib.Change;
	ColumnDetails.Actions = New Structure("OnChange", "Attachable_OnChangeFlag");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Value";
	ColumnDetails.Type = AllTypes();
	ColumnDetails.Presentation = NStr("ru = 'Новое значение'; en = 'New value'; pl = 'Nowa wartość';es_ES = 'Nuevo valor';es_CO = 'Nuevo valor';tr = 'Yeni değer';it = 'Nuovo valore';de = 'Neuer Wert'");
	ColumnDetails.FieldKind = FormFieldType.InputField;
	ColumnDetails.Actions = New Structure("OnChange", "Attachable_ValueOnChange");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "ValidTypes";
	ColumnDetails.Type = New TypeDescription("TypeDescription");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "ChoiceParameterLinks";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "ChoiceParameters";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "OperationKind";
	ColumnDetails.Type = New TypeDescription("Number");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "Property";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "ChoiceFoldersAndItems";
	ColumnDetails.Type = New TypeDescription("String");
	
	ColumnDetails = TableColumns.Add();
	ColumnDetails.Name = "ChoiceParameterLinksPresentation";
	ColumnDetails.Type = New TypeDescription("String");
	
	Return TableColumns;
	
EndFunction

&AtServer
Function AllTypes()
	Result = Undefined;
	Attributes = GetAttributes("ObjectAttributes");
	For Each Attribute In Attributes Do
		If Attribute.Name = "Value" Then
			Result = Attribute.ValueType;
			Break;
		EndIf;
	EndDo;
	Return Result;
EndFunction

&AtClient
Procedure RestrictSelectableTypesAndSetValueChoiceParameters(TableBox)
	If TableBox.CurrentData = Undefined Then
		Return;
	EndIf;
	
	InputField = TableBox.ChildItems[TableBox.Name + "Value"];
	InputField.TypeRestriction = TableBox.CurrentData.ValidTypes;
	
	If InputField.TypeRestriction.Types().Count() = 1 AND InputField.TypeRestriction.ContainsType(Type("String")) Then
		InputField.ChoiceButton = True;
	EndIf;
	
	ChoiceParametersArray = New Array;
	
	If NOT IsBlankString(TableBox.CurrentData.ChoiceParameters) Then
		SetChoiceParametersServer(TableBox.CurrentData.ChoiceParameters, ChoiceParametersArray)
	EndIf;
	
	If Not IsBlankString(TableBox.CurrentData.ChoiceParameterLinks) Then
		For Index = 1 To StrLineCount(TableBox.CurrentData.ChoiceParameterLinks) Do
			ChoiceParametersLinksString = StrGetLine(TableBox.CurrentData.ChoiceParameterLinks, Index);
			ParsedStrings = StrSplit(ChoiceParametersLinksString, ";");
			ParameterName = TrimAll(ParsedStrings[0]);
			
			AttributeName = TrimAll(ParsedStrings[1]);
			AttributeNameParts = StrSplit(AttributeName, ".", False);
			TabularSectionName = "";
			If AttributeNameParts.Count() > 1 Then
				TabularSectionName = AttributeNameParts[0];
			EndIf;
			AttributeName = AttributeNameParts[AttributeNameParts.Count() - 1];
			
			AttributesTable = ObjectAttributes;
			If Not IsBlankString(TabularSectionName) Then
				AttributesTable = ThisObject["TabularSection" + TabularSectionName];
			EndIf;
			
			FoundRows = AttributesTable.FindRows(New Structure("OperationKind,Name", 1, AttributeName));
			If FoundRows.Count() = 1 Then
				Value = FoundRows[0].Value;
				If ValueIsFilled(Value) Then
					ChoiceParametersArray.Add(New ChoiceParameter(ParameterName, Value));
				EndIf;
			EndIf;
		EndDo;
	EndIf;
	
	If ValueIsFilled(TableBox.CurrentData.Property) Then
		ChoiceParametersArray.Add(New ChoiceParameter("Filter.Owner", TableBox.CurrentData.Property));
	EndIf;
	
	If DisableSelectionParameterConnections Then
		InputField.ChoiceParameters = New FixedArray(New Array);
	Else
		InputField.ChoiceParameters = New FixedArray(ChoiceParametersArray);
	EndIf;
	
	ChoiceOfGroupsAndItems = TableBox.CurrentData.ChoiceFoldersAndItems;
	
	If ChoiceOfGroupsAndItems <> "" Then
		If ChoiceOfGroupsAndItems = "Folders" Then
			InputField.ChoiceFoldersAndItems = FoldersAndItems.Folders;
		ElsIf ChoiceOfGroupsAndItems = "FoldersAndItems" Then
			InputField.ChoiceFoldersAndItems = FoldersAndItems.FoldersAndItems;
		ElsIf ChoiceOfGroupsAndItems = "Items" Then
			InputField.ChoiceFoldersAndItems = FoldersAndItems.Items;
		Else
			InputField.ChoiceFoldersAndItems = FoldersAndItems.Auto;
		EndIf;
	Else
		InputField.ChoiceFoldersAndItems = FoldersAndItems.Auto;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateCountersOfAttributesToChange(Val FormTable = Undefined)
	
	TableList = New Array;
	If FormTable <> Undefined Then
		TableList.Add(FormTable);
	Else
		TableList.Add(Items.ObjectAttributes);
		For Each TabularSection In ObjectTabularSections Do
			TableList.Add(Items[TabularSection.Value]);
		EndDo;
	EndIf;
	
	For Each FormTable In TableList Do
		TabularSection = ThisObject[FormTable.Name];
		ItemsToChangeCount = 0;
		For Each Attribute In TabularSection Do
			If Attribute.Change Then
				ItemsToChangeCount = ItemsToChangeCount + 1;
			EndIf;
		EndDo;
	
		Page = FormTable.Parent;
		Page.Title = FormTable.Title + ?(ItemsToChangeCount = 0, "", " (" + ItemsToChangeCount+ ")");
	EndDo;
	
EndProcedure

&AtServer
Procedure UpdateItemsVisibility()
	If ObjectTabularSections.Count() = 0 Then
		Items.ObjectComposition.PagesRepresentation = FormPagesRepresentation.None;
	Else
		Items.ObjectComposition.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
	EndIf;
	
	If Not IsBlankString(KindsOfObjectsToChange) Then
		CommonAttributesAvailable = ObjectAttributes.Count() > 0;
		Items.NoAttributesGroup.Visible = Not CommonAttributesAvailable;
		If Object.OperationType = "ExecuteAlgorithm" Then
			Items.Algorithms.Visible = True;
		Else
			Items.PreviouslyChangedAttributes.Visible = CommonAttributesAvailable Or ObjectTabularSections.Count() > 0;
		EndIf;
		Items.ObjectAttributes.Visible = CommonAttributesAvailable;
	EndIf;
EndProcedure

&AtServer
Procedure FillObjectAttributes(AttributesToLock, ToSkip, DisabledAttributes, AvailableAttributes)
	
	AttributesSets = New Structure;
	AttributesSets.Insert("ToSkip", ToSkip);
	AttributesSets.Insert("Disabled", DisabledAttributes);
	AttributesSets.Insert("ToLock", AttributesToLock);
	AttributesSets.Insert("Available", AvailableAttributes);
	
	
	KindsOfObjectsToChangeList = StrSplit(KindsOfObjectsToChange, ",", False);
	ObjectName = KindsOfObjectsToChangeList[0];
	
	MetadataObject = Metadata.FindByFullName(ObjectName);
	ObjectAttributes.Clear();
	
	AttributesSets.Insert("AttributesDetails", MetadataObject.StandardAttributes);
	AddAttributesToSet(AttributesSets, MetadataObject);
	
	AttributesSets.Insert("AttributesDetails", MetadataObject.Attributes);
	AddAttributesToSet(AttributesSets, MetadataObject);
	
	ObjectAttributes.Sort("Presentation Asc");
	
	If SubsystemExists("StandardSubsystems.Properties") Then
		ModulePropertyManager = CommonModule("PropertyManager");
		If ModulePropertyManager <> Undefined Then
			AdditionalAttributesUsed = True;
			AdditionalInfoUsed = True;
			For Each ObjectKind In KindsOfObjectsToChangeList Do
				ObjectManager = ObjectManagerByFullName(ObjectKind);
				AdditionalAttributesUsed = AdditionalAttributesUsed AND ModulePropertyManager.UseAddlAttributes(ObjectManager.EmptyRef());
				AdditionalInfoUsed  = AdditionalInfoUsed AND ModulePropertyManager.UseAddlInfo (ObjectManager.EmptyRef());
			EndDo;
			If AdditionalAttributesUsed Or AdditionalInfoUsed Then
				AddAdditionalAttributesAndInfoToSet();
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure AddAdditionalAttributesAndInfoToSet()
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	KindsOfObjectsToChangeList = StrSplit(KindsOfObjectsToChange, ",", False);
	CommonAttributesList = PropertiesListForObjectsKind(KindsOfObjectsToChangeList[0]);
	For Index = 1 To KindsOfObjectsToChangeList.Count() - 1 Do
		CommonAttributesList = DataProcessorObject.SetIntersection(CommonAttributesList, PropertiesListForObjectsKind(KindsOfObjectsToChangeList[Index]));
	EndDo;
	
	If ContextCall Then
		FilterSettings = FilterSettings();
		FilterSettings.RefreshList = True;
		For Each ObjectData In SelectedObjects(FilterSettings).Rows Do
			ObjectToChange = ObjectData.Ref;
			
			ObjectKindByRef = ObjectKindByRef(ObjectToChange);
			If (ObjectKindByRef = "Catalog" OR ObjectKindByRef = "ChartOfCharacteristicTypes") AND ObjectIsFolder(ObjectToChange) Then
				Continue;
			EndIf;
			
			ModulePropertyManager = CommonModule("PropertyManager");
			PropertiesList = ModulePropertyManager.ObjectProperties(ObjectToChange);
			For Each Property In PropertiesList Do
				If CommonAttributesList.Find(Property) = Undefined Then
					Continue;
				EndIf;
				
				If ObjectAttributes.FindRows(New Structure("Property", Property)).Count() > 0 Then
					Continue;
				EndIf;
				
				AddPropertyToAttributesList(Property);
			EndDo;
		EndDo;
	Else
		For Each Attribute In CommonAttributesList Do
			AddPropertyToAttributesList(Attribute);
		EndDo;
	EndIf;
	
	ObjectAttributes.Sort("Presentation");
	
EndProcedure

&AtServer
Procedure AddPropertyToAttributesList(Property)
	PropertyDetails = ObjectAttributeValues(Property, "Ref,Description,ValueType,IsAdditionalInfo");
	AttributeDetails = ObjectAttributes.Add();
	AttributeDetails.OperationKind = ?(PropertyDetails.IsAdditionalInfo, 3, 2);
	AttributeDetails.Property = PropertyDetails.Ref;
	AttributeDetails.Presentation = PropertyDetails.Description;
	AttributeDetails.ValidTypes = PropertyDetails.ValueType;
EndProcedure

&AtServer
Function PropertiesListForObjectsKind(ObjectsKind)
	Result = New Array;
	
	PropertyKinds = New Array;
	PropertyKinds.Add("AdditionalAttributes");
	PropertyKinds.Add("AdditionalInfo");
	
	ModulePropertyManagerInternal = CommonModule("PropertyManagerInternal");
	If ModulePropertyManagerInternal <> Undefined Then
		For Each PropertyKind In PropertyKinds Do
			PropertiesList = ModulePropertyManagerInternal.PropertiesListForObjectsKind(ObjectsKind, PropertyKind);
			If PropertiesList <> Undefined Then
				For Each Item In PropertiesList Do
					Result.Add(Item.Property);
				EndDo;
			EndIf;
		EndDo;
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Procedure AddAttributesToSet(AttributesSets, MetadataObject)
	
	Attributes = AttributesSets.AttributesDetails;
	ToSkip = AttributesSets.ToSkip;
	DisabledAttributes = AttributesSets.Disabled;
	AttributesToLock = AttributesSets.ToLock;
	ListAvailableAttributes = AttributesSets.Available;
	
	For Each AttributeDetails In Attributes Do
		If ListAvailableAttributes.Find(AttributeDetails.Name) = Undefined Then
			Continue;
		EndIf;
		
		If TypeOf(AttributeDetails) = Type("StandardAttributeDescription") Then
			If NOT AccessRight("Edit", MetadataObject, , AttributeDetails.Name) Then
				Continue;
			EndIf;
		Else
			If NOT AccessRight("Edit", AttributeDetails) Then
				Continue;
			EndIf;
		EndIf;
		
		If ToSkip.Find(AttributeDetails.Name) <> Undefined Then
			Continue;
		EndIf;
		
		If DisabledAttributes.Find(AttributeDetails.Name) <> Undefined Then
			Continue;
		EndIf;
		
		ChoiceOfGroupsAndItems = "";
		If TypeOf(AttributeDetails) = Type("StandardAttributeDescription") Then
			If AttributeDetails.Name = "Parent" Or AttributeDetails.Name = "Parent" Then
				ChoiceOfGroupsAndItems = "Folders";
			ElsIf AttributeDetails.Name = "Owner" Or AttributeDetails.Name = "Owner" Then
				If MetadataObject.SubordinationUse = Metadata.ObjectProperties.SubordinationUse.ToItems Then
					ChoiceOfGroupsAndItems = "Items";
				ElsIf MetadataObject.SubordinationUse = Metadata.ObjectProperties.SubordinationUse.ToFoldersAndItems Then
					ChoiceOfGroupsAndItems = "FoldersAndItems";
				ElsIf MetadataObject.SubordinationUse = Metadata.ObjectProperties.SubordinationUse.ToFolders Then
					ChoiceOfGroupsAndItems = "Folders";
				EndIf;
			EndIf;
		Else
			IsReference = False;
			
			For Each Type In AttributeDetails.Type.Types() Do
				If IsReference(Type) Then
					IsReference = True;
					Break;
				EndIf;
			EndDo;
			
			If IsReference Then
				If AttributeDetails.ChoiceFoldersAndItems = FoldersAndItemsUse.Folders Then
					ChoiceOfGroupsAndItems = "Folders";
				ElsIf AttributeDetails.ChoiceFoldersAndItems = FoldersAndItemsUse.FoldersAndItems Then
					ChoiceOfGroupsAndItems = "FoldersAndItems";
				ElsIf AttributeDetails.ChoiceFoldersAndItems = FoldersAndItemsUse.Items Then
					ChoiceOfGroupsAndItems = "Items";
				EndIf;
			EndIf;
		EndIf;
		
		KindsOfObjectsToChangeList = StrSplit(KindsOfObjectsToChange, ",", False);
		ChoiceParameterLinksPresentation = "";
		If KindsOfObjectsToChangeList.Count() = 1 Then
			ChoiceParametersString = ChoiceParametersAsString(AttributeDetails.ChoiceParameters);
			ChoiceParameterLinksString = ChoiceParameterLinksAsString(AttributeDetails.ChoiceParameterLinks);
			ChoiceParameterLinksPresentation = ChoiceParameterLinksPresentation(AttributeDetails.ChoiceParameterLinks, MetadataObject);
		Else
			ChoiceParametersString = ChoiceParametersAsString(New Array);
			ChoiceParameterLinksString = ChoiceParameterLinksAsString(New Array);
		EndIf;
		
		ObjectAttribute = ObjectAttributes.Add();
		ObjectAttribute.Name = AttributeDetails.Name;
		ObjectAttribute.Presentation = AttributeDetails.Presentation();
		
		ObjectAttribute.ValidTypes = AttributeDetails.Type;
		ObjectAttribute.ChoiceParameters = ChoiceParametersString;
		ObjectAttribute.ChoiceParameterLinks = ChoiceParameterLinksString;
		ObjectAttribute.ChoiceParameterLinksPresentation = ChoiceParameterLinksPresentation;
		ObjectAttribute.ChoiceFoldersAndItems = ChoiceOfGroupsAndItems;
		ObjectAttribute.OperationKind = 1;
		
		If AttributesToLock.Find(AttributeDetails.Name) <> Undefined Then
			ObjectAttribute.LockedAttribute = True;
		EndIf;
		
		ObjectAttribute.IsStandardAttribute = TypeOf(AttributeDetails) = Type("StandardAttributeDescription");
		
	EndDo;
	
EndProcedure

// Gets an array of attributes not editable at the configuration level.
// 
//
&AtServer
Function GetEditFilterByType(MetadataObject)
	
	DataProcessorObject = FormAttributeToValue("Object");
	XMLFilter = DataProcessorObject.GetTemplate("AttributeFilter").GetText();
	
	FilterTable = ReadXMLToTable(XMLFilter).Data;
	
	// Attributes lockable for any metadata object type.
	CommonFilter = FilterTable.FindRows(New Structure("ObjectType", "*"));
	
	// Attributes lockable for the specified metadata object type.
	FilterByMOType = FilterTable.FindRows(
							New Structure("ObjectType", 
							BaseTypeNameByMetadataObject(MetadataObject)));
	
	DisabledAttributes = New Array;
	
	For Each RowDescription In CommonFilter Do
		DisabledAttributes.Add(RowDescription.Attribute);
	EndDo;
	
	For Each RowDescription In FilterByMOType Do
		DisabledAttributes.Add(RowDescription.Attribute);
	EndDo;
	
	AttributesBeingDeletedPrefix = "Delete";
	For Each Attribute In MetadataObject.Attributes Do
		If Lower(Left(Attribute.Name, StrLen(AttributesBeingDeletedPrefix))) = Lower(AttributesBeingDeletedPrefix) Then
			DisabledAttributes.Add(Attribute.Name);
		EndIf;
	EndDo;
	For Each TabularSection In MetadataObject.TabularSections Do
		If Lower(Left(TabularSection.Name, StrLen(AttributesBeingDeletedPrefix))) = Lower(AttributesBeingDeletedPrefix) Then
			DisabledAttributes.Add(TabularSection.Name + ".*");
		Else
			For Each Attribute In TabularSection.Attributes Do
				If Lower(Left(Attribute.Name, StrLen(AttributesBeingDeletedPrefix))) = Lower(AttributesBeingDeletedPrefix) Then
					DisabledAttributes.Add(TabularSection.Name + "." + Attribute.Name);
				EndIf;
			EndDo;
		EndIf;
	EndDo;
	
	Return DisabledAttributes;
	
EndFunction

&AtServer
Function FilterItemsNoHierarchy(Val FilterItems)
	Result = New Array;
	For Each FilterItem In FilterItems Do
		If TypeOf(FilterItem) = Type("DataCompositionFilterItemGroup") Then
			SubordinateFilters = FilterItemsNoHierarchy(FilterItem.Items);
			For Each SubordinateFilter In SubordinateFilters Do
				Result.Add(SubordinateFilter);
			EndDo;
		Else
			Result.Add(FilterItem);
		EndIf;
	EndDo;
	Return Result;
EndFunction

&AtServer
Procedure GenerateNoteOnConfiguredChanges()
	
	FilterByRowsAvailable = False;
	For Each FilterItem In FilterItemsNoHierarchy(SettingsComposer.Settings.Filter.Items) Do
		If Not FilterItem.Use Then
			Continue;
		EndIf;
		For Each TabularSection In ObjectTabularSections Do
			TabularSectionName = Mid(TabularSection.Value, StrLen("TabularSection") + 1);
			If StrStartsWith(FilterItem.LeftValue, TabularSectionName) Then
				FilterByRowsAvailable = True;
				Break;
			EndIf;
		EndDo;
	EndDo;
	
	TabularSectionsToChange = New Map;
	For Each TabularSection In ObjectTabularSections Do
		AttributesToChange = New Array;
		For Each Attribute In ThisObject[TabularSection.Value] Do
			If Attribute.Change Then
				AttributesToChange.Add(Attribute.Presentation);
			EndIf;
		EndDo;
		If AttributesToChange.Count() > 0 Then 
			TabularSectionsToChange.Insert(TabularSection.Presentation, AttributesToChange);
		EndIf;
	EndDo;
	
	AttributesToChange = New Array;
	For Each Attribute In ObjectAttributes Do
		If Attribute.Change Then
			AttributesToChange.Add(Attribute.Presentation);
		EndIf;
	EndDo;
	
	Note = "";
	If AttributesToChange.Count() > 3 Then
		Note = "(" + AttributesToChange.Count() +")";
	Else
		For Each Attribute In AttributesToChange Do
			If Not IsBlankString(Note) Then
				Note = Note + ", ";
			EndIf;
			Note = Note + """" + Attribute + """";
		EndDo;
	EndIf;
	
	If AttributesToChange.Count() = 1 Then
		Note = NStr("ru = 'реквизит'; en = 'attribute'; pl = 'atrybut';es_ES = 'atributo';es_CO = 'atributo';tr = 'öznitelik';it = 'attributo';de = 'attribut'") + " " + Note;
	ElsIf AttributesToChange.Count() > 1 Then
		Note = NStr("ru = 'реквизиты'; en = 'attributes'; pl = 'dane firmy';es_ES = 'atributos';es_CO = 'atributos';tr = 'öznitelikler';it = 'attributi';de = 'Requisiten'") + " " + Note;
	EndIf;
	
	If Not IsBlankString(Note) Then
		Note = Note + " " + NStr("ru = 'в выбранных элементах'; en = 'in the selected items'; pl = 'w wybranych pozycjach';es_ES = 'en los elementos seleccionados';es_CO = 'en los elementos seleccionados';tr = 'seçilmiş öğelerde';it = 'negli elementi selezionati';de = 'in den ausgewählten Elementen'");
	EndIf;
	
	For Each TabularSection In TabularSectionsToChange Do
		AttributesToChange = TabularSection.Value;
		If AttributesToChange.Count() > 3 Then
			If Not IsBlankString(Note) Then
				Note = Note + ", ";
			EndIf;
			Note = Note + SubstituteParametersToString(NStr("ru = 'реквизиты (%1)'; en = 'attributes (%1)'; pl = 'szczegóły (%1)';es_ES = 'requisitos (%1)';es_CO = 'requisitos (%1)';tr = 'özellikler (%1)';it = 'attributi (%1)';de = 'Requisiten (%1)'"), AttributesToChange.Count());
		Else
			For Each Attribute In AttributesToChange Do
				If Not IsBlankString(Note) Then
					Note = Note + ", ";
				EndIf;
				If AttributesToChange.Find(Attribute) = 0 Then
					If AttributesToChange.Count() = 1 Then
						Note = Note + NStr("ru = 'реквизит'; en = 'attribute'; pl = 'atrybut';es_ES = 'atributo';es_CO = 'atributo';tr = 'öznitelik';it = 'attributo';de = 'attribut'") + " ";
					ElsIf AttributesToChange.Count() > 1 Then
						Note =  Note + NStr("ru = 'реквизиты'; en = 'attributes'; pl = 'dane firmy';es_ES = 'atributos';es_CO = 'atributos';tr = 'öznitelikler';it = 'attributi';de = 'Requisiten'") + " ";
					EndIf;
				EndIf;
				Note = Note + """" + Attribute + """";
			EndDo;
		EndIf;
		Note = Note + " " 
			+ SubstituteParametersToString(NStr("ru = 'в табличной части ""%1""'; en = 'in the ""%1"" tabular section'; pl = 'w części tabelarycznej ""%1""';es_ES = 'en la parte de tabla ""%1""';es_CO = 'en la parte de tabla ""%1""';tr = '""%1"" tablo bölümünde';it = 'nella sezione tabellare ""%1""';de = 'im tabellarischen Teil ""%1""'"), TabularSection.Key);
	EndDo;
	
	If Not IsBlankString(Note) Then
		If TabularSectionsToChange.Count() > 0 Then
			If FilterByRowsAvailable Then 
				Note = Note + " " + NStr("ru = 'в тех строках выбранных элементов, которые удовлетворяют условиям отбора'; en = 'in the lines of the selected items that satisfy the filter conditions'; pl = 'w tych wierszach wybranych pozycji, które spełniają warunki selekcji';es_ES = 'en las líneas de los elementos seleccionados que cumplen las condiciones de la selección';es_CO = 'en las líneas de los elementos seleccionados que cumplen las condiciones de la selección';tr = 'filtre koşullarını karşılayan seçilmiş öğelerin satırlarında';it = 'nelle linee degli elementi selezionati che soddisfano le condizioni di filtro';de = 'in den Zeilen der ausgewählten Elemente, die den Auswahlbedingungen entsprechen'")
			Else
				Note = Note + " " + NStr("ru = '<b>во всех строках</b> выбранных элементов'; en = '<b>in all lines</b> of the selected items'; pl = '<b>we wszystkich wierszach</b> wybranych elementów';es_ES = '<b>en todas las líneas</b> de los elementos seleccionados';es_CO = '<b>en todas las líneas</b> de los elementos seleccionados';tr = '<b>seçilmiş </b>öğelerin tüm satırlarında';it = '<b>in tutte le linee</b> degli elementi selezionati';de = '<b>in allen Zeilen der</b> ausgewählten Elemente'")
			EndIf;
		EndIf;
	EndIf;
	
	If SelectedObjectsAvailable() Then
		If Not IsBlankString(Note) Then
			Note = NStr("ru = 'Изменить'; en = 'Change'; pl = 'Zmień';es_ES = 'Cambiar';es_CO = 'Cambiar';tr = 'Değiştir';it = 'Modifica';de = 'Ändern'") + " " + Note + ".";
		Else
			Note = NStr("ru = 'Выполнить <b>перезапись</b> выбранных элементов.'; en = '<b>Rewrite</b> the selected items.'; pl = 'Wykonaj <b> ponowne zapisywanie </b> wybranych elementów.';es_ES = 'Realizar <b>la regrabación</b> de los elementos guardados.';es_CO = 'Realizar <b>la regrabación</b> de los elementos guardados.';tr = '<b>Seçilmiş öğeler</b>yeniden yazılsın.';it = '<b>Riscrivi</b> gli elementi selezionati.';de = '<b>Überschreibe</b> Sie die ausgewählten Elemente.'");
		EndIf;
	Else
		Note = NStr("ru = 'Не выбраны элементы, реквизиты которых необходимо изменить.'; en = 'Items which attributes shall be changed are not selected.'; pl = 'Elementy, których atrybuty zostaną zmienione, nie są wybierane.';es_ES = 'Artículos cuyos atributos tienen que cambiarse, no se han seleccionado.';es_CO = 'Artículos cuyos atributos tienen que cambiarse, no se han seleccionado.';tr = 'Niteliklerin değiştirileceği öğeler seçilmez.';it = 'Gli elementi i cui attributi dovrebbero essere cambiati, non sono selezionati.';de = 'Elemente, deren Attribute geändert werden sollen, werden nicht ausgewählt.'");
	EndIf;
	
	Items.NoteOnConfiguredChanges.Title = FormattedString(Note);
	
	If IsBlankString(AlgorithmCode) Then
		AlgorithmCode = "// Available variables:
		|// Object - object being processed" + Chars.LF;
	EndIf;
	
EndProcedure

&AtServer
Function SelectedObjectsAvailable()
	FilterSettings = FilterSettings();
	FilterSettings.RestrictSelection = True;
	Return SelectedObjects(FilterSettings).Rows.Count() > 0;
EndFunction

&AtServer
Procedure UpdateSelectedCountLabel()
	
	If AvailableConfiguredFilters() Then
		ErrorMessageText = "";
		SelectedObjectsCount = SelectedObjectsCount(True, , ErrorMessageText);
		LabelText = StringWithNumberForAnyLanguage(NStr("ru = ';%1 элемент;;%1 элемента;%1 элементов;%1 элемента'; en = ';%1 item;;%1 items;%1 items;%1 items'; pl = ';%1 element;;%1 elementu;%1 elementów;%1 elementu';es_ES = ';%1 elemento;;%1 del elemento;%1 de los elementos;%1 del elemento';es_CO = ';%1 elemento;;%1 del elemento;%1 de los elementos;%1 del elemento';tr = ';%1 öğe;;%1 öğe;%1 öğe;%1 öğe';it = ',%1 elemento;;%1 elementi,%1 elementi,%1 elementi';de = ';%1 Element;;%1 Elemente;%1 Elemente;%1 Elemente'"),
			SelectedObjectsCount);
	Else
		LabelText = NStr("ru = 'Все элементы'; en = 'All items'; pl = 'Wszystkie elementy';es_ES = 'Todos los artículos';es_CO = 'Todos los artículos';tr = 'Tüm öğeler';it = 'Tutti gli elementi';de = 'Alle Elemente'");
	EndIf;
	
	Items.FilterSettings.Title = LabelText;
EndProcedure

&AtServer
Procedure FillPreviouslyChangedAttributesSubmenu()
	
	CommandLocation = Items.PreviouslyChangedAttributes;
	
	ItemsToRemove = New Array;
	For Each Setting In CommandLocation.ChildItems Do
		If Setting.Name = "Stub" Then
			Continue;
		EndIf;
		ItemsToRemove.Add(Setting);
	EndDo;
	
	For Each Setting In ItemsToRemove Do
		Commands.Delete(Commands[Setting.Name]);
		Items.Delete(Setting);
	EndDo;
	
	For Each Setting In OperationsHistoryList Do
		CommandNumber = OperationsHistoryList.IndexOf(Setting);
		CommandName = CommandLocation.Name + "ChangesSetting" + CommandNumber;
		
		FormCommand = Commands.Add(CommandName);
		FormCommand.Action = "Attachable_EnableSetting";
		FormCommand.Title = Setting.Presentation;
		FormCommand.ModifiesStoredData = False;
		
		NewItem = Items.Add(CommandName, Type("FormButton"), CommandLocation);
		NewItem.Type = FormButtonType.CommandBarButton;
		NewItem.CommandName = CommandName;
	EndDo;
	
	Items.Stub.Visible = OperationsHistoryList.Count() = 0;
	
	If Not ContextCall Then
		FillAlgorithmsListSubmenu();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAlgorithmsListSubmenu()
	CommandLocation = Items.Algorithms;
	
	ItemsToRemove = New Array;
	For Each Setting In CommandLocation.ChildItems Do
		If Setting.Name = "StubAlgorythms" Then
			Continue;
		EndIf;
		ItemsToRemove.Add(Setting);
	EndDo;
	
	For Each Setting In ItemsToRemove Do
		Commands.Delete(Commands[Setting.Name]);
		Items.Delete(Setting);
	EndDo;
	
	For Each Setting In AlgorithmsHistoryList Do
		CommandNumber = AlgorithmsHistoryList.IndexOf(Setting);
		CommandName = CommandLocation.Name + "ChangesSetting" + CommandNumber;
		
		FormCommand = Commands.Add(CommandName);
		FormCommand.Action = "Attachable_EnableSetting";
		FormCommand.Title = Setting.Presentation;
		FormCommand.ModifiesStoredData = False;
		
		NewItem = Items.Add(CommandName, Type("FormButton"), CommandLocation);
		NewItem.Type = FormButtonType.CommandBarButton;
		NewItem.CommandName = CommandName;
	EndDo;
	
	Items.StubAlgorythms.Visible = AlgorithmsHistoryList.Count() = 0;
EndProcedure

&AtClient
Procedure SetChangeSetting(Val Setting)
	
	ResetChangeSettings();
	
	LockedAttributesAvailable = False;
	
	// For backward compatibility with settings saved in SSL 2.1.
	If TypeOf(Setting) <> Type("Structure") Then
		Setting = New Structure("Attributes,TabularSections", Setting, New Structure);
	EndIf;
	
	For Each AttributeToChange In Setting.Attributes Do
		SearchStructure = New Structure;
		SearchStructure.Insert("OperationKind", AttributeToChange.OperationKind);
		If AttributeToChange.OperationKind = 1 Then // Object attribute
			SearchStructure.Insert("Name", AttributeToChange.AttributeName);
		Else
			SearchStructure.Insert("Property", AttributeToChange.Property);
		EndIf;
		
		FoundRows = ObjectAttributes.FindRows(SearchStructure);
		If FoundRows.Count() > 0 Then
			If FoundRows[0].LockedAttribute  Then
				LockedAttributesAvailable = True;
				Continue;
			EndIf;
			FoundRows[0].Value = AttributeToChange.Value;
			FoundRows[0].Change = True;
		EndIf;
	EndDo;
	
	For Each TabularSection In Setting.TabularSections Do
		For Each AttributeToChange In TabularSection.Value Do
			SearchStructure = New Structure;
			SearchStructure.Insert("Name", AttributeToChange.Name);
			If Items.Find("TabularSection" + TabularSection.Key) <> Undefined Then
				FoundRows = ThisObject["TabularSection" + TabularSection.Key].FindRows(SearchStructure);
				If FoundRows.Count() > 0 Then
					FoundRows[0].Value = AttributeToChange.Value;
					FoundRows[0].Change = True;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	If LockedAttributesAvailable Then
		ShowMessageBox(, NStr("ru = 'Некоторые реквизиты заблокированы для изменения, изменения не установлены.'; en = 'Some attributes are locked for editing. Changes were not defined.'; pl = 'Niektóre rekwizyty są zablokowane do edycji. Zmiany nie zostały zdefiniowane.';es_ES = 'Algunos atributos están bloqueados para edición. Cambios no se han definido.';es_CO = 'Algunos atributos están bloqueados para edición. Cambios no se han definido.';tr = 'Bazı özellikler düzenleme için kilitlenmiştir. Değişiklikler tanımlanmamıştır.';it = 'Alcuni attributi sono bloccati per la modifica. Le modifiche non sono state definite.';de = 'Einige Attribute sind zur Bearbeitung gesperrt. Änderungen wurden nicht definiert.'"));
	EndIf;
	
	UpdateCountersOfAttributesToChange();
EndProcedure

&AtServer
Function ChoiceParametersAsString(ChoiceParameters)
	Result = "";
	
	For Each ChoiceParameterDescription In ChoiceParameters Do
		CurrentCPString = "[FilterField];[StringType];[StringValue]";
		ValueType = TypeOf(ChoiceParameterDescription.Value);
		
		If ValueType = Type("FixedArray") Then
			TypePresentationString = "FixedArray";
			StringValue = "";
			
			For Each Item In ChoiceParameterDescription.Value Do
				ValueStringPattern = "[Type]*[Value]";
				ValueStringPattern = StrReplace(ValueStringPattern, "[Type]", TypePresentationString(TypeOf(Item)));
				ValueStringPattern = StrReplace(ValueStringPattern, "[Value]", XMLString(Item));
				StringValue = StringValue + ?(IsBlankString(StringValue), "", "#") + ValueStringPattern;
			EndDo;
		Else
			TypePresentationString = TypePresentationString(ValueType);
			StringValue = XMLString(ChoiceParameterDescription.Value);
		EndIf;
		
		If Not IsBlankString(StringValue) Then
			CurrentCPString = StrReplace(CurrentCPString, "[FilterField]", ChoiceParameterDescription.Name);
			CurrentCPString = StrReplace(CurrentCPString, "[StringType]", TypePresentationString);
			CurrentCPString = StrReplace(CurrentCPString, "[StringValue]", StringValue);
			
			Result = Result + CurrentCPString + Chars.LF;
		EndIf;
	EndDo;
	
	Result = Left(Result, StrLen(Result)-1);
	Return Result;
EndFunction

&AtServer
Function ChoiceParameterLinksAsString(ChoiceParameterLinks)
	Result = "";
	
	For Each ChoiceParameterLinkDescription In ChoiceParameterLinks Do
		CurrentCPLString = "[ParameterName];[AttributeName]";
		CurrentCPLString = StrReplace(CurrentCPLString, "[ParameterName]", ChoiceParameterLinkDescription.Name);
		CurrentCPLString = StrReplace(CurrentCPLString, "[AttributeName]", ChoiceParameterLinkDescription.DataPath);
		Result = Result + CurrentCPLString + Chars.LF;
	EndDo;
	
	Result = Left(Result, StrLen(Result)-1);
	Return Result;
EndFunction

&AtServer
Function ChoiceParameterLinksPresentation(ChoiceParameterLinks, MetadataObject)
	Result = "";
	
	LinkedAttributes = New Array;
	For Each ChoiceParameterLinkDescription In ChoiceParameterLinks Do
		AttributeName = ChoiceParameterLinkDescription.DataPath;
		TabularSectionPresentation = "";
		AttributesOwner = MetadataObject;
		NameParts = StrSplit(AttributeName, ".", True);
		If NameParts.Count() = 2 Then
			AttributeName = NameParts[1];
			TabularSectionName = NameParts[0];
			AttributesOwner = MetadataObject.TabularSections.Find(TabularSectionName);
			If AttributesOwner <> Undefined Then
				TabularSectionPresentation = AttributesOwner.Presentation();
			EndIf;
		EndIf;
		If AttributesOwner <> Undefined Then
			Attribute = AttributesOwner.Attributes.Find(AttributeName);
			If Attribute <> Undefined Then
				AttributePresentation = Attribute.Presentation();
				If Not IsBlankString(TabularSectionPresentation) Then
					AttributePresentation = AttributePresentation + " (" + NStr("ru = 'таблица'; en = 'table'; pl = 'tabela';es_ES = 'tabla';es_CO = 'tabla';tr = 'Tablo';it = 'tabella';de = 'tabelle'") + " " 
						+ TabularSectionPresentation + ")";
				EndIf;
				LinkedAttributes.Add(AttributePresentation);
			EndIf;
		EndIf;
	EndDo;
	
	If LinkedAttributes.Count() > 0 Then
		LinkPresentationPattern = NStr("ru = 'Зависит от реквизитов: %1.'; en = 'Depends on the %1 attributes.'; pl = 'Zależy od szczegółów: %1.';es_ES = 'Depende de los requisitos: %1.';es_CO = 'Depende de los requisitos: %1.';tr = 'Özelliklere bağlı: %1.';it = 'Dipende dagli attributi %1.';de = 'Hängt von den Requisiten ab: %1.'");
		If LinkedAttributes.Count() = 1 Then
			LinkPresentationPattern = NStr("ru = 'Зависит от реквизита %1.'; en = 'Depends on the %1 attribute.'; pl = 'Zależy od szczegółu %1.';es_ES = 'Depende del requisito %1.';es_CO = 'Depende del requisito %1.';tr = 'Özelliğe bağlı %1.';it = 'Dipende dall''attributo %1.';de = 'Hängt von dem Requisit ab: %1.'");
		EndIf;
		Result = SubstituteParametersToString(LinkPresentationPattern, StrConcat(LinkedAttributes, ", "));
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Procedure FillObjectsTypesList()
	DataProcessorObject = FormAttributeToValue("Object");
	DataProcessorObject.FillEditableObjectsCollection(
		Items.PresentationOfObjectsToChange.ChoiceList, Object.ShowInternalAttributes);
EndProcedure

&AtClient
Procedure NoteOnConfiguredChangesURLProcessing(Item, FormattedStringURL, StandardProcessing)
	If FormattedStringURL = "GoToFilterSettings" Then
		StandardProcessing = False;
		GoToFilterSettings();
	EndIf;
EndProcedure

&AtClient
Procedure GoToFilterSettings()
	If Not IsBlankString(KindsOfObjectsToChange) Then
		NotifyDescription = New NotifyDescription("OnCloseSelectedObjectsForm", ThisObject);
		OpenForm(FullFormName("SelectedItems"), 
		New Structure("SelectedTypes, Settings", KindsOfObjectsToChange, SettingsComposer.Settings), , , , , NotifyDescription);
	EndIf;
EndProcedure

&AtClient
Function ComposerParameters(Formula)
	Result = New Structure;
	Result.Insert("Formula", Formula);
	Result.Insert("OperandsTitle", NStr("ru = 'Доступные реквизиты'; en = 'Available attributes'; pl = 'Dostępne atrybuty';es_ES = 'Requisitos disponibles';es_CO = 'Requisitos disponibles';tr = 'Mevcut özellikler';it = 'Attributi disponibili';de = 'Verfügbare Requisiten'"));
	Result.Insert("Operands", Operands());
	Result.Insert("Advanced", False);
	Return Result;
EndFunction

&AtServer
Function Operands()
	OperandsTable = New ValueTable;
	OperandsTable.Columns.Add("ID");
	OperandsTable.Columns.Add("Presentation");
	
	For Each AttributeDetails In ObjectAttributes Do
		Operand = OperandsTable.Add();
		Operand.ID = AttributeDetails.Presentation;
	EndDo;
	
	Return PutToTempStorage(OperandsTable, UUID);
EndFunction

&AtClient
Function ExpressionHasErrors(Val Expression, ErrorText = "")
	
	Expression = Mid(Expression, 2);
	
	For Each AttributeDetails In ObjectAttributes Do
		Expression = StrReplace(Expression, "[" + AttributeDetails.Presentation + "]", """1""");
	EndDo;
	
	Try
		Return Eval(Expression) = Undefined;
	Except
		ErrorText = BriefErrorDescription(ErrorInfo());
		Return True;
	EndTry;
	
EndFunction

&AtServer
Procedure FindUnlockAttributesForm()
	UnlockAttributesFormAvailable = False;
	FullNameOfUnlockAttributesForm = "";
	KindsOfObjectsToChangeList = StrSplit(KindsOfObjectsToChange, ",", False);
	If KindsOfObjectsToChangeList.Count() = 1 Then
		ObjectMetadata = Metadata.FindByFullName(KindsOfObjectsToChangeList[0]);
		If EditProhibitionIntegrated AND ObjectAttributes.FindRows(New Structure("LockedAttribute", True)).Count() > 0 Then
			MetadataObjectForm = ObjectMetadata.Forms.Find("AttributeUnlocking");
			If MetadataObjectForm <> Undefined Then
				UnlockAttributesFormAvailable = True;
				FullNameOfUnlockAttributesForm = MetadataObjectForm.FullName();
			EndIf;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure OnUnlockAttributes(UnlockedAttributes, AdditionalParameters) Export
	If UnlockedAttributes = Undefined Then
		Return;
	EndIf;
	
	If TypeOf(UnlockedAttributes) = Type("Array") AND UnlockedAttributes.Count() > 0 Then
		LockedAttributesRows = ObjectAttributes.FindRows(New Structure("LockedAttribute", True));
		For Each OperationDescriptionString In LockedAttributesRows Do
			If OperationDescriptionString.LockedAttribute AND UnlockedAttributes.Find(OperationDescriptionString.Name) <> Undefined Then
				OperationDescriptionString.LockedAttribute = False;
			EndIf;
		EndDo;
	EndIf;
EndProcedure

&AtClient
Procedure SaveSettings()
	SaveDataProcessorSettings(
			"",
			Object.ChangeInTransaction,
			Object.InterruptOnError,
			TransactionalBatchSetting,
			TransactionalPercentageOfObjectsInBatch,
			TransactionalNumberOfObjectsInBatch,
			ProcessRecursively);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Base-functionality procedures and functions for standalone operation support.

// Saves a setting to the common settings storage.
// 
// Parameters:
//   As for the CommonSettingsStorageSave.Save method, see StorageSave() parameters.
//   
// 
&AtServerNoContext
Procedure CommonSettingsStorageSave(ObjectKey, SettingsKey, Value,
	SettingsDetails = Undefined, Username = Undefined, 
	NeedToRefreshCachedValues = False)
	
	StorageSave(
		CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		Value,
		SettingsDetails,
		Username,
		NeedToRefreshCachedValues);
	
EndProcedure

// Loads settings from the common settings storage.
//
// Parameters:
//   As for the CommonSettingsStorage.Loadmethod, see StorageLoad() parameters.
//   
//
&AtServerNoContext
Function CommonSettingsStorageLoad(ObjectKey, SettingsKey, DefaultValue = Undefined, 
	SettingsDetails = Undefined, Username = Undefined)
	
	Return StorageLoad(
		CommonSettingsStorage,
		ObjectKey,
		SettingsKey,
		DefaultValue,
		SettingsDetails,
		Username);
	
EndFunction

&AtServerNoContext
Procedure StorageSave(StorageManager, ObjectKey, SettingsKey, Value,
	SettingsDetails, Username, NeedToRefreshCachedValues)
	
	If NOT AccessRight("SaveUserData", Metadata) Then
		Return;
	EndIf;
	
	StorageManager.Save(ObjectKey, SettingsKey(SettingsKey), Value, SettingsDetails, Username);
	
	If NeedToRefreshCachedValues Then
		RefreshReusableValues();
	EndIf;
	
EndProcedure

&AtServerNoContext
Function StorageLoad(StorageManager, ObjectKey, SettingsKey, DefaultValue,
	SettingsDetails, Username)
	
	Result = Undefined;
	
	If AccessRight("SaveUserData", Metadata) Then
		Result = StorageManager.Load(ObjectKey, SettingsKey(SettingsKey), SettingsDetails, Username);
	EndIf;
	
	If (Result = Undefined) AND (DefaultValue <> Undefined) Then
		Result = DefaultValue;
	EndIf;

	Return Result;
	
EndFunction

// Returns a settings key string within a valid length.
// Checks the length of the passed string. If it exceeds 128, converts its end according to the MD5 
// algorithm into a short alternative. As the result, string becomes 128 character length.
// If the original string is less then 128 characters, it is returned as is.
//
// Parameters:
//  String - String -  string of any number of characters.
//
&AtServerNoContext
Function SettingsKey(Val Row)
	Result = Row;
	If StrLen(Row) > 128 Then // A key longer than 128 characters raises an exception when accessing the settings storage.
		Result = Left(Row, 96);
		DataHashing = New DataHashing(HashFunction.MD5);
		DataHashing.Append(Mid(Row, 97));
		Result = Result + StrReplace(DataHashing.HashSum, " ", "");
	EndIf;
	Return Result;
EndFunction

// Returns an object manager by the passed full name of a metadata object.
//
// Does not regard business process route points.
//
// Parameters:
//  FullName    - String - full name of the metadata object, e.g. "Catalog.Companies".
//                 
//
// Returns:
//  CatalogManager, DocumentManager, etc.
// 
&AtServerNoContext
Function ObjectManagerByFullName(FullName)
	Var MOClass, MetadataObjectName, Manager;
	
	NameParts = StrSplit(FullName, ".");
	
	If NameParts.Count() = 2 Then
		MOClass = NameParts[0];
		MetadataObjectName  = NameParts[1];
	EndIf;
	
	If      Upper(MOClass) = "EXCHANGEPLAN" Then
		Manager = ExchangePlans;
		
	ElsIf Upper(MOClass) = "CATALOG" Then
		Manager = Catalogs;
		
	ElsIf Upper(MOClass) = "DOCUMENT" Then
		Manager = Documents;
		
	ElsIf Upper(MOClass) = "DOCUMENTJOURNAL" Then
		Manager = DocumentJournals;
		
	ElsIf Upper(MOClass) = "ENUM" Then
		Manager = Enums;
		
	ElsIf Upper(MOClass) = "REPORT" Then
		Manager = Reports;
		
	ElsIf Upper(MOClass) = "DATAPROCESSOR" Then
		Manager = DataProcessors;
		
	ElsIf Upper(MOClass) = "CHARTOFCHARACTERISTICTYPES" Then
		Manager = ChartsOfCharacteristicTypes;
		
	ElsIf Upper(MOClass) = "CHARTOFACCOUNTS" Then
		Manager = ChartsOfAccounts;
		
	ElsIf Upper(MOClass) = "CHARTOFCALCULATIONTYPES" Then
		Manager = ChartsOfCalculationTypes;
		
	ElsIf Upper(MOClass) = "INFORMATIONREGISTER" Then
		Manager = InformationRegisters;
		
	ElsIf Upper(MOClass) = "ACCUMULATIONREGISTER" Then
		Manager = AccumulationRegisters;
		
	ElsIf Upper(MOClass) = "ACCOUNTINGREGISTER" Then
		Manager = AccountingRegisters;
		
	ElsIf Upper(MOClass) = "CALCULATIONREGISTER" Then
		If NameParts.Count() = 2 Then
			// Calculation register
			Manager = CalculationRegisters;
		Else
			SubordinateMOClass = NameParts[2];
			If Upper(SubordinateMOClass) = "RECALCULATION" Then
				// Recalculation
				Manager = CalculationRegisters[MetadataObjectName].Recalculations;
			Else
				Raise SubstituteParametersToString(NStr("ru = 'Неизвестный тип объекта метаданных ""%1""'; en = 'Unknown metadata object type: ""%1""'; pl = 'Nieznany typ obiektu metadanych %1';es_ES = 'Tipo del objeto de metadatos desconocido ""%1""';es_CO = 'Tipo del objeto de metadatos desconocido ""%1""';tr = 'Bilinmeyen meta veri nesne türü ""%1""';it = 'Tipo di oggetto metadati sconosciuto: ""%1""';de = 'Unbekannter Metadaten-Objekttyp ""%1""'"), FullName);
			EndIf;
		EndIf;
		
	ElsIf Upper(MOClass) = "BUSINESSPROCESS" Then
		Manager = BusinessProcesses;
		
	ElsIf Upper(MOClass) = "TASK" Then
		Manager = Tasks;
		
	ElsIf Upper(MOClass) = "CONSTANT" Then
		Manager = Constants;
		
	ElsIf Upper(MOClass) = "SEQUENCE" Then
		Manager = Sequences;
	EndIf;
	
	If Manager <> Undefined Then
		Try
			Return Manager[MetadataObjectName];
		Except
			Manager = Undefined;
		EndTry;
	EndIf;
	
	Raise SubstituteParametersToString(NStr("ru = 'Неизвестный тип объекта метаданных ""%1""'; en = 'Unknown metadata object type: ""%1""'; pl = 'Nieznany typ obiektu metadanych %1';es_ES = 'Tipo del objeto de metadatos desconocido ""%1""';es_CO = 'Tipo del objeto de metadatos desconocido ""%1""';tr = 'Bilinmeyen meta veri nesne türü ""%1""';it = 'Tipo di oggetto metadati sconosciuto: ""%1""';de = 'Unbekannter Metadaten-Objekttyp ""%1""'"), FullName);
	
EndFunction

&AtClientAtServerNoContext
Function SubstituteParametersToString(Val SubstitutionString,
	Val Parameter1, Val Parameter2 = Undefined, Val Parameter3 = Undefined)
	
	SubstitutionString = StrReplace(SubstitutionString, "%1", Parameter1);
	SubstitutionString = StrReplace(SubstitutionString, "%2", Parameter2);
	SubstitutionString = StrReplace(SubstitutionString, "%3", Parameter3);
	
	Return SubstitutionString;
EndFunction

// Returns the name of a kind for a referenced metadata object.
// 
//
// Does not regard business process route points.
//
// Parameters:
//  Reference       - reference to an object - catalog item, document, etc.
//
// Returns:
//  String       - a metadata object kind name, for example, "Catalog" or "Document".
// 
&AtServerNoContext
Function ObjectKindByRef(Ref)
	
	Return ObjectKindByType(TypeOf(Ref));
	
EndFunction 

// Returns the name of a kind for a metadata object of a specific type.
//
// Does not regard business process route points.
//
// Parameters:
//  Type - an applied object type defined in the configuration.
//
// Returns:
//  String       - a metadata object kind name, for example, "Catalog" or "Document".
// 
&AtServerNoContext
Function ObjectKindByType(Type)
	
	If Catalogs.AllRefsType().ContainsType(Type) Then
		Return "Catalog";
	
	ElsIf Documents.AllRefsType().ContainsType(Type) Then
		Return "Document";
	
	ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
		Return "BusinessProcess";
	
	ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCharacteristicTypes";
	
	ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
		Return "ChartOfAccounts";
	
	ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
		Return "ChartOfCalculationTypes";
	
	ElsIf Tasks.AllRefsType().ContainsType(Type) Then
		Return "Task";
	
	ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
		Return "ExchangePlan";
	
	ElsIf Enums.AllRefsType().ContainsType(Type) Then
		Return "Enum";
	
	Else
		Raise SubstituteParametersToString(NStr("ru='Неверный тип значения параметра (%1)'; en = 'Invalid parameter value type (%1)'; pl = 'Nieprawidłowy typ wartości parametru (%1)';es_ES = 'Tipo incorrecto del valor del parámetro (%1)';es_CO = 'Tipo incorrecto del valor del parámetro (%1)';tr = 'Parametre değeri tipi yanlış (%1)';it = 'Tipo di valore parametro non valido (%1)';de = 'Falscher Typ des Parameterwerts (%1)'"), String(Type));
	
	EndIf;
	
EndFunction 

// Checks whether the object is an item group.
//
// Parameters:
//  Object       - Object, Reference, FormDataStructure for the Object type.
//
// Returns:
//  Boolean.
//
&AtServerNoContext
Function ObjectIsFolder(Object)
	
	If RefTypeValue(Object) Then
		Ref = Object;
	Else
		Ref = Object.Ref;
	EndIf;
	
	ObjectMetadata = Ref.Metadata();
	
	If IsCatalog(ObjectMetadata) Then
		
		If NOT ObjectMetadata.Hierarchical
		 OR ObjectMetadata.HierarchyType
		     <> Metadata.ObjectProperties.HierarchyType.HierarchyFoldersAndItems Then
			
			Return False;
		EndIf;
		
	ElsIf NOT IsChartOfCharacteristicTypes(ObjectMetadata) Then
		Return False;
		
	ElsIf NOT ObjectMetadata.Hierarchical Then
		Return False;
	EndIf;
	
	If Ref <> Object Then
		Return Object.IsFolder;
	EndIf;
	
	Return ObjectAttributeValue(Ref, "IsFolder");
	
EndFunction

// Checks whether the metadata object belongs to the Catalog common type.
//
// Parameters:
//  MetadataObject - metadata object to be checked for having a specific type.
// 
//  Returns:
//   Boolean.
//
&AtServerNoContext
Function IsCatalog(MetadataObject)
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = CatalogsTypeName();
	
EndFunction

// Checking whether it's a reference data type.
//
&AtServerNoContext
Function IsReference(Type)
	
	Return Type <> Type("Undefined") 
		AND (Catalogs.AllRefsType().ContainsType(Type)
		OR Documents.AllRefsType().ContainsType(Type)
		OR Enums.AllRefsType().ContainsType(Type)
		OR ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type)
		OR ChartsOfAccounts.AllRefsType().ContainsType(Type)
		OR ChartsOfCalculationTypes.AllRefsType().ContainsType(Type)
		OR BusinessProcesses.AllRefsType().ContainsType(Type)
		OR BusinessProcesses.RoutePointsAllRefsType().ContainsType(Type)
		OR Tasks.AllRefsType().ContainsType(Type)
		OR ExchangePlans.AllRefsType().ContainsType(Type));
	
EndFunction

// Checks whether the value is a reference type value.
//
// Parameters:
//  Value       - Object reference - catalog item, document, etc.
//
// Returns:
//  Boolean - True if the value is a reference type value.
//
&AtServerNoContext
Function RefTypeValue(Value)
	
	If Value = Undefined Then
		Return False;
	EndIf;
	
	If Catalogs.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Documents.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Enums.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCharacteristicTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfAccounts.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ChartsOfCalculationTypes.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If BusinessProcesses.RoutePointsAllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If Tasks.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	If ExchangePlans.AllRefsType().ContainsType(TypeOf(Value)) Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Checks whether the metadata object belongs to the Chart of Characteristic Types common type.
//
// Parameters:
//  MetadataObject - metadata object to be checked for having a specific type.
// 
//  Returns:
//   Boolean.
//
&AtServerNoContext
Function IsChartOfCharacteristicTypes(MetadataObject)
	
	Return BaseTypeNameByMetadataObject(MetadataObject) = ChartsOfCharacteristicTypesTypeName();
	
EndFunction

// Returns a base type name by the passed metadata object value.
//
// Parameters:
//  MetadataObject - metadata object to use for identifying the base type.
// 
// Returns:
//  String - name of the base type for the passed metadata object value.
//
&AtServerNoContext
Function BaseTypeNameByMetadataObject(MetadataObject)
	
	If Metadata.Documents.Contains(MetadataObject) Then
		Return DocumentsTypeName();
		
	ElsIf Metadata.Catalogs.Contains(MetadataObject) Then
		Return CatalogsTypeName();
		
	ElsIf Metadata.Enums.Contains(MetadataObject) Then
		Return EnumsTypeName();
		
	ElsIf Metadata.InformationRegisters.Contains(MetadataObject) Then
		Return InformationRegistersTypeName();
		
	ElsIf Metadata.AccumulationRegisters.Contains(MetadataObject) Then
		Return AccumulationRegistersTypeName();
		
	ElsIf Metadata.AccountingRegisters.Contains(MetadataObject) Then
		Return AccountingRegistersTypeName();
		
	ElsIf Metadata.CalculationRegisters.Contains(MetadataObject) Then
		Return CalculationRegistersTypeName();
		
	ElsIf Metadata.ExchangePlans.Contains(MetadataObject) Then
		Return ExchangePlansTypeName();
		
	ElsIf Metadata.ChartsOfCharacteristicTypes.Contains(MetadataObject) Then
		Return ChartsOfCharacteristicTypesTypeName();
		
	ElsIf Metadata.BusinessProcesses.Contains(MetadataObject) Then
		Return BusinessProcessesTypeName();
		
	ElsIf Metadata.Tasks.Contains(MetadataObject) Then
		Return TasksTypeName();
		
	ElsIf Metadata.ChartsOfAccounts.Contains(MetadataObject) Then
		Return ChartsOfAccountsTypeName();
		
	ElsIf Metadata.ChartsOfCalculationTypes.Contains(MetadataObject) Then
		Return ChartsOfCalculationTypesTypeName();
		
	ElsIf Metadata.Constants.Contains(MetadataObject) Then
		Return ConstantsTypeName();
		
	ElsIf Metadata.DocumentJournals.Contains(MetadataObject) Then
		Return DocumentJournalsTypeName();
		
	ElsIf Metadata.Sequences.Contains(MetadataObject) Then
		Return SequencesTypeName();
		
	ElsIf Metadata.ScheduledJobs.Contains(MetadataObject) Then
		Return ScheduledJobsTypeName();
		
	Else
		
		Return "";
		
	EndIf;
	
EndFunction

// Returns a value for identification of the Information registers type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function InformationRegistersTypeName()
	
	Return "InformationRegisters";
	
EndFunction

// Returns a value for identification of the Accumulation registers type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function AccumulationRegistersTypeName()
	
	Return "AccumulationRegisters";
	
EndFunction

// Returns a value for identification of the Accounting registers type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function AccountingRegistersTypeName()
	
	Return "AccountingRegisters";
	
EndFunction

// Returns a value for identification of the Calculation registers type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function CalculationRegistersTypeName()
	
	Return "CalculationRegisters";
	
EndFunction

// Returns a value for identification of the Documents type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function DocumentsTypeName()
	
	Return "Documents";
	
EndFunction

// Returns a value for identification of the Catalogs type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function CatalogsTypeName()
	
	Return "Catalogs";
	
EndFunction

// Returns a value for identifying the Enumeration data type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function EnumsTypeName()
	
	Return "Enums";
	
EndFunction

// Returns a value for identification of the Exchange plans type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function ExchangePlansTypeName()
	
	Return "ExchangePlans";
	
EndFunction

// Returns a value for identification of the Charts of characteristic types type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function ChartsOfCharacteristicTypesTypeName()
	
	Return "ChartsOfCharacteristicTypes";
	
EndFunction

// Returns a value for identification of the Business processes type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function BusinessProcessesTypeName()
	
	Return "BusinessProcesses";
	
EndFunction

// Returns a value for identification of the Tasks type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function TasksTypeName()
	
	Return "Tasks";
	
EndFunction

// Checks whether the metadata object belongs to the Charts of accounts type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function ChartsOfAccountsTypeName()
	
	Return "ChartsOfAccounts";
	
EndFunction

// Returns a value for identification of the Charts of calculation types type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function ChartsOfCalculationTypesTypeName()
	
	Return "ChartsOfCalculationTypes";
	
EndFunction

// Returns a value for identification of the Constants type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function ConstantsTypeName()
	
	Return "Constants";
	
EndFunction

// Returns a value for identification of the Document journals type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function DocumentJournalsTypeName()
	
	Return "DocumentJournals";
	
EndFunction

// Returns a value for identification of the Sequences type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function SequencesTypeName()
	
	Return "Sequences";
	
EndFunction

// Returns a value for identification of the Scheduled jobs type.
//
// Returns:
//  String.
//
&AtServerNoContext
Function ScheduledJobsTypeName()
	
	Return "ScheduledJobs";
	
EndFunction

// Returns a structure containing attribute values retrieved from the infobase using the object 
// reference.
// 
//  If access to any of the attributes is denied, an exception is raised.
//  To read attribute values regardless of current user rights, enable privileged mode.
//  
// 
// Parameters:
//  Reference       - Reference to an object - catalog item, document, etc.
//
//  Attributes - String - attribute names separated with commas, formatted according to structure 
//              requirements.
//              Example: "Code, Description, Parent".
//            - Structure - FixedStructure - keys are field aliases used for resulting structure 
//              keys, values (optional) are field names. If a value is empty, it is considered equal 
//              to the key.
//              If a value is empty, it is considered equal to the key.
//            - Array - FixedArray - attribute names formatted according to structure property 
//              requirements.
//
// Returns:
//  Structure - contains names (keys) and values of the requested attributes.
//              If the string of the requested attributes is empty, an empty structure is returned.
//
&AtServerNoContext
Function ObjectAttributeValues(Ref, Val Attributes)
	
	If TypeOf(Attributes) = Type("String") Then
		If IsBlankString(Attributes) Then
			Return New Structure;
		EndIf;
		Attributes = StrSplit(Attributes, ",", False);
	EndIf;
	
	AttributesStructure = New Structure;
	If TypeOf(Attributes) = Type("Structure") Or TypeOf(Attributes) = Type("FixedStructure") Then
		AttributesStructure = Attributes;
	ElsIf TypeOf(Attributes) = Type("Array") Or TypeOf(Attributes) = Type("FixedArray") Then
		For Each Attribute In Attributes Do
			AttributesStructure.Insert(StrReplace(Attribute, ".", ""), Attribute);
		EndDo;
	Else
		Raise SubstituteParametersToString(NStr("ru = 'Неверный тип второго параметра Реквизиты: %1'; en = 'Invalid Attributes parameter type: %1'; pl = 'Nieprawidłowy typ parametru Atrybuty: %1';es_ES = 'Tipo del parámetro de Atributos inválido: %1';es_CO = 'Tipo del parámetro de Atributos inválido: %1';tr = 'Geçersiz Özellikler parametresinin türü: %1';it = 'Attributi non valido tipo di parametro: %1';de = 'Ungültiger Parametertyp für Attribute: %1'"), String(TypeOf(Attributes)));
	EndIf;
	
	FieldTexts = "";
	For Each KeyAndValue In AttributesStructure Do
		FieldName   = ?(ValueIsFilled(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Value),
		              TrimAll(KeyAndValue.Key));
		
		Alias = TrimAll(KeyAndValue.Key);
		
		FieldTexts  = FieldTexts + ?(IsBlankString(FieldTexts), "", ",") + "
		|	" + FieldName + " AS " + Alias;
	EndDo;
	
	Query = New Query;
	Query.SetParameter("Ref", Ref);
	Query.Text =
	"SELECT
	|" + FieldTexts + "
	|FROM
	|	" + Ref.Metadata().FullName() + " AS SpecifiedTableAlias
	|WHERE
	|	SpecifiedTableAlias.Ref = &Ref
	|";
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Result = New Structure;
	For Each KeyAndValue In AttributesStructure Do
		Result.Insert(KeyAndValue.Key);
	EndDo;
	FillPropertyValues(Result, Selection);
	
	Return Result;
	
EndFunction

// Returns an attribute value retrieved from the infobase using the object reference.
// 
//  If access to the attribute is denied, an exception is raised.
//  To read attribute values regardless of current user rights, enable privileged mode.
//  
// 
// Parameters:
//  Reference       - reference to an object - catalog item, document, etc.
//  NameAttribute - String - e.g.  "Code".
// 
// Returns:
//  Arbitrary - depends on the type of the read attribute.
// 
&AtServerNoContext
Function ObjectAttributeValue(Ref, AttributeName)
	
	Result = ObjectAttributeValues(Ref, AttributeName);
	Return Result[StrReplace(AttributeName, ".", "")];
	
EndFunction 

// Returns a reference to the common module by the name.
//
// Parameters:
//  Name          - String - common module name, for example:
//                 "Common",
//                 "CommonClient".
//
// Returns:
//  CommonModule.
//
&AtClientAtServerNoContext
Function CommonModule(Name)
	
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	If Metadata.CommonModules.Find(Name) <> Undefined Then
		Module = Eval(Name);
	Else
		Module = Undefined;
	EndIf;
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise SubstituteParametersToString(NStr("ru = 'Общий модуль ""%1"" не найден.'; en = 'Common module ""%1"" is not found.'; pl = 'Nie znaleziono wspólnego modułu ""%1"".';es_ES = 'Módulo común ""%1"" no se ha encontrado.';es_CO = 'Módulo común ""%1"" no se ha encontrado.';tr = 'Ortak modül ""%1"" bulunamadı.';it = 'Il modulo comune""%1"" non è stato trovato.';de = 'Gemeinsames Modul ""%1"" wurde nicht gefunden.'"), Name);
	EndIf;
#Else
	Module = Eval(Name);
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise SubstituteParametersToString(NStr("ru = 'Общий модуль ""%1"" не найден.'; en = 'Common module ""%1"" is not found.'; pl = 'Nie znaleziono wspólnego modułu ""%1"".';es_ES = 'Módulo común ""%1"" no se ha encontrado.';es_CO = 'Módulo común ""%1"" no se ha encontrado.';tr = 'Ortak modül ""%1"" bulunamadı.';it = 'Il modulo comune""%1"" non è stato trovato.';de = 'Gemeinsames Modul ""%1"" wurde nicht gefunden.'"), Name);
	EndIf;
#EndIf
	
	Return Module;
	
EndFunction

// Returns True if a susbystem exists.
//
// Parameters:
//  FullSubsystemName - String. Full name for the subsystem metadata object, excluding the "Susbystem." substring.
//                        Example: "StandardSubsystems.Core".
//
// Example of calling an optional subsystem:
//
//  If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
//  	ModuleAccessManagement = Common.CommonModule("AccessManagement");
//  	ModuleAccessManagement.<Method name>();
//  EndIf
//
// Returns:
//  Boolean.
//
&AtServer
Function SubsystemExists(FullSubsystemName)
	
	If Not SSLVersionMatchesRequirements() Then
		Return False;
	EndIf;
	
	SubsystemNames = SubsystemNames();
	Return SubsystemNames.Get(FullSubsystemName) <> Undefined;
	
EndFunction

// Returns a map between subsystem names and the True value;
&AtServerNoContext
Function SubsystemNames()
	
	Return New FixedMap(SubordinateSubsystemsNames(Metadata));
	
EndFunction

&AtServerNoContext
Function SubordinateSubsystemsNames(ParentSubsystem)
	
	Names = New Map;
	
	For Each CurrentSubsystem In ParentSubsystem.Subsystems Do
		
		Names.Insert(CurrentSubsystem.Name, True);
		SubordinateItemNames = SubordinateSubsystemsNames(CurrentSubsystem);
		
		For each SubordinateItemName In SubordinateItemNames Do
			Names.Insert(CurrentSubsystem.Name + "." + SubordinateItemName.Key, True);
		EndDo;
	EndDo;
	
	Return Names;
	
EndFunction

// Returns a string presentation of the type.
// For reference types, returns a string in format "CatalogRef.ObjectName" or "DocumentRef.ObjectName".
// For any other types, converts the type to string. Example: "Number".
//
&AtServerNoContext
Function TypePresentationString(Type)
	
	Presentation = "";
	
	If IsReference(Type) Then
	
		FullName = Metadata.FindByType(Type).FullName();
		ObjectName = StrSplit(FullName, ".")[1];
		
		If Catalogs.AllRefsType().ContainsType(Type) Then
			Presentation = "CatalogRef";
		
		ElsIf Documents.AllRefsType().ContainsType(Type) Then
			Presentation = "DocumentRef";
		
		ElsIf BusinessProcesses.AllRefsType().ContainsType(Type) Then
			Presentation = "BusinessProcessRef";
		
		ElsIf ChartsOfCharacteristicTypes.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfCharacteristicTypesRef";
		
		ElsIf ChartsOfAccounts.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfAccountsRef";
		
		ElsIf ChartsOfCalculationTypes.AllRefsType().ContainsType(Type) Then
			Presentation = "ChartOfCalculationTypesRef";
		
		ElsIf Tasks.AllRefsType().ContainsType(Type) Then
			Presentation = "TaskRef";
		
		ElsIf ExchangePlans.AllRefsType().ContainsType(Type) Then
			Presentation = "ExchangePlanRef";
		
		ElsIf Enums.AllRefsType().ContainsType(Type) Then
			Presentation = "EnumRef";
		
		EndIf;
		
		Result = ?(Presentation = "", Presentation, Presentation + "." + ObjectName);
		
	ElsIf Type = Type("Undefined") Then
		
		Result = "Undefined";
		
	Else
		
		Result = String(Type);
		
	EndIf;
	
	Return Result;
	
EndFunction

// Converts XML text into a structure with value tables. The function creates table columns based on 
// the XML description.
//
// Parameters:
//  XML     - text in XML or ReadXML format.
//
// XML schema:
// <?xml version="1.0" encoding="utf-8"?>
//  <xs:schema attributeFormDefault="unqualified" elementFormDefault="qualified" xmlns:xs="http://www.w3.org/2001/XMLSchema">
//   <xs:element name="Items">
//    <xs:complexType>
//     <xs:sequence>
//      <xs:element maxOccurs="unbounded" name="Item">
//       <xs:complexType>
//        <xs:attribute name="Code" type="xs:integer" use="required" />
//        <xs:attribute name="Name" type="xs:string" use="required" />
//        <xs:attribute name="Socr" type="xs:string" use="required" />
//        <xs:attribute name="Index" type="xs:string" use="required" />
//       </xs:complexType>
//      </xs:element>
//     </xs:sequence>
//    <xs:attribute name="Description" type="xs:string" use="required" />
//    <xs:attribute name="Columns" type="xs:string" use="required" />
//   </xs:complexType>
//  </xs:element>
// </xs:schema>
//
// DELETE: NO DEMO INCLUDED
// 
// Usage example:
//   ClassifierTable = ReadXMLToTable(InformationRegisters.AddressClassifier.
//       GetTemplate("NationalAddressObjectsClassifier").GetText());
//
// Returns:
//  Structure containing fields:
//   TableName - String
//   Data - ValueTable.
//
&AtServerNoContext
Function ReadXMLToTable(Val XML)
	
	If TypeOf(XML) <> Type("XMLReader") Then
		Read = New XMLReader;
		Read.SetString(XML);
	Else
		Read = XML;
	EndIf;
	
	// Reading the first node and checking it.
	If Not Read.Read() Then
		Raise NStr("ru = 'Пустой XML'; en = 'The XML file is empty.'; pl = 'Pusty XML';es_ES = 'XML vacío';es_CO = 'XML vacío';tr = 'Boş XML';it = 'Il file XML è vuoto.';de = 'Leeres XML'");
	ElsIf Read.Name <> "Items" Then
		Raise NStr("ru = 'Ошибка в структуре XML'; en = 'XML file format error.'; pl = 'Wystąpił błąd w strukturze XML';es_ES = 'Ha ocurrido un error en la estructura XML';es_CO = 'Ha ocurrido un error en la estructura XML';tr = 'XML yapısında bir hata oluştu';it = 'Errore formato file XML.';de = 'In der XML-Struktur ist ein Fehler aufgetreten'");
	EndIf;
	
	// Getting table details and creating the table.
	TableName = Read.GetAttribute("Description");
	ColumnNames = StrReplace(Read.GetAttribute("Columns"), ",", Chars.LF);
	Columns = StrLineCount(ColumnNames);
	
	ValueTable = New ValueTable;
	For Cnt = 1 To Columns Do
		ValueTable.Columns.Add(StrGetLine(ColumnNames, Cnt), New TypeDescription("String"));
	EndDo;
	
	// Filling the table with values.
	While Read.Read() Do
		
		If Read.NodeType = XMLNodeType.EndElement AND Read.Name = "Items" Then
			Break;
		ElsIf Read.NodeType <> XMLNodeType.StartElement Then
			Continue;
		ElsIf Read.Name <> "Item" Then
			Raise NStr("ru = 'Ошибка в структуре XML'; en = 'XML file format error.'; pl = 'Wystąpił błąd w strukturze XML';es_ES = 'Ha ocurrido un error en la estructura XML';es_CO = 'Ha ocurrido un error en la estructura XML';tr = 'XML yapısında bir hata oluştu';it = 'Errore formato file XML.';de = 'In der XML-Struktur ist ein Fehler aufgetreten'");
		EndIf;
		
		newRow = ValueTable.Add();
		For Cnt = 1 To Columns Do
			ColumnName = StrGetLine(ColumnNames, Cnt);
			newRow[Cnt-1] = Read.GetAttribute(ColumnName);
		EndDo;
		
	EndDo;
	
	// Filling the resulting value table
	Result = New Structure;
	Result.Insert("TableName", TableName);
	Result.Insert("Data", ValueTable);
	
	Return Result;
	
EndFunction

//	Converts the value table into an array.
//	Use this function to pass data received on the server as a value table to the client. This is 
//	only possible if all of values from the value table can be passed to the client.
//	
//  
//
//	The resulting array contains structures that duplicate value table row structures.
//	
//
//	It is recommended that you do not use this procedure to convert value tables with a large number 
//	of rows.
//
//	Parameters: ValueTable
//	Return value: Array.
//
&AtServerNoContext
Function ValueTableToArray(ValueTable)
	
	Array = New Array();
	StructureString = "";
	CommaRequired = False;
	For Each Column In ValueTable.Columns Do
		If CommaRequired Then
			StructureString = StructureString + ",";
		EndIf;
		StructureString = StructureString + Column.Name;
		CommaRequired = True;
	EndDo;
	For Each Row In ValueTable Do
		NewRow = New Structure(StructureString);
		FillPropertyValues(NewRow, Row);
		Array.Add(NewRow);
	EndDo;
	Return Array;

EndFunction

// Generates a string according to the specified pattern.
// The following tags are available:
//	<b> String </b> - formats the string as bold.
//	<a href = "Link"> String </a>
//
// Example:
//	The lowest supported version is <b>1.1</b>. Please <a href = "Update">update</a> the application.
//
// Returns:
//	FormattedString
&AtServerNoContext
Function FormattedString(Val Row)
	
	BoldStrings = New ValueList;
	While StrFind(Row, "<b>") <> 0 Do
		BoldBeginning = StrFind(Row, "<b>");
		StringBeforeOpeningTag = Left(Row, BoldBeginning - 1);
		BoldStrings.Add(StringBeforeOpeningTag);
		StringAfterOpeningTag = Mid(Row, BoldBeginning + 3);
		BoldEnd = StrFind(StringAfterOpeningTag, "</b>");
		BoldFragment = Left(StringAfterOpeningTag, BoldEnd - 1);
		BoldStrings.Add(BoldFragment,, True);
		StringAfterBold = Mid(StringAfterOpeningTag, BoldEnd + 4);
		Row = StringAfterBold;
	EndDo;
	BoldStrings.Add(Row);
	
	StringsWithLinks = New ValueList;
	For Each StringPart In BoldStrings Do
		
		Row = StringPart.Value;
		
		If StringPart.Check Then
			StringsWithLinks.Add(Row,, True);
			Continue;
		EndIf;
		
		BoldBeginning = StrFind(Row, "<a href = ");
		While BoldBeginning <> 0 Do
			StringBeforeOpeningTag = Left(Row, BoldBeginning - 1);
			StringsWithLinks.Add(StringBeforeOpeningTag, );
			
			StringAfterOpeningTag = Mid(Row, BoldBeginning + 9);
			EndTag = StrFind(StringAfterOpeningTag, ">");
			
			Ref = TrimAll(Left(StringAfterOpeningTag, EndTag - 2));
			If StrStartsWith(Ref, """") Then
				Ref = Mid(Ref, 2, StrLen(Ref) - 1);
			EndIf;
			If StrEndsWith(Ref, """") Then
				Ref = Mid(Ref, 1, StrLen(Ref) - 1);
			EndIf;
			
			StringAfterLink = Mid(StringAfterOpeningTag, EndTag + 1);
			BoldEnd = StrFind(StringAfterLink, "</a>");
			HyperlinkAnchorText = Left(StringAfterLink, BoldEnd - 1);
			StringsWithLinks.Add(HyperlinkAnchorText, Ref);
			
			StringAfterBold = Mid(StringAfterLink, BoldEnd + 4);
			Row = StringAfterBold;
			
			BoldBeginning = StrFind(Row, "<a href = ");
		EndDo;
		StringsWithLinks.Add(Row);
		
	EndDo;
	
	StringArray = New Array;
	For Each StringPart In StringsWithLinks Do
		
		If StringPart.Check Then
			StringArray.Add(New FormattedString(StringPart.Value, New Font(,,True)));
		ElsIf Not IsBlankString(StringPart.Presentation) Then
			StringArray.Add(New FormattedString(StringPart.Value,,,, StringPart.Presentation));
		Else
			StringArray.Add(StringPart.Value);
		EndIf;
		
	EndDo;
	
	Return New FormattedString(StringArray);
	
EndFunction

// Generates the presentation of a number for a certain language and number parameters.
//
// Parameters:
//  Pattern          - String - contains 6 semicolon-separated string forms for each numeral 
//                             category: 
//                             - %1 denotes the number position;
//  Number           - Number - number to be inserted instead of "%1".
//  Kind             -  NumberValueType - kind of the numeric value to generate a presentation for. 
//                             - Cardinal (default) or Ordinal.
//  FormatString - String - formatting parameters. See similar example for StringWithNumber. 
//
// Returns:
//  String - string presentation for the number in the requested format.
//
// Example:
//  
//  String = StringFunctionsClientServer.StringWithNumberForAnyLanguage(
//		NStr("ru=';остался %1 день;;осталось %1 дня;осталось %1 дней;осталось %1 дня';
//		     |en=';left %1 day;;;;left %1 days'"), 
//		0.05,, "NFD=1");
// 
&AtServerNoContext
Function StringWithNumberForAnyLanguage(Template, Number, Kind = Undefined, FormatString = Undefined)

	If IsBlankString(Template) Then
		Return Format(Number, FormatString); 
	EndIf;

	If Kind = Undefined Then
		Kind = NumericValueType.Cardinal;
	EndIf;

	Return StringWithNumber(Template, Number, Kind, FormatString);

EndFunction

// Returns a flag that shows whether this is the base configuration.
//
// Returns:
//   Boolean   - True if this is the basic configuration.
//
&AtServerNoContext
Function IsBaseConfigurationVersion()
	
	Return StrFind(Upper(Metadata.Name), "BASE") > 0;
	
EndFunction

// Checks if conditional separation is enabled.
// If it is called in shared application it returns False.
//
&AtServerNoContext
Function DataSeparationEnabled()
	
	SaaSAvailable = Metadata.FunctionalOptions.Find("SaaS");
	If SaaSAvailable <> Undefined Then
		OptionName = "SaaS";
		Return IsSeparatedConfiguration() AND GetFunctionalOption(OptionName);
	EndIf;
	
	Return False;
	
EndFunction

// Returns a flag that shows if there are any common separators in the configuration.
//
// Returns:
// Boolean.
//
&AtServerNoContext
Function IsSeparatedConfiguration()
	
	HasSeparators = False;
	For each CommonAttribute In Metadata.CommonAttributes Do
		If CommonAttribute.DataSeparation = Metadata.ObjectProperties.CommonAttributeDataSeparation.Separate Then
			HasSeparators = True;
			Break;
		EndIf;
	EndDo;
	
	Return HasSeparators;
	
EndFunction

&AtServer
Function SSLVersionMatchesRequirements()
	DataProcessorObject = FormAttributeToValue("Object");
	Return DataProcessorObject.SSLVersionMatchesRequirements();
EndFunction

&AtServer
Procedure CheckPlatformVersionAndCompatibilityMode()
	
	Information = New SystemInfo;
	If Not (Left(Information.AppVersion, 3) = "8.3"
		AND (Metadata.CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse
		Or (Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_1
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_2_13
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_2_16"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_1"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_2"]))) Then
		
		Raise NStr("ru = 'Обработка предназначена для запуска на версии платформы
			|1С:Предприятие 8.3 с отключенным режимом совместимости или выше'; 
			|en = 'The data processor is intended for use with 
			|1C:Enterprise 8.3 or later, with disabled compatibility mode'; 
			|pl = 'Przetwarzanie jest przeznaczona do uruchomienia na wersji platformy 
			|1C:Enterprise 8.3 z odłączonym trybem kompatybilności lub wyżej';
			|es_ES = 'El procesamiento se utiliza para iniciar en la versión de la plataforma
			| 1C:Enterprise 8.3 con el modo de compatibilidad desactivado o superior';
			|es_CO = 'El procesamiento se utiliza para iniciar en la versión de la plataforma
			| 1C:Enterprise 8.3 con el modo de compatibilidad desactivado o superior';
			|tr = 'İşlem, 
			|1C: İşletme 8.3 platform sürümü (veya üzeri) uyumluluk modu kapalı olarak başlamak için kullanılır';
			|it = 'L''elaborazione è predisposta per essere eseguita sulla versione della piattaforma
			|1C:Enterprise 8.3 con la modalità di compatibilità disabilitata o superiore';
			|de = 'Die Verarbeitung soll auf der Plattform Version
			|1C:Enterprise 8.3 mit deaktiviertem Kompatibilitätsmodus oder höher gestartet werden'");
		
	EndIf;
	
EndProcedure

&AtServer
Function OperationsKindsPicture()
	If SSLVersionMatchesRequirements() Then
		Return PictureLib["OperationKinds"];
	Else
		Return New Picture;
	EndIf;
EndFunction

&AtClient
Procedure Object1AttributesStartDrag(Item, DragParameters, Perform)
	DragParameters.Value = "Object." + Item.CurrentData.Name;
	// Insert the handler content.
EndProcedure

#EndRegion
