#Region Variables

&AtClient
Var ContinuationHandlerOnWriteError;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	InfobaseUpdate.CheckObjectProcessed(Object, ThisObject);
	
	NewPassedParametersStructure();
	
	If PassedFormParameters.CopyWithQuestion
		AND Not GetFunctionalOption("UseAdditionalCommonAttributesAndInfo")
		AND (Not AttributeWithAdditionalValuesList()
			Or Not GetFunctionalOption("UseCommonAdditionalValues")) Then
		PassedFormParameters.CopyWithQuestion = False;
		PassedFormParameters.CopyingValue = PassedFormParameters.AdditionalValuesOwner;
	EndIf;
	
	If PassedFormParameters.SelectCommonProperty
		Or PassedFormParameters.SelectAdditionalValueOwner
		Or PassedFormParameters.CopyWithQuestion Then
		ThisObject.WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		WizardMode               = True;
		If PassedFormParameters.CopyWithQuestion Then
			Items.WIzardCardPages.CurrentPage = Items.ActionChoice;
			FillActionListOnAddAttribute();
		Else
			FillSelectionPage();
		EndIf;
		RefreshFormItemsContent();
		
		If CommonClientServer.IsWebClient() Then
			Items.AttributeCard.Visible = False;
		EndIf;
	Else
		FillAttributeOrInfoCard();
		// Object attribute lock subsystem handler.
		ObjectAttributesLock.LockAttributes(ThisObject, Items.MainCommandBar);
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.DuplicateObjectDetection") Then
		Items.FormDuplicateObjectDetection.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If TypeOf(SelectedValue) = Type("ChartOfCharacteristicTypesRef.AdditionalAttributesAndInfo") Then
		Close();
		
		// Opening the property form.
		FormParameters = New Structure;
		FormParameters.Insert("Key", SelectedValue);
		FormParameters.Insert("CurrentPropertiesSet", CurrentPropertiesSet);
		
		OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
			FormParameters, FormOwner);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If NOT WriteParameters.Property("WhenDescriptionAlreadyInUse") Then
	
		// Fill in description by property set and check if there is a property with the same description.
		// 
		QuestionText = DescriptionAlreadyUsed(
			Object.Title, Object.Ref, Object.PropertySet, Object.Description);
		
		If ValueIsFilled(QuestionText) Then
			Buttons = New ValueList;
			Buttons.Add("ContinueWrite",            NStr("ru = '???????????????????? ????????????'; en = 'Continue writing'; pl = 'Kontynuuj zapisywanie';es_ES = 'Continuar la grabaci??n';es_CO = 'Continuar la grabaci??n';tr = 'Yazmaya devam et';it = 'continuare la scrittura';de = 'Weiter schreiben'"));
			Buttons.Add("BackToDescriptionInput", NStr("ru = '?????????????????? ?? ?????????? ????????????????????????'; en = 'Back to description input'; pl = 'Wr???? do wprowadzania nazwy';es_ES = 'Volver a la introducci??n del nombre';es_CO = 'Volver a la introducci??n del nombre';tr = '??sim giri??ine d??n';it = 'Indietro alla descrizione inserimento';de = 'Zur??ck zur Namenseingabe'"));
			
			ShowQueryBox(
				New NotifyDescription("AfterResponseOnQuestionWhenDescriptionIsAlreadyUsed", ThisObject, WriteParameters),
				QuestionText, Buttons, , "BackToDescriptionInput");
			
			Cancel = True;
			Return;
		EndIf;
	EndIf;
	
	If NOT WriteParameters.Property("WhenNameAlreadyInUse")
		AND ValueIsFilled(Object.Name) Then
		// Fill in description by property set and check if there is a property with the same description.
		// 
		QuestionText = NameAlreadyUsed(
			Object.Name, Object.Ref, Object.PropertySet, Object.Description);
		
		If ValueIsFilled(QuestionText) Then
			Buttons = New ValueList;
			Buttons.Add("ContinueWrite",            NStr("ru = '????????????????????'; en = 'Continue'; pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continua';de = 'Weiter'"));
			Buttons.Add("BackToNameInput", NStr("ru = '????????????'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = '??ptal et';it = 'Annulla';de = 'Abbrechen'"));
			
			ShowQueryBox(
				New NotifyDescription("AfterResponseOnQuestionWhenNameIsAlreadyUsed", ThisObject, WriteParameters),
				QuestionText, Buttons, , "ContinueWrite");
			
			Cancel = True;
			Return;
		EndIf;
	EndIf;
	
	If WriteParameters.Property("ContinuationHandler") Then
		ContinuationHandlerOnWriteError = WriteParameters.ContinuationHandler;
		AttachIdleHandler("AfterWriteError", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If PropertyManagerInternal.ValueTypeContainsPropertyValues(Object.ValueType) Then
		CurrentObject.AdditionalValuesUsed = True;
	Else
		CurrentObject.AdditionalValuesUsed = False;
		CurrentObject.ValueFormTitle = "";
		CurrentObject.ValueSelectionFormTitle = "";
	EndIf;
	
	If Object.IsAdditionalInfo
	 OR NOT (    Object.ValueType.ContainsType(Type("Number" ))
	         OR Object.ValueType.ContainsType(Type("Date"  ))
	         OR Object.ValueType.ContainsType(Type("Boolean")) )Then
		
		CurrentObject.FormatProperties = "";
	EndIf;
	
	CurrentObject.MultilineInputField = 0;
	
	If NOT Object.IsAdditionalInfo
	   AND Object.ValueType.Types().Count() = 1
	   AND Object.ValueType.ContainsType(Type("String")) Then
		
		If AttributePresentation = "MultilineInputField" Then
			CurrentObject.MultilineInputField   = MultilineInputFieldNumber;
			CurrentObject.OutputAsHyperlink = False;
		EndIf;
	EndIf;
	
	// Generating additional attribute or info name.
	If Not ValueIsFilled(CurrentObject.Name)
		Or WriteParameters.Property("WhenNameAlreadyInUse") Then
		CurrentObject.Name = "";
		ObjectTitle = CurrentObject.Title;
		PropertyManagerInternal.DeleteDisallowedCharacters(ObjectTitle);
		ObjectTitleInParts = StrSplit(ObjectTitle, " ", False);
		For Each TitlePart In ObjectTitleInParts Do
			CurrentObject.Name = CurrentObject.Name + Upper(Left(TitlePart, 1)) + Mid(TitlePart, 2);
		EndDo;
		
		UID = New UUID();
		UIDString = StrReplace(String(UID), "-", "");
		CurrentObject.Name = CurrentObject.Name + "_" + UIDString;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If ValueIsFilled(CurrentObject.PropertySet) Then
		AddToSet = CurrentObject.PropertySet;
		
		Lock = New DataLock;
		LockItem = Lock.Add("Catalog.AdditionalAttributesAndInfoSets");
		LockItem.SetValue("Ref", AddToSet);
		Lock.Lock();
		LockDataForEdit(AddToSet);
		
		ObjectPropertySet = AddToSet.GetObject();
		If CurrentObject.IsAdditionalInfo Then
			TabularSection = ObjectPropertySet.AdditionalInfo;
		Else
			TabularSection = ObjectPropertySet.AdditionalAttributes;
		EndIf;
		FoundRow = TabularSection.Find(CurrentObject.Ref, "Property");
		If FoundRow = Undefined Then
			NewRow = TabularSection.Add();
			NewRow.Property = CurrentObject.Ref;
			ObjectPropertySet.Write();
			CurrentObject.AdditionalProperties.Insert("ModifiedSet", AddToSet);
		EndIf;
		
	EndIf;
	
	If WriteParameters.Property("ClearEnteredWeightCoefficients") Then
		ClearEnteredWeightCoefficients();
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If AttributeAddMode = "CreateByCopying" Then
		WriteAdditionalAttributeValuesOnCopy(CurrentObject);
	EndIf;
	
	// Object attribute lock subsystem handler.
	ObjectAttributesLock.LockAttributes(ThisObject);
	
	RefreshFormItemsContent();
	
	If CurrentObject.AdditionalProperties.Property("ModifiedSet") Then
		WriteParameters.Insert("ModifiedSet", CurrentObject.AdditionalProperties.ModifiedSet);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_AdditionalAttributesAndInfo",
		New Structure("Ref", Object.Ref), Object.Ref);
	
	If WriteParameters.Property("ModifiedSet") Then
		
		Notify("Write_AdditionalDataAndAttributeSets",
			New Structure("Ref", WriteParameters.ModifiedSet), WriteParameters.ModifiedSet);
	EndIf;
	
	If WriteParameters.Property("ContinuationHandler") Then
		ContinuationHandlerOnWriteError = Undefined;
		DetachIdleHandler("AfterWriteError");
		ExecuteNotifyProcessing(
			New NotifyDescription(WriteParameters.ContinuationHandler.ProcedureName,
				ThisObject, WriteParameters.ContinuationHandler.Parameters),
			False);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If WizardMode Then
		SetWizardSettings();
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Properties_AttributeDependencySet" Then
		Modified = True;
		ValueAdded = False;
		For Each DependenceCondition In AttributeDependencyConditions Do
			Value = Undefined;
			If Parameter.Property(DependenceCondition.Presentation, Value) Then
				ValueInStorage = PutToTempStorage(Value, UUID);
				DependenceCondition.Value = ValueInStorage;
				ValueAdded = True;
			EndIf;
		EndDo;
		If Not ValueAdded Then
			For Each PassedParameter In Parameter Do
				ValueInStorage = PutToTempStorage(PassedParameter.Value, UUID);
				AttributeDependencyConditions.Add(ValueInStorage, PassedParameter.Key);
			EndDo;
		EndIf;
		
		SetAdditionalAttributeDependencies();
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure IsAdditionalInfoOnChange(Item)
	
	Object.IsAdditionalInfo = IsAdditionalInfo;
	
	RefreshFormItemsContent();
	
EndProcedure

&AtClient
Procedure ValueListAdjustmentCommentClick(Item)
	
	WriteObject("GoToValueList",
		"ValueListAdjustmentCommentClickCompletion");
	
EndProcedure

&AtClient
Procedure SetAdjustmentCommentClick(Item)
	
	WriteObject("GoToValueList",
		"SetAdjustmentCommentClickFollowUp");
	
EndProcedure

&AtClient
Procedure ValueTypeOnChange(Item)
	
	WarningText = "";
	RefreshFormItemsContent(WarningText);
	
	If ValueIsFilled(WarningText) Then
		ShowMessageBox(, WarningText);
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalValuesWithWeightOnChange(Item)
	
	If ValueIsFilled(Object.Ref)
	   AND NOT Object.AdditionalValuesWithWeight Then
		
		QuestionText =
			NStr("ru = '???????????????? ?????????????????? ?????????????? ?????????????????????????
			           |
			           |???????????? ?????????? ????????????????.'; 
			           |en = 'Do you want to clear the entered weight coefficients?
			           |
			           |The data will be written.'; 
			           |pl = 'Oczy??ci?? wprowadzone wsp????czynniki wagowe?
			           |
			           |Dane zostan?? zapisane.';
			           |es_ES = '??Eliminar los coeficientes de peso introducidos?
			           |
			           |Datos se guardar??n.';
			           |es_CO = '??Eliminar los coeficientes de peso introducidos?
			           |
			           |Datos se guardar??n.';
			           |tr = 'Girilen a????rl??k katsay??lar?? temizlensin mi? 
			           |
			           |Veri yaz??lacak.';
			           |it = 'Volete cancellare i coefficienti di peso inseriti?
			           |
			           |I dati saranno sovrascritti.';
			           |de = 'Die eingegebenen Gewichtswerte l??schen?
			           |
			           |Die Daten werden aufgezeichnet.'");
		
		Buttons = New ValueList;
		Buttons.Add("ClearAndWrite", NStr("ru = '???????????????? ?? ????????????????'; en = 'Clear and write'; pl = 'Oczy???? i zapisz';es_ES = 'Eliminar y grabar';es_CO = 'Eliminar y grabar';tr = 'Temizle ve yaz';it = 'Cancella e scrivi';de = 'L??schen und schreiben'"));
		Buttons.Add("Cancel", NStr("ru = '????????????'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = '??ptal et';it = 'Annulla';de = 'Abbrechen'"));
		
		ShowQueryBox(
			New NotifyDescription("AfterConfirmClearWeightCoefficients", ThisObject),
			QuestionText, Buttons, , "ClearAndWrite");
	Else
		WriteObject("WeightUsageEdit",
			"AdditionalValuesWithWeightOnChangeCompletion");
	EndIf;
	
EndProcedure

&AtClient
Procedure MultilineInputFieldNumberOnChange(Item)
	
	AttributePresentation = "MultilineInputField";
	
EndProcedure

&AtClient
Procedure CommentOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	CommonClient.ShowCommentEditingForm(
		Item.EditText, ThisObject, "Object.Comment");
	
EndProcedure

&AtClient
Procedure RequiredToFillOnChange(Item)
	Items.SpecifyFillingCondition.Enabled = Object.RequiredToFill;
EndProcedure

&AtClient
Procedure SetAvailabilityConditionClick(Item)
	OpenDependenceSettingForm("Available");
EndProcedure

&AtClient
Procedure SetConditionClick(Item)
	OpenDependenceSettingForm("RequiredToFill");
EndProcedure

&AtClient
Procedure SetVisibilityConditionClick(Item)
	OpenDependenceSettingForm("Visible");
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Object.Comment");
EndProcedure

&AtClient
Procedure AttributeKindOnChange(Item)
	Items.OutputAsHyperlink.Enabled    = (AttributePresentation = "OneLineInputField");
	Items.MultilineInputFieldNumber.Enabled = (AttributePresentation = "MultilineInputField");
EndProcedure

#EndRegion

#Region PropertySetsFormTableItemEventHandlers

&AtClient
Procedure PropertySetsOnActivateRow(Item)
	AttachIdleHandler("OnChangeCurrentSet", 0.1, True)
EndProcedure

&AtClient
Procedure PropertySetsBeforeChangeRow(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region PropertiesSelectionFormTableItemEventHandlers

&AtClient
Procedure PropertiesSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	
	NextCommand(Undefined);
EndProcedure

#EndRegion

#Region ValueFormTableItemEventHandlers

&AtClient
Procedure ValuesOnChange(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		EventName = "Write_ObjectPropertyValues";
	Else
		EventName = "Write_ObjectPropertyValueHierarchy";
	EndIf;
	
	Notify(EventName,
		New Structure("Ref", Item.CurrentData.Ref),
		Item.CurrentData.Ref);
	
EndProcedure

&AtClient
Procedure ValuesBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	Cancel = True;
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Copy", Clone);
	AdditionalParameters.Insert("Parent", Parent);
	AdditionalParameters.Insert("Group", IsFolder);
	
	WriteObject("GoToValueList",
		"BeforeAddRowValuesCompletion", AdditionalParameters);
	
EndProcedure

&AtClient
Procedure ValuesBeforeChangeStart(Item, Cancel)
	
	Cancel = True;
	
	If Items.AdditionalValues.ReadOnly Then
		Return;
	EndIf;
	
	WriteObject("GoToValueList",
		"ValuesBeforeChangeRowCompletion");
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure NextCommand(Command)
	
	If CommonClientServer.IsWebClient() Then
		If Not Items.AttributeCard.Visible Then
			Items.AttributeCard.Visible = True;
		EndIf;
	EndIf;
	
	If AttributeAddMode = "MakeCommon" Then
		ConvertAdditionalAttributeToCommonOne();
	EndIf;
	
	If AttributeAddMode = "AddCommonAttributeToSet"
		Or AttributeAddMode = "MakeCommon" Then
		Result = New Structure;
		Result.Insert("CommonProperty", PassedFormParameters.AdditionalValuesOwner);
		If PassedFormParameters.Drag Then
			Result.Insert("Drag", True);
		EndIf;
		NotifyChoice(Result);
		Return;
	EndIf;
	
	MainPage = Items.WIzardCardPages;
	PageIndex = MainPage.ChildItems.IndexOf(MainPage.CurrentPage);
	If PageIndex = 0
		AND Items.Properties.CurrentData = Undefined Then
		WarningText = NStr("ru = '?????????????? ???? ????????????.'; en = 'Item is not selected.'; pl = 'Element nie zosta?? wybrany.';es_ES = 'Elemento no seleccionado.';es_CO = 'Elemento no seleccionado.';tr = '????e se??ilmedi.';it = 'L''elemento non ?? selezionato.';de = 'Element nicht ausgew??hlt.'");
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	If PageIndex = 2 Then
		If Not CheckFilling() Then
			Return;
		EndIf;
		
		If AttributeAddMode = "CreateByCopying" Then
			Items.AttributeValuePages.CurrentPage = Items.AdditionalValues;
		EndIf;
		
		Write();
		Close();
		Return;
	EndIf;
	CurrentPage = MainPage.ChildItems.Get(PageIndex + 1);
	SetWizardSettings(CurrentPage);
	
	OnChangePage("Forward", MainPage, CurrentPage);
	
EndProcedure

&AtClient
Procedure BackCommand(Command)
	
	MainPage = Items.WIzardCardPages;
	PageIndex = MainPage.ChildItems.IndexOf(MainPage.CurrentPage);
	If PageIndex = 1 Then
		AttributeAddMode = "";
	EndIf;
	CurrentPage = MainPage.ChildItems.Get(PageIndex - 1);
	SetWizardSettings(CurrentPage);
	
	OnChangePage("Back", MainPage, CurrentPage);
	
EndProcedure

&AtClient
Procedure CloseForm(Command)
	Close();
EndProcedure

&AtClient
Procedure EditValueFormat(Command)
	
	Designer = New FormatStringWizard(Object.FormatProperties);
	
	Designer.AvailableTypes = Object.ValueType;
	
	Designer.Show(
		New NotifyDescription("EditValueFormatCompletion", ThisObject));
	
EndProcedure

&AtClient
Procedure ValueListAdjustmentChange(Command)
	
	WriteObject("AttributeKindEdit",
		"ValueListAdjustmentChangeCompletion");
	
EndProcedure

&AtClient
Procedure SetsAdjustmentChange(Command)
	
	WriteObject("AttributeKindEdit",
		"ChangeSetAdjustmentCompletion");
	
EndProcedure

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	
	LockedAttributes = ObjectAttributesLockClient.Attributes(ThisObject);
	
	If LockedAttributes.Count() > 0 Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Ref", Object.Ref);
		FormParameters.Insert("IsAdditionalAttribute", Not Object.IsAdditionalInfo);
		
		Notification = New NotifyDescription("AfterAttributesToUnlockChoice", ThisObject);
		OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Form.AttributeUnlocking",
			FormParameters, ThisObject,,,, Notification);
	Else
		ObjectAttributesLockClient.ShowAllVisibleAttributesUnlockedWarning();
	EndIf;
	
EndProcedure

&AtClient
Procedure DuplicateObjectDetection(Command)
	ModuleDuplicateObjectDetectionClient = CommonClient.CommonModule("FindAndDeleteDuplicatesDuplicatesClient");
	DuplicateObjectDetectionFormName = ModuleDuplicateObjectDetectionClient.SearchAndDeletionOfDuplicatesDataProcessorFormName();
	OpenForm(DuplicateObjectDetectionFormName);
EndProcedure

&AtClient
Procedure Change(Command)
	
	If Items.Properties.CurrentData <> Undefined Then
		// Opening the property form.
		FormParameters = New Structure;
		FormParameters.Insert("Key", Items.Properties.CurrentData.Property);
		FormParameters.Insert("CurrentPropertiesSet", SelectedPropertiesSet);
		
		OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
			FormParameters, Items.Properties,,,,, FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtClient
Procedure SharedAttributesNotIncludedInSets(Command)
	NewValue = Not Items.SharedAttributesNotIncludedInSets.Check;
	Items.SharedAttributesNotIncludedInSets.Check = NewValue;
	If NewValue Then
		Items.PropertiesSetsPages.CurrentPage = Items.SharedSetsPage;
	Else
		Items.PropertiesSetsPages.CurrentPage = Items.AllSetsPage;
	EndIf;
	
	DisplayShowCommonAttributesWithoutSets();
	
EndProcedure

&AtServer
Procedure DisplayShowCommonAttributesWithoutSets()
	
	UpdateCurrentSetPropertiesList();
	
EndProcedure

&AtClient
Procedure SetClearDeletionMark(Command)
	WriteObject("DeletionMarkEdit", "SetClearDeletionMarkFollowUp");
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetAdditionalAttributeDependencies()
	
	If AttributeDependencyConditions.Count() = 0 Then
		Return;
	EndIf;
	
	CurrentObject = FormAttributeToValue("Object");
	
	AdditionalAttributesDependencies = CurrentObject.AdditionalAttributesDependencies;
	
	For Each DependenceCondition In AttributeDependencyConditions Do
		RowsFilter = New Structure;
		RowsFilter.Insert("DependentProperty", DependenceCondition.Presentation);
		RowsArray = AdditionalAttributesDependencies.FindRows(RowsFilter);
		For Each TabularSectionRow In RowsArray Do
			AdditionalAttributesDependencies.Delete(TabularSectionRow);
		EndDo;
		
		ValueFromStorage = GetFromTempStorage(DependenceCondition.Value);
		If ValueFromStorage = Undefined Then
			Continue;
		EndIf;
		For Each NewDependence In ValueFromStorage.Get() Do
			FillPropertyValues(CurrentObject.AdditionalAttributesDependencies.Add(), NewDependence);
		EndDo;
	EndDo;
	
	ValueToFormAttribute(CurrentObject, "Object");
	
	SetHyperlinkTitles();
	
EndProcedure

&AtServer
Procedure FillSelectionPage()
	
	If PassedFormParameters.IsAdditionalInfo <> Undefined Then
		IsAdditionalInfo = PassedFormParameters.IsAdditionalInfo;
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
	For Each Ref In Sets Do
		SetPropertiesTypes = PropertyManagerInternal.SetPropertiesTypes(Ref, False);
		
		If IsAdditionalInfo = 1
		   AND SetPropertiesTypes.AdditionalInfo
		 OR IsAdditionalInfo = 0
		   AND SetPropertiesTypes.AdditionalAttributes Then
			
			AvailableSets.Add(Ref);
		EndIf;
	EndDo;
	
	CurrentSetParent = Common.ObjectAttributeValue(
		PassedFormParameters.CurrentPropertiesSet, "Parent");
	SetsToExclude = New Array;
	SetsToExclude.Add(PassedFormParameters.CurrentPropertiesSet);
	If ValueIsFilled(CurrentSetParent) Then
		PredefinedDataName = Common.ObjectAttributeValue(CurrentSetParent, "PredefinedDataName");
		ReplacedCharacterPosition = StrFind(PredefinedDataName, "_");
		FullObjectName = Left(PredefinedDataName, ReplacedCharacterPosition - 1)
			             + "."
			             + Mid(PredefinedDataName, ReplacedCharacterPosition + 1);
		Manager         = Common.ObjectManagerByFullName(FullObjectName);
		
		If StrStartsWith(FullObjectName, "Document") Then
			NewObject = Manager.CreateDocument();
		Else
			NewObject = Manager.CreateItem();
		EndIf;
		ObjectSets = PropertyManagerInternal.GetObjectPropertySets(NewObject);
		
		FilterParameters = New Structure;
		FilterParameters.Insert("CommonSet", True);
		FoundRows = ObjectSets.FindRows(FilterParameters);
		For Each FoundRow In FoundRows Do
			If PassedFormParameters.CurrentPropertiesSet = FoundRow.Set Then
				Continue;
			EndIf;
			SetsToExclude.Add(FoundRow.Set);
		EndDo;
	EndIf;
	
	If IsAdditionalInfo = 1 Then
		Items.SharedAttributesNotIncludedInSets.Title = NStr("ru ='???????????? ?????????? ???????????????????????????? ????????????????'; en = 'Only common additional information'; pl = 'Tylko wsp??lne informacje dodatkowe';es_ES = 'Solo la informaci??n adicional com??n';es_CO = 'Solo la informaci??n adicional com??n';tr = 'Sadece genel ek bilgiler';it = 'Solo informazioni comuni aggiuntive';de = 'Nur allgemeine Zusatzinformationen'");
	Else
		Items.SharedAttributesNotIncludedInSets.Title = NStr("ru ='???????????? ?????????? ???????????????????????????? ??????????????????'; en = 'Only common additional attributes'; pl = 'Tylko wsp??lne atrybuty dodatkowe';es_ES = 'Solo los requisitos adicionales comunes';es_CO = 'Solo los requisitos adicionales comunes';tr = 'Sadece genel ek alanlar';it = 'Solo attributi aggiuntivi comuni';de = 'Nur allgemeine Zusatzattribute'");
	EndIf;
	
	CommonClientServer.SetDynamicListParameter(
		PropertySets, "Sets", AvailableSets, True);
	
	CommonClientServer.SetDynamicListParameter(
		PropertySets, "SetsToExclude", SetsToExclude, True);
	
	CommonClientServer.SetDynamicListParameter(
		PropertySets, "IsAdditionalInfo", (IsAdditionalInfo = 1), True);
	
	CommonClientServer.SetDynamicListParameter(
		CommonPropertySets, "IsAdditionalInfo", (IsAdditionalInfo = 1), True);
	
	CommonClientServer.SetDynamicListParameter(
		CommonPropertySets, "CommonAdditionalInfo", NStr("ru = '?????????? ???????????????????????????? ????????????????'; en = 'Common additional information'; pl = 'Wsp??lne informacje dodatkowe';es_ES = 'Informaci??n adicional com??n';es_CO = 'Informaci??n adicional com??n';tr = 'Genel ek bilgiler';it = 'Informazioni aggiuntive comuni';de = 'Allgemeine Zusatzinformationen'"), True);
	CommonClientServer.SetDynamicListParameter(
		CommonPropertySets, "CommonAdditionalAttributes", NStr("ru = '?????????? ???????????????????????????? ??????????????????'; en = 'Common additional attributes'; pl = 'Wsp??lne atrybuty dodatkowe';es_ES = 'Requisitos adicionales comunes';es_CO = 'Requisitos adicionales comunes';tr = 'Genel ek alanlar';it = 'Attributi aggiuntivi comuni';de = 'Allgemeine Zusatzattribute'"), True);
	
EndProcedure

&AtServer
Procedure FillAdditionalAttributesValues(ValuesOwner)
	
	ValuesTree = FormAttributeToValue("AdditionalAttributesValues");
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	ObjectsPropertiesValues.Ref AS Ref,
		|	ObjectsPropertiesValues.Owner AS Owner,
		|	0 AS PictureCode,
		|	ObjectsPropertiesValues.Weight,
		|	ObjectsPropertiesValues.Description
		|FROM
		|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
		|WHERE
		|	ObjectsPropertiesValues.DeletionMark = FALSE
		|	AND ObjectsPropertiesValues.Owner = &Owner
		|
		|UNION ALL
		|
		|SELECT
		|	ObjectPropertyValueHierarchy.Ref,
		|	ObjectPropertyValueHierarchy.Owner,
		|	0,
		|	ObjectPropertyValueHierarchy.Weight,
		|	ObjectPropertyValueHierarchy.Description
		|FROM
		|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
		|WHERE
		|	ObjectPropertyValueHierarchy.DeletionMark = FALSE
		|	AND ObjectPropertyValueHierarchy.Owner = &Owner
		|
		|ORDER BY
		|	Ref HIERARCHY";
	Query.SetParameter("Owner", ValuesOwner);
	Result = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	
	ValuesTree = Result.Copy();
	ValueToFormAttribute(ValuesTree, "AdditionalAttributesValues");
	
EndProcedure

&AtServer
Procedure ConvertAdditionalAttributeToCommonOne()
	BeginTransaction();
	Try
		SelectedAttribute = PassedFormParameters.AdditionalValuesOwner;
		SelectedAttributeObject = SelectedAttribute.GetObject();
		SelectedAttributeObject.PropertySet = Catalogs.AdditionalAttributesAndInfoSets.EmptyRef();
		SelectedAttributeObject.Description = SelectedAttributeObject.Title;
		SelectedAttributeObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
EndProcedure

&AtServer
Procedure FillAttributeOrInfoCard()
	
	If ValueIsFilled(PassedFormParameters.CopyingValue) Then
		AttributeAddMode = "CreateByCopying";
	EndIf;
	
	CreateAttributeByCopying = (AttributeAddMode = "CreateByCopying");
	
	CurrentPropertiesSet = PassedFormParameters.CurrentPropertiesSet;
	
	If ValueIsFilled(Object.Ref) Then
		Items.IsAdditionalInfo.Enabled = False;
		ShowSetAdjustment = PassedFormParameters.ShowSetAdjustment;
	Else
		Object.Available = True;
		Object.Visible  = True;
		
		Object.AdditionalAttributesDependencies.Clear();
		If ValueIsFilled(CurrentPropertiesSet) Then
			Object.PropertySet = CurrentPropertiesSet;
		EndIf;
		
		If CreateAttributeByCopying Then
			Object.AdditionalValuesOwner = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.EmptyRef();
		ElsIf ValueIsFilled(PassedFormParameters.AdditionalValuesOwner) Then
			Object.AdditionalValuesOwner = PassedFormParameters.AdditionalValuesOwner;
		EndIf;
		
		If PassedFormParameters.IsAdditionalInfo <> Undefined Then
			Object.IsAdditionalInfo = PassedFormParameters.IsAdditionalInfo;
			
		ElsIf NOT ValueIsFilled(PassedFormParameters.CopyingValue) Then
			Items.IsAdditionalInfo.Visible = True;
		EndIf;
	EndIf;
	
	If Object.Predefined AND NOT ValueIsFilled(Object.Title) Then
		Object.Title = Object.Description;
	EndIf;
	
	IsAdditionalInfo = ?(Object.IsAdditionalInfo, 1, 0);
	
	If CreateAttributeByCopying Then
		// For cases when the attribute is copied from its card using the Copy command.
		If Not ValueIsFilled(PassedFormParameters.AdditionalValuesOwner) Then
			PassedFormParameters.AdditionalValuesOwner = PassedFormParameters.CopyingValue;
		EndIf;
		
		OwnerProperties = Common.ObjectAttributesValues(
			PassedFormParameters.AdditionalValuesOwner, "ValueType, AdditionalValuesWithWeight, FormatProperties");
		
		Object.ValueType    = OwnerProperties.ValueType;
		Object.FormatProperties = OwnerProperties.FormatProperties;
		
		OwnerValuesWithWeight                                = OwnerProperties.AdditionalValuesWithWeight;
		Object.AdditionalValuesWithWeight                    = OwnerValuesWithWeight;
		Items.AdditionalAttributeValues.Header        = OwnerValuesWithWeight;
		Items.AdditionalAttributeValuesWeight.Visible = OwnerValuesWithWeight;
		Items.AttributeValuePages.CurrentPage     = Items.ValueTreePage;
		
		FillAdditionalAttributesValues(PassedFormParameters.AdditionalValuesOwner);
	EndIf;
	
	RefreshFormItemsContent();
	
	If Object.MultilineInputField > 0 Then
		AttributePresentation = "MultilineInputField";
		MultilineInputFieldNumber = Object.MultilineInputField;
	Else
		AttributePresentation = "OneLineInputField";
	EndIf;
	
	Items.OutputAsHyperlink.Enabled    = (AttributePresentation = "OneLineInputField");
	Items.MultilineInputFieldNumber.Enabled = (AttributePresentation = "MultilineInputField");
	
EndProcedure

&AtClient
Procedure AfterAttributesToUnlockChoice(AttributesToUnlock, Context) Export
	
	If TypeOf(AttributesToUnlock) <> Type("Array") Then
		Return;
	EndIf;
	
	ObjectAttributesLockClient.SetFormItemEnabled(ThisObject,
		AttributesToUnlock);
	
	#If WebClient Then
		RefreshDataRepresentation();
	#EndIf
	
EndProcedure

&AtClient
Procedure AfterResponseOnQuestionWhenDescriptionIsAlreadyUsed(Response, WriteParameters) Export
	
	If Response <> "ContinueWrite" Then
		CurrentItem = Items.Title;
		If WriteParameters.Property("ContinuationHandler") Then
			ExecuteNotifyProcessing(
				New NotifyDescription(WriteParameters.ContinuationHandler.ProcedureName,
					ThisObject, WriteParameters.ContinuationHandler.Parameters),
				True);
		EndIf;
	Else
		WriteParameters.Insert("WhenDescriptionAlreadyInUse");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterResponseOnQuestionWhenNameIsAlreadyUsed(Response, WriteParameters) Export
	
	If Response <> "ContinueWrite" Then
		CurrentItem = Items.Title;
		If WriteParameters.Property("ContinuationHandler") Then
			ExecuteNotifyProcessing(
				New NotifyDescription(WriteParameters.ContinuationHandler.ProcedureName,
					ThisObject, WriteParameters.ContinuationHandler.Parameters),
				True);
		EndIf;
	Else
		WriteParameters.Insert("WhenNameAlreadyInUse");
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterConfirmClearWeightCoefficients(Response, Context) Export
	
	If Response <> "ClearAndWrite" Then
		Object.AdditionalValuesWithWeight = NOT Object.AdditionalValuesWithWeight;
		Return;
	EndIf;
	
	WriteParameters = New Structure;
	WriteParameters.Insert("ClearEnteredWeightCoefficients");
	
	WriteObject("WeightUsageEdit",
		"AdditionalValuesWithWeightOnChangeCompletion",
		,
		WriteParameters);
	
EndProcedure

&AtClient
Procedure AdditionalValuesWithWeightOnChangeCompletion(Cancel, Context) Export
	
	If Cancel Then
		Object.AdditionalValuesWithWeight = NOT Object.AdditionalValuesWithWeight;
		Return;
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		Notify(
			"Change_ValueIsCharacterizedByWeightCoefficient",
			Object.AdditionalValuesWithWeight,
			Object.Ref);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValueListAdjustmentCommentClickCompletion(Cancel, Context) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	Close();
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowSetAdjustment", True);
	FormParameters.Insert("Key", Object.AdditionalValuesOwner);
	FormParameters.Insert("CurrentPropertiesSet", CurrentPropertiesSet);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.ObjectForm",
		FormParameters, FormOwner);
	
EndProcedure

&AtClient
Procedure SetAdjustmentCommentClickFollowUp(Cancel, Context) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	SelectedSet = Undefined;
	
	If SetsList.Count() > 1 Then
		ShowChooseFromList(
			New NotifyDescription("SetAdjustmentCommentClickCompletion", ThisObject),
			SetsList, Items.SetsAdjustmentComment);
	Else
		SetAdjustmentCommentClickCompletion(Undefined, SetsList[0].Value);
	EndIf;
	
EndProcedure

&AtClient
Procedure SetAdjustmentCommentClickCompletion(SelectedItem, SelectedSet) Export
	
	If SelectedItem <> Undefined Then
		SelectedSet = SelectedItem.Value;
	EndIf;
	
	If Not ValueIsFilled(CurrentPropertiesSet) Then
		Return;
	EndIf;
	
	If SelectedSet <> Undefined Then
		SelectionValue = New Structure;
		SelectionValue.Insert("Set", SelectedSet);
		SelectionValue.Insert("Property", Object.Ref);
		SelectionValue.Insert("IsAdditionalInfo", Object.IsAdditionalInfo);
		NotifyChoice(SelectionValue);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeAddRowValuesCompletion(Cancel, ProcessingParameters) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	If AttributeAddMode = "CreateByCopying" Then
		Items.AttributeValuePages.CurrentPage = Items.AdditionalValues;
	EndIf;
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		ValueTableName = "Catalog.ObjectsPropertiesValues";
	Else
		ValueTableName = "Catalog.ObjectPropertyValueHierarchy";
	EndIf;
	
	FillingValues = New Structure;
	FillingValues.Insert("Parent", ProcessingParameters.Parent);
	FillingValues.Insert("Owner", Object.Ref);
	
	FormParameters = New Structure;
	FormParameters.Insert("HideOwner", True);
	FormParameters.Insert("FillingValues", FillingValues);
	
	If ProcessingParameters.Group Then
		FormParameters.Insert("IsFolder", True);
		
		OpenForm(ValueTableName + ".FolderForm", FormParameters, Items.Values);
	Else
		FormParameters.Insert("ShowWeight", Object.AdditionalValuesWithWeight);
		
		If ProcessingParameters.Copy Then
			FormParameters.Insert("CopyingValue", Items.Values.CurrentRow);
		EndIf;
		
		OpenForm(ValueTableName + ".ObjectForm", FormParameters, Items.Values);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValuesBeforeChangeRowCompletion(Cancel, Context) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		ValueTableName = "Catalog.ObjectsPropertiesValues";
	Else
		ValueTableName = "Catalog.ObjectPropertyValueHierarchy";
	EndIf;
	
	If Items.Values.CurrentRow <> Undefined Then
		// Opening a value form or a value set.
		FormParameters = New Structure;
		FormParameters.Insert("HideOwner", True);
		FormParameters.Insert("ShowWeight", Object.AdditionalValuesWithWeight);
		FormParameters.Insert("Key", Items.Values.CurrentRow);
		
		OpenForm(ValueTableName + ".ObjectForm", FormParameters, Items.Values);
	EndIf;
	
EndProcedure

&AtClient
Procedure ValueListAdjustmentChangeCompletion(Cancel, Context) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentPropertiesSet", CurrentPropertiesSet);
	FormParameters.Insert("PropertySet", Object.PropertySet);
	FormParameters.Insert("Property", Object.Ref);
	FormParameters.Insert("AdditionalValuesOwner", Object.AdditionalValuesOwner);
	FormParameters.Insert("IsAdditionalInfo", Object.IsAdditionalInfo);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Form.ChangePropertySettings",
		FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ChangeSetAdjustmentCompletion(Cancel, Context) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("CurrentPropertiesSet", CurrentPropertiesSet);
	FormParameters.Insert("Property", Object.Ref);
	FormParameters.Insert("PropertySet", Object.PropertySet);
	FormParameters.Insert("AdditionalValuesOwner", Object.AdditionalValuesOwner);
	FormParameters.Insert("IsAdditionalInfo", Object.IsAdditionalInfo);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Form.ChangePropertySettings",
		FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure WriteObject(QuestionTextVariant, ContinuationProcedureName, AdditionalParameters = Undefined, WriteParameters = Undefined)
	
	If WriteParameters = Undefined Then
		WriteParameters = New Structure;
	EndIf;
	
	If QuestionTextVariant = "DeletionMarkEdit" Then
		If Modified Then
			QuestionText = NStr("ru = '?????? %1 ?????????????? ???????????????? ???????????????????? ???????????????? ?????????????????? ??????????????????. ???????????????? ?????????????'; en = 'To set a deletion mark %1, write made changes. Write data?'; pl = 'Dla %1 zaznaczenia do usuni??cia nale??y zapisa?? wprowadzone zmiany. Zapisa?? dane?';es_ES = 'Para %1 marca de borrar es necesario guardar los cambios introducidos. ??Guardar los datos?';es_CO = 'Para %1 marca de borrar es necesario guardar los cambios introducidos. ??Guardar los datos?';tr = 'Silinmeyi %1 i??aretlemek i??in yap??lan de??i??iklikler kaydedilmelidir. Veri kaydedilsin mi?';it = 'Per impostare il contrassegno di eliminazione %1, registrare le modifiche effettuate. Registrare i dati?';de = 'F??r die %1 L??schmarkierung m??ssen die vorgenommenen ??nderungen protokolliert werden. Die Daten aufschreiben?'");
			If Object.DeletionMark Then
				Action = NStr("ru = '????????????????'; en = 'Clear'; pl = 'Wyczy????';es_ES = 'Eliminar';es_CO = 'Eliminar';tr = 'Temizle';it = 'Annulla';de = 'L??schen'");
			Else
				Action = NStr("ru = '??????????????????'; en = 'Set'; pl = 'Ustaw';es_ES = 'Establecer';es_CO = 'Establecer';tr = 'Ayarla';it = 'Imposta';de = 'Einstellen'");
			EndIf;
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(QuestionText, Action);
		Else
			QuestionText = NStr("ru = '???????????????? ""%1"" ???? ?????????????????'; en = 'Do you want to mark %1 for deletion?'; pl = 'Zaznaczy?? ""%1"" do usuni??cia?';es_ES = '??Marcar ""%1"" para borrar?';es_CO = '??Marcar ""%1"" para borrar?';tr = '""%1"" silinmek ??zere i??aretlensin mi?';it = 'Volete contrassegnare %1 per l''eliminazione?';de = 'Markieren Sie ""%1"" zum L??schen?'");
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(QuestionText, Object.Description);
		EndIf;
		
		ShowQueryBox(
			New NotifyDescription(
				ContinuationProcedureName, ThisObject, WriteParameters),
			QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
		Return;
	EndIf;
	
	If ValueIsFilled(Object.Ref) AND NOT Modified Then
		
		ExecuteNotifyProcessing(New NotifyDescription(
			ContinuationProcedureName, ThisObject, AdditionalParameters), False);
		Return;
	EndIf;
	
	ContinuationHandler = New Structure;
	ContinuationHandler.Insert("ProcedureName", ContinuationProcedureName);
	ContinuationHandler.Insert("Parameters", AdditionalParameters);
	
	WriteParameters.Insert("ContinuationHandler", ContinuationHandler);
	
	If ValueIsFilled(Object.Ref) Then
		WriteObjectContinuation("Write", WriteParameters);
		Return;
	EndIf;
	
	If QuestionTextVariant = "GoToValueList" Then
		QuestionText =
			NStr("ru = '?????????????? ?? ???????????? ???? ?????????????? ????????????????
			           |???????????????? ???????????? ?????????? ???????????? ????????????.
			           |
			           |???????????? ?????????? ????????????????.'; 
			           |en = 'You can start working with a value list
			           |only after writing data.
			           |
			           |The data will be written.'; 
			           |pl = 'Przej??cie do pracy z list?? warto??ci
			           |jest mo??liwe tylko po zapisaniu danych.
			           |
			           |Dane zostan?? zapisane.';
			           |es_ES = 'Transici??n para el trabajo de la lista de valores es
			           |posible solo despu??s de haber grabado los datos.
			           |
			           |Datos se guardar??n.';
			           |es_CO = 'Transici??n para el trabajo de la lista de valores es
			           |posible solo despu??s de haber grabado los datos.
			           |
			           |Datos se guardar??n.';
			           |tr = 'De??er listesi ??al????malar??na ge??i?? 
			           |sadece veri kayd??ndan sonra yap??labilir. 
			           |
			           |Veri yaz??lacak.';
			           |it = 'Potete cominciare a lavorare con una lista lavori
			           |solo dopo che i dati saranno registrati.
			           |
			           |I dati saranno registrati.';
			           |de = 'Auf die Werteliste
			           |kann erst nach dem Schreiben der Daten zugegriffen werden
			           |
			           |Die Daten werden aufgezeichnet.'");
	Else
		QuestionText =
			NStr("ru = '???????????? ?????????? ????????????????.'; en = 'Data will be written.'; pl = 'Dane zostan?? zapisane.';es_ES = 'Datos se grabar??n.';es_CO = 'Datos se grabar??n.';tr = 'Veriler yaz??lacakt??r.';it = 'I dati verranno scritti.';de = 'Daten werden geschrieben.'")
	EndIf;
	
	Buttons = New ValueList;
	Buttons.Add("Write", NStr("ru = '????????????????'; en = 'Write'; pl = 'Zapisz';es_ES = 'Guardar';es_CO = 'Escribir';tr = 'Yaz';it = 'Registra';de = 'Schreiben'"));
	Buttons.Add("Cancel", NStr("ru = '????????????'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = '??ptal et';it = 'Annulla';de = 'Abbrechen'"));
	
	ShowQueryBox(
		New NotifyDescription(
			"WriteObjectContinuation", ThisObject, WriteParameters),
		QuestionText, Buttons, , "Write");
	
EndProcedure

&AtClient
Procedure SetClearDeletionMarkFollowUp(Response, WriteParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		Object.DeletionMark = Not Object.DeletionMark;
	EndIf;
	WriteObjectContinuation(Response, WriteParameters);
	
EndProcedure


&AtClient
Procedure WriteObjectContinuation(Response, WriteParameters) Export
	
	If Response = "Write"
		Or Response = DialogReturnCode.Yes Then
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWriteError()
	
	If ContinuationHandlerOnWriteError <> Undefined Then
		ExecuteNotifyProcessing(
			New NotifyDescription(ContinuationHandlerOnWriteError.ProcedureName,
				ThisObject, ContinuationHandlerOnWriteError.Parameters),
			True);
	EndIf;
	
EndProcedure

&AtClient
Procedure EditValueFormatCompletion(Text, Context) Export
	
	If Text <> Undefined Then
		Object.FormatProperties = Text;
		SetFormatButtonTitle(ThisObject);
		
		WarningText = NStr("ru = '?????????????????? ?????????????????? ?????????????? ?????????????????????????? ???? ?????????????????????? ?? ?????????????????????? ????????:'; en = 'The following format settings are not applied automatically in many places:'; pl = 'Nast??puj??ce ustawienia formatu nie s?? stosowane automatycznie w wi??kszo??ci miejsc:';es_ES = 'Los ajustes siguientes del formato o se aplican autom??ticamente en lugares:';es_CO = 'Los ajustes siguientes del formato o se aplican autom??ticamente en lugares:';tr = 'A??a????daki bi??im ayarlar?? ??o??u yerde otomatik olarak uygulanmaz:';it = 'Le impostazioni di formato seguenti non sono applicate automaticamente in posti diversi:';de = 'Die folgenden Formateinstellungen werden an den meisten Orten nicht automatisch angewendet:'");
		Array = StrSplit(Text, ";", False);
		
		For each Substring In Array Do
			If StrFind(Substring, "DE=") > 0 OR StrFind(Substring, "DE=") > 0 Then
				WarningText = WarningText + Chars.LF
					+ " - " + NStr("ru = '?????????????????????????? ???????????? ????????'; en = 'blank date presentation'; pl = 'prezentacja pustej daty';es_ES = 'presentaci??n de la fecha vac??a';es_CO = 'presentaci??n de la fecha vac??a';tr = 'bo?? tarih g??r??nt??leme';it = 'presentazione data vuota';de = 'ein leeres Datum pr??sentieren'");
				Continue;
			EndIf;
			If StrFind(Substring, "NZ=") > 0 OR StrFind(Substring, "NZ=") > 0 Then
				WarningText = WarningText + Chars.LF
					+ " - " + NStr("ru = '?????????????????????????? ?????????????? ??????????'; en = 'blank number presentation'; pl = 'prezentacja pustej liczby';es_ES = 'presentaci??n del n??mero vac??o';es_CO = 'presentaci??n del n??mero vac??o';tr = 'bo?? g??n g??r??nt??leme';it = 'presentazione numero vuota';de = 'eine leere Nummer pr??sentieren'");
				Continue;
			EndIf;
			If StrFind(Substring, "DF=") > 0 OR StrFind(Substring, "DF=") > 0 Then
				If StrFind(Substring, "ddd") > 0 OR StrFind(Substring, "ddd") > 0 Then
					WarningText = WarningText + Chars.LF
						+ " - " + NStr("ru = '?????????????? ???????????????? ?????? ????????????'; en = 'short weekday name'; pl = 'krotna nazwa dnia tygodnia';es_ES = 'nombre corto del d??a de semana';es_CO = 'nombre corto del d??a de semana';tr = 'hafta g??n??n??n k??sa ad??';it = 'nome breve giorno della settimana';de = 'mehrfacher Name des Wochentags'");
				EndIf;
				If StrFind(Substring, "dddd") > 0 OR StrFind(Substring, "dddd") > 0 Then
					WarningText = WarningText + Chars.LF
						+ " - " + NStr("ru = '???????????? ???????????????? ?????? ????????????'; en = 'full weekday name'; pl = 'pe??na nazwa dni tygodnia';es_ES = 'nombre completo del d??a de semana';es_CO = 'nombre completo del d??a de semana';tr = 'hafta g??n??n??n tam ad??';it = 'nome completo giorno della settimana';de = 'vollst??ndiger Name des Wochentags'");
				EndIf;
				If StrFind(Substring, "MMM") > 0 OR StrFind(Substring, "MMM") > 0 Then
					WarningText = WarningText + Chars.LF
						+ " - " + NStr("ru = '?????????????? ???????????????? ????????????'; en = 'short month name'; pl = 'krotna nazwa miesi??ca';es_ES = 'nombre corto del mes';es_CO = 'nombre corto del mes';tr = 'ay??n k??sa ad??';it = 'nome breve mese';de = 'mehrfacher Name des Monats'");
				EndIf;
				If StrFind(Substring, "MMMM") > 0 OR StrFind(Substring, "MMMM") > 0 Then
					WarningText = WarningText + Chars.LF
						+ " - " + NStr("ru = '???????????? ???????????????? ????????????'; en = 'full month name'; pl = 'pe??na nazwa miesi??ca';es_ES = 'nombre completo del mes';es_CO = 'nombre completo del mes';tr = 'ay??n tam ad??';it = 'nome completo mese';de = 'vollst??ndiger Monatsname'");
				EndIf;
			EndIf;
			If StrFind(Substring, "DLF=") > 0 OR StrFind(Substring, "DLF=") > 0 Then
				If StrFind(Substring, "DD") > 0 OR StrFind(Substring, "DD") > 0 Then
					WarningText = WarningText + Chars.LF
						+ " - " + NStr("ru = '?????????????? ???????? (?????????? ????????????????)'; en = 'long date (month in writing)'; pl = 'd??uga data (miesi??c s??ownie)';es_ES = 'fecha larga (mes en letras)';es_CO = 'fecha larga (mes en letras)';tr = 'uzun tarih (ay yaz?? ile)';it = 'data lunga (mese in lettere)';de = 'langes Datum (Monat in Worten)'");
				EndIf;
			EndIf;
		EndDo;
		
		If StrLineCount(WarningText) > 1 Then
			ShowMessageBox(, WarningText);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetWizardSettings(CurrentPage = Undefined)
	
	If CurrentPage = Undefined Then
		CurrentPage = Items.WIzardCardPages.CurrentPage;
	EndIf;
	
	ListHeaderTemplate        = NStr("ru = '???????????????? %1 ?????? ?????????????????? ?? ?????????? ""%2""'; en = 'Select %1 to include it in the ""%2"" set'; pl = 'Wybierz %1 aby w????czy?? do zestawu ""%2""';es_ES = 'Seleccione %1 para activar en el conjunto ""%2""';es_CO = 'Seleccione %1 para activar en el conjunto ""%2""';tr = '""%1"" k??mesine ilave etmek i??in %2 se??';it = 'Seleziona %1 per includerlo nell''insieme ""%2""';de = 'W??hlen Sie %1, um in das ""%2"" Set aufgenommen zu werden'");
	RadioButtonHeaderTemplate = NStr("ru = '???????????????? ?????????????? ???????????????????? ?????????????????????????????? %1 ""%2"" ?? ?????????? ""%3""'; en = 'Select an option of adding additional %1 %2 to the ""%3"" set'; pl = 'Wybierz wariant dodawania dodatkowego %1 ""%2"" do zestawu ""%3""';es_ES = 'Seleccione la variante de a??adir el adicional %1 ""%2"" en el conjunto ""%3""';es_CO = 'Seleccione la variante de a??adir el adicional %1 ""%2"" en el conjunto ""%3""';tr = '""%1"" k??meye ek %2 ""%3"" ilave etme opsiyonunu se??';it = 'Seleziona una opzione di aggiunta aggiuntivi %1 %2 all''insieme ""%3""';de = 'W??hlen Sie die Option aus, um dem Set ""%3"" ein zus??tzliches %1 ""%2"" hinzuzuf??gen'");
	
	If CurrentPage = Items.SelectAttribute Then
		
		If PassedFormParameters.IsAdditionalInfo Then
			Title = NStr("ru = '???????????????????? ?????????????????????????????? ????????????????'; en = 'Add additional information'; pl = 'Dodawanie informacji dodatkowej';es_ES = 'A??adir la informaci??n adicional';es_CO = 'A??adir la informaci??n adicional';tr = 'Ek bilgi ilavesi';it = 'Aggiungi informazioni aggiuntive';de = 'Hinzuf??gen weiterer Informationen'");
		Else
			Title = NStr("ru = '???????????????????? ?????????????????????????????? ??????????????????'; en = 'Add additional attribute'; pl = 'Dodawanie atrybutu dodatkowego';es_ES = 'A??adir el requisito adicional';es_CO = 'A??adir el requisito adicional';tr = 'Ek ??zellik ilavesi';it = 'Aggiungi attributo aggiuntivo';de = 'Hinzuf??gen zus??tzlicher Attribute'");
		EndIf;
		
		Items.CommandBarLeft.Enabled = False;
		Items.NextCommand.Title = NStr("ru = '?????????? >'; en = 'Next >'; pl = 'Dalej >';es_ES = 'Siguiente >';es_CO = 'Siguiente >';tr = 'Sonraki >';it = 'Avanti >';de = 'Weiter >'");
		
		Items.HeaderDecoration.Title = StringFunctionsClientServer.SubstituteParametersToString(
			ListHeaderTemplate,
			?(PassedFormParameters.IsAdditionalInfo, NStr("ru = '???????????????????????????? ????????????????'; en = 'additional information'; pl = 'informacja dodatkowa';es_ES = 'informaci??n adicional';es_CO = 'informaci??n adicional';tr = 'ek bilgi';it = 'informazioni aggiuntive';de = 'weitere Informationen'"), NStr("ru = '???????????????????????????? ????????????????'; en = 'additional attribute'; pl = 'atrybut dodatkowy';es_ES = '(atributo adicional)';es_CO = '(atributo adicional)';tr = 'ek ??znitelik';it = 'attributo aggiuntivo';de = 'zus??tzliche Attribute'")),
			String(PassedFormParameters.CurrentPropertiesSet));
		
	ElsIf CurrentPage = Items.ActionChoice Then
		
		If PassedFormParameters.CopyWithQuestion Then
			Items.CommandBarLeft.Enabled = False;
			AdditionalValuesOwner = PassedFormParameters.AdditionalValuesOwner;
		Else
			Items.CommandBarLeft.Enabled = True;
			SelectedItem = Items.Properties.CurrentData;
			If SelectedItem = Undefined Then
				AdditionalValuesOwner = PassedFormParameters.AdditionalValuesOwner;
			Else
				AdditionalValuesOwner = Items.Properties.CurrentData.Property;
			EndIf;
		EndIf;
		Items.NextCommand.Title = NStr("ru = '?????????? >'; en = 'Next >'; pl = 'Dalej >';es_ES = 'Siguiente >';es_CO = 'Siguiente >';tr = 'Sonraki >';it = 'Avanti >';de = 'Weiter >'");
		
		Items.AttributeAddMode.Title = StringFunctionsClientServer.SubstituteParametersToString(
			RadioButtonHeaderTemplate,
			?(PassedFormParameters.IsAdditionalInfo, NStr("ru = '????????????????'; en = 'information'; pl = 'szczeg????y';es_ES = 'informaci??n';es_CO = 'informaci??n';tr = 'bilgi';it = 'informazione';de = 'information'"), NStr("ru = '??????????????????'; en = 'attribute'; pl = 'atrybut';es_ES = 'atributo';es_CO = 'atributo';tr = '??znitelik';it = 'attributo';de = 'attribut'")),
			String(AdditionalValuesOwner),
			String(PassedFormParameters.CurrentPropertiesSet));
		
		If PassedFormParameters.IsAdditionalInfo Then
			Title = NStr("ru = '???????????????????? ?????????????????????????????? ????????????????'; en = 'Add additional information'; pl = 'Dodawanie informacji dodatkowej';es_ES = 'A??adir la informaci??n adicional';es_CO = 'A??adir la informaci??n adicional';tr = 'Ek bilgi ilavesi';it = 'Aggiungi informazioni aggiuntive';de = 'Hinzuf??gen weiterer Informationen'");
		Else
			Title = NStr("ru = '???????????????????? ?????????????????????????????? ??????????????????'; en = 'Add additional attribute'; pl = 'Dodawanie atrybutu dodatkowego';es_ES = 'A??adir el requisito adicional';es_CO = 'A??adir el requisito adicional';tr = 'Ek ??zellik ilavesi';it = 'Aggiungi attributo aggiuntivo';de = 'Hinzuf??gen zus??tzlicher Attribute'");
		EndIf;
		
	Else
		Items.NextCommand.Title = NStr("ru = '????????????'; en = 'Finish'; pl = 'Data zako??czenia';es_ES = 'Finalizar';es_CO = 'Finalizar';tr = 'Biti??';it = 'Termina';de = 'Abschluss'");
		Items.CommandBarLeft.Enabled = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshFormItemsContent(WarningText = "")
	
	If WizardMode Then
		Items.MainCommandBar.Visible = False;
		Items.NextCommand.DefaultButton    = True;
	Else
		Items.WizardCommandBar.Visible = False;
		Items.WIzardCardPages.CurrentPage = Items.AttributeCard;
	EndIf;
	
	SetFormHeader();
	
	If NOT Object.ValueType.ContainsType(Type("Number"))
	   AND NOT Object.ValueType.ContainsType(Type("Date"))
	   AND NOT Object.ValueType.ContainsType(Type("Boolean")) Then
		
		Object.FormatProperties = "";
	EndIf;
	
	SetFormatButtonTitle(ThisObject);
	
	If Object.IsAdditionalInfo
	 OR NOT (    Object.ValueType.ContainsType(Type("Number" ))
	         OR Object.ValueType.ContainsType(Type("Date"  ))
	         OR Object.ValueType.ContainsType(Type("Boolean")) )Then
		
		Items.EditValueFormat.Visible = False;
	Else
		Items.EditValueFormat.Visible = True;
	EndIf;
	
	If NOT Object.IsAdditionalInfo Then
		Items.MultilineGroup.Visible = True;
		SwitchAttributeDisplaySettings(Object.ValueType);
	Else
		Items.MultilineGroup.Visible = False;
	EndIf;
	
	If ValueIsFilled(Object.Ref) Then
		OldValueType = Common.ObjectAttributeValue(Object.Ref, "ValueType");
		VisibilityAvailabilityCanBeCustomized = ValueIsFilled(Object.PropertySet);
	Else
		OldValueType = New TypeDescription;
		VisibilityAvailabilityCanBeCustomized = ValueIsFilled(CurrentPropertiesSet);
	EndIf;
	
	If Object.IsAdditionalInfo Then
		Object.RequiredToFill = False;
		Items.PropertiesAndDependenciesGroup.Visible = False;
	Else
		AttributeBoolean = (Object.ValueType = New TypeDescription("Boolean"));
		Items.RequiredToFill.Visible    = Not AttributeBoolean;
		Items.SpecifyFillingCondition.Visible = Not AttributeBoolean;
		Items.PropertiesAndDependenciesGroup.Visible = True;
		
		If VisibilityAvailabilityCanBeCustomized Then
			Items.SpecifyFillingCondition.Enabled   = Object.RequiredToFill;
			Items.SpecifyAvailabilityCondition.Enabled  = True;
			Items.SpecifyVisibilityCondition.Enabled    = True;
		Else
			Items.DependencySetupGroup.Visible = False;
			Items.Visible.Visible  = False;
			Items.Available.Visible = False;
			Items.RequiredToFill.Title = NStr("ru = '?????????????????? ??????????????????????'; en = 'Required'; pl = 'Wymagany';es_ES = 'Requerido';es_CO = 'Requerido';tr = 'Gerekli';it = 'Richiesto';de = 'Erforderlich'");
		EndIf;
		SetHyperlinkTitles();
	EndIf;
	
	If ValueIsFilled(Object.AdditionalValuesOwner) Then
		
		OwnerProperties = Common.ObjectAttributesValues(
			Object.AdditionalValuesOwner, "ValueType, AdditionalValuesWithWeight");
		
		If OwnerProperties.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
			Object.ValueType = New TypeDescription(
				Object.ValueType,
				"CatalogRef.ObjectPropertyValueHierarchy",
				"CatalogRef.ObjectsPropertiesValues");
		Else
			Object.ValueType = New TypeDescription(
				Object.ValueType,
				"CatalogRef.ObjectsPropertiesValues",
				"CatalogRef.ObjectPropertyValueHierarchy");
		EndIf;
		
		ValuesOwner = Object.AdditionalValuesOwner;
		ValuesWithWeight   = OwnerProperties.AdditionalValuesWithWeight;
	Else
		// Checking possibility to delete an additional value type.
		If PropertyManagerInternal.ValueTypeContainsPropertyValues(OldValueType) Then
			Query = New Query;
			Query.SetParameter("Owner", Object.Ref);
			
			If OldValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
				Query.Text =
				"SELECT TOP 1
				|	TRUE AS TrueValue
				|FROM
				|	Catalog.ObjectPropertyValueHierarchy AS ObjectPropertyValueHierarchy
				|WHERE
				|	ObjectPropertyValueHierarchy.Owner = &Owner";
			Else
				Query.Text =
				"SELECT TOP 1
				|	TRUE AS TrueValue
				|FROM
				|	Catalog.ObjectsPropertiesValues AS ObjectsPropertiesValues
				|WHERE
				|	ObjectsPropertiesValues.Owner = &Owner";
			EndIf;
			
			If NOT Query.Execute().IsEmpty() Then
				
				If OldValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy"))
				   AND NOT Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
					
					WarningText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = '?????????????????????? ?????????????? ?????? ""%1"",
						           |?????? ?????? ???????????????????????????? ???????????????? ?????? ??????????????.
						           |?????????????? ?????????? ?????????????? ?????????????????? ???????????????????????????? ????????????????.
						           |
						           |?????????????????? ?????? ????????????????????????.'; 
						           |en = 'Cannot delete the %1 type
						           |as additional values are entered already.
						           |Delete additional values you entered first.
						           |
						           |Deleted type is restored.'; 
						           |pl = 'Usuwanie typu ""%1"" jest niedozwolone,
						           |poniewa?? dodatkowe warto??ci zosta??y ju?? wprowadzone.
						           |Najpierw nale??y usun???? wprowadzone warto??ci dodatkowe.
						           |
						           |Usuni??ty typ zosta?? odzyskany.';
						           |es_ES = 'No se puede borrar el tipo ""%1"",
						           |porque los valores adicionales de este tipo no se han encontrado.
						           |Borrar todos los valores adicionales antes de borrar el tipo.
						           |
						           |Tipo eliminado restablecido.';
						           |es_CO = 'No se puede borrar el tipo ""%1"",
						           |porque los valores adicionales de este tipo no se han encontrado.
						           |Borrar todos los valores adicionales antes de borrar el tipo.
						           |
						           |Tipo eliminado restablecido.';
						           |tr = '"
" t??r??n ek de??erleri bulundu??undan "" %1 "" t??r??n?? silemezsiniz. 
						           | T??r?? silmeden ??nce t??m ek de??erleri silin.
						           |
						           |Silinen t??r geri y??klendi.';
						           |it = 'Impossibile eliminare il tipo %1
						           |dato che valori aggiuntivi sono gi?? stati inseriti.
						           |Eliminare prima di tutti i valori aggiuntivi che avete inserito.
						           |
						           |Il tipo eliminato ?? stato ripristinato.';
						           |de = 'L??schen Sie den Typ ""%1"" nicht,
						           |da bereits zus??tzliche Werte eingegeben wurden.
						           |Zun??chst m??ssen die eingegebenen zus??tzlichen Werte gel??scht werden.
						           |
						           |Der gel??schte Typ wird wiederhergestellt.'"),
						String(Type("CatalogRef.ObjectPropertyValueHierarchy")) );
					
					Object.ValueType = New TypeDescription(
						Object.ValueType,
						"CatalogRef.ObjectPropertyValueHierarchy",
						"CatalogRef.ObjectsPropertiesValues");
				
				ElsIf OldValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
				        AND NOT Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
					
					WarningText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = '?????????????????????? ?????????????? ?????? ""%1"",
						           |?????? ?????? ???????????????????????????? ???????????????? ?????? ??????????????.
						           |?????????????? ?????????? ?????????????? ?????????????????? ???????????????????????????? ????????????????.
						           |
						           |?????????????????? ?????? ????????????????????????.'; 
						           |en = 'Cannot delete the %1 type
						           |as additional values are entered already.
						           |Delete additional values you entered first.
						           |
						           |Deleted type is restored.'; 
						           |pl = 'Usuwanie typu ""%1"" jest niedozwolone,
						           |poniewa?? dodatkowe warto??ci zosta??y ju?? wprowadzone.
						           |Najpierw nale??y usun???? wprowadzone warto??ci dodatkowe.
						           |
						           |Usuni??ty typ zosta?? odzyskany.';
						           |es_ES = 'No se puede borrar el tipo ""%1"",
						           |porque los valores adicionales de este tipo no se han encontrado.
						           |Borrar todos los valores adicionales antes de borrar el tipo.
						           |
						           |Tipo eliminado restablecido.';
						           |es_CO = 'No se puede borrar el tipo ""%1"",
						           |porque los valores adicionales de este tipo no se han encontrado.
						           |Borrar todos los valores adicionales antes de borrar el tipo.
						           |
						           |Tipo eliminado restablecido.';
						           |tr = '"
" t??r??n ek de??erleri bulundu??undan "" %1 "" t??r??n?? silemezsiniz. 
						           | T??r?? silmeden ??nce t??m ek de??erleri silin.
						           |
						           |Silinen t??r geri y??klendi.';
						           |it = 'Impossibile eliminare il tipo %1
						           |dato che valori aggiuntivi sono gi?? stati inseriti.
						           |Eliminare prima di tutti i valori aggiuntivi che avete inserito.
						           |
						           |Il tipo eliminato ?? stato ripristinato.';
						           |de = 'L??schen Sie den Typ ""%1"" nicht,
						           |da bereits zus??tzliche Werte eingegeben wurden.
						           |Zun??chst m??ssen die eingegebenen zus??tzlichen Werte gel??scht werden.
						           |
						           |Der gel??schte Typ wird wiederhergestellt.'"),
						String(Type("CatalogRef.ObjectsPropertiesValues")) );
					
					Object.ValueType = New TypeDescription(
						Object.ValueType,
						"CatalogRef.ObjectsPropertiesValues",
						"CatalogRef.ObjectPropertyValueHierarchy");
				EndIf;
			EndIf;
		EndIf;
		
		// Checking that not more than one additional value type is set.
		If Object.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy"))
		   AND Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
			
			If NOT OldValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
				
				WarningText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '?????????????????????? ???????????????????????? ???????????????????????? ???????? ????????????????
					           |""%1"" ??
					           |""%2"".
					           |
					           |???????????? ?????? ????????????.'; 
					           |en = 'Cannot use the
					           |""%1"" and
					           |""%2"" value types at the same time.
					           |
					           |The second type is deleted.'; 
					           |pl = 'Jednoczesne wykorzystywanie typ??w warto??ci
					           |""%1"" i
					           |""%2"" jest niedozwolone.
					           |
					           |Drugi typ zosta?? usuni??ty.';
					           |es_ES = 'No se admite usar simult??neamente los tipos del valor
					           |""%1"" y
					           |""%2"".
					           |
					           |El segundo tipo se ha eliminado.';
					           |es_CO = 'No se admite usar simult??neamente los tipos del valor
					           |""%1"" y
					           |""%2"".
					           |
					           |El segundo tipo se ha eliminado.';
					           |tr = 'Ayn?? zamanda 
					           |""%1"" ve
					           |""%2"".
					           |
					           | de??erin tipleri kullan??lamaz. ??kinci tip silindi.';
					           |it = 'Non ?? consentito utilizzare i tipi dei valori
					           |""%1"" e ""%2""
					           |contemporaneamente.
					           |
					           |Il secondo tipo ?? stato cancellato.';
					           |de = 'Verwenden Sie nicht gleichzeitig die Werttypen
					           |""%1"" und
					           |""%2"".
					           |
					           |Der zweite Typ wird gel??scht.'"),
					String(Type("CatalogRef.ObjectsPropertiesValues")),
					String(Type("CatalogRef.ObjectPropertyValueHierarchy")) );
				
				// Deletion of the second type.
				Object.ValueType = New TypeDescription(
					Object.ValueType,
					,
					"CatalogRef.ObjectPropertyValueHierarchy");
			Else
				WarningText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '?????????????????????? ???????????????????????? ???????????????????????? ???????? ????????????????
					           |""%1"" ??
					           |""%2"".
					           |
					           |???????????? ?????? ????????????.'; 
					           |en = 'Cannot use the
					           |""%1"" and
					           |""%2"" value types at the same time.
					           |
					           |The first type is deleted.'; 
					           |pl = 'Jednoczesne wykorzystywanie typ??w warto??ci
					           |""%1"" i
					           |""%2"" jest niedozwolone.
					           |
					           |Pierwszy typ zosta?? usuni??ty.';
					           |es_ES = 'No se admite usar simult??neamente los tipos del valor
					           |""%1"" y
					           |""%2"".
					           |
					           |El primer tipo se ha eliminado.';
					           |es_CO = 'No se admite usar simult??neamente los tipos del valor
					           |""%1"" y
					           |""%2"".
					           |
					           |El primer tipo se ha eliminado.';
					           |tr = 'Ayn?? zamanda 
					           |""%1"" ve
					           |""%2"".
					           |
					           | de??erin tipleri kullan??lamaz. Birinci tip silindi.';
					           |it = 'Non ?? consentito utilizzare i tipi dei valori
					           |""%1"" e ""%2""
					           |contemporaneamente.
					           |
					           |Il primo tipo ?? stato cancellato.';
					           |de = 'Verwenden Sie nicht gleichzeitig die Werttypen
					           |""%1"" und
					           |""%2"".
					           |
					           |Der erste Typ wird gel??scht.'"),
					String(Type("CatalogRef.ObjectsPropertiesValues")),
					String(Type("CatalogRef.ObjectPropertyValueHierarchy")) );
				
				// Deletion of the first type.
				Object.ValueType = New TypeDescription(
					Object.ValueType,
					,
					"CatalogRef.ObjectsPropertiesValues");
			EndIf;
		EndIf;
		
		ValuesOwner = Object.Ref;
		ValuesWithWeight   = Object.AdditionalValuesWithWeight;
	EndIf;
	
	If PropertyManagerInternal.ValueTypeContainsPropertyValues(Object.ValueType) Then
		Items.ValueFormsHeadersGroup.Visible = True;
		Items.AdditionalValuesWithWeight.Visible = True;
		Items.ValuePage.Visible = True;
		Items.Pages.PagesRepresentation = FormPagesRepresentation.TabsOnTop;
	Else
		Items.ValueFormsHeadersGroup.Visible = False;
		Items.AdditionalValuesWithWeight.Visible = False;
		Items.ValuePage.Visible = False;
		Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
	EndIf;
	
	Items.Values.Header        = ValuesWithWeight;
	Items.ValuesWeight.Visible = ValuesWithWeight;
	
	CommonClientServer.SetDynamicListFilterItem(
		Values, "Owner", ValuesOwner, , , True);
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		ListProperties = Common.DynamicListPropertiesStructure();
		ListProperties.MainTable = "Catalog.ObjectsPropertiesValues";
		Common.SetDynamicListProperties(Items.Values,
			ListProperties);
	Else
		ListProperties = Common.DynamicListPropertiesStructure();
		ListProperties.MainTable = "Catalog.ObjectPropertyValueHierarchy";
		Common.SetDynamicListProperties(Items.Values,
			ListProperties);
	EndIf;
	
	// Displaying adjustments.
	
	If NOT ValueIsFilled(Object.AdditionalValuesOwner) Then
		Items.ValueListAdjustment.Visible = False;
		Items.AdditionalValues.ReadOnly = False;
		Items.ValuesEditingCommandBar.Visible = True;
		Items.ValuesEditingContextMenu.Visible = True;
		Items.AdditionalValuesWithWeight.Visible = True;
	Else
		Items.ValueListAdjustment.Visible = True;
		Items.AdditionalValues.ReadOnly = True;
		Items.ValuesEditingCommandBar.Visible = False;
		Items.ValuesEditingContextMenu.Visible = False;
		Items.AdditionalValuesWithWeight.Visible = False;
		
		Items.ValueListAdjustmentComment.Hyperlink = ValueIsFilled(Object.Ref);
		Items.ValueListAdjustmentChange.Enabled    = ValueIsFilled(Object.Ref);
		
		OwnerProperties = Common.ObjectAttributesValues(
			Object.AdditionalValuesOwner, "PropertySet, Title, IsAdditionalInfo");
		
		If OwnerProperties.IsAdditionalInfo <> True Then
			AdjustmentTemplate = NStr("ru = '???????????? ???????????????? ?????????? ?? ???????????????????? ""%1""'; en = 'Value list common with the %1 attribute'; pl = 'Lista warto??ci wsp??lna z atrybutem ""%1""';es_ES = 'Lista com??n de valores con el atributo ""%1""';es_CO = 'Lista com??n de valores con el atributo ""%1""';tr = '""%1"" alana sahip ortak de??er listesi';it = 'Elenco valori comune con l''attributo %1';de = 'Die Werteliste ist allgemein mit den Attributen ""%1"".'");
		Else
			AdjustmentTemplate = NStr("ru = '???????????? ???????????????? ?????????? ???? ?????????????????? ""%1""'; en = 'Value list common with the %1 information'; pl = 'Lista warto??ci wsp??lna z informacj?? ""%1""';es_ES = 'Lista com??n de valores con los datos ""%1""';es_CO = 'Lista com??n de valores con los datos ""%1""';tr = '""%1"" bilgiye sahip ortak de??er listesi';it = 'Elenco valori comune con le informazioni %1';de = 'Die Werteliste ist allgemein mit den Informationen ""%1"".'");
		EndIf;
		
		If ValueIsFilled(OwnerProperties.PropertySet) Then
			AdjustmentTemplateSet = " " + NStr("ru = '???????????? ""%1""'; en = 'of the ""%1"" set'; pl = 'zestawu ""%1""';es_ES = 'del conjunto ""%1""';es_CO = 'del conjunto ""%1""';tr = '""%1"" k??mesinin';it = 'dell''insieme ""%1""';de = 'Set ""%1""'");
			AdjustmentTemplateSet = StringFunctionsClientServer.SubstituteParametersToString(AdjustmentTemplateSet, String(OwnerProperties.PropertySet));
		Else
			AdjustmentTemplateSet = "";
		EndIf;
		
		Items.ValueListAdjustmentComment.Title =
			StringFunctionsClientServer.SubstituteParametersToString(AdjustmentTemplate, OwnerProperties.Title)
			+ AdjustmentTemplateSet + "  ";
	EndIf;
	
	RefreshSetsList();
	
	If NOT ShowSetAdjustment
	   AND ValueIsFilled(Object.PropertySet)
	   AND SetsList.Count() < 2 Then
		
		Items.SetsAdjustment.Visible = False;
	Else
		Items.SetsAdjustment.Visible = True;
		Items.SetsAdjustmentComment.Hyperlink = True;
		
		Items.SetsAdjustmentChange.Enabled = ValueIsFilled(Object.Ref);
		
		If ValueIsFilled(Object.PropertySet)
		   AND SetsList.Count() < 2 Then
			
			Items.SetsAdjustmentChange.Visible = False;
		
		ElsIf ValueIsFilled(CurrentPropertiesSet) Then
			Items.SetsAdjustmentChange.Visible = True;
		Else
			Items.SetsAdjustmentChange.Visible = False;
		EndIf;
		
		If SetsList.Count() > 0 Then
		
			If ValueIsFilled(Object.PropertySet)
			   AND SetsList.Count() < 2 Then
				
				If Object.IsAdditionalInfo Then
					AdjustmentTemplate = NStr("ru = '???????????????? ???????????? ?? ??????????: %1'; en = 'The information is included in set: %1'; pl = 'Dane s?? zawarte w zestawie: %1';es_ES = 'Datos est?? incluido en el conjunto: %1';es_CO = 'Datos est?? incluido en el conjunto: %1';tr = 'Verinin dahil oldu??u k??me: %1';it = 'L''informazione ?? inclusa nell''insieme: %1';de = 'Daten sind im Satz enthalten: %1'");
				Else
					AdjustmentTemplate = NStr("ru = '???????????????? ???????????? ?? ??????????: %1'; en = 'The attribute is included in set: %1'; pl = 'Atrybut nale??y do zestawu: %1';es_ES = 'El atributo pertenece al conjunto: %1';es_CO = 'El atributo pertenece al conjunto: %1';tr = '??zelli??in ait oldu??u k??me: %1';it = 'L''attributo ?? incluso nell''insieme: %1';de = 'Das Attribut geh??rt zu dem Satz: %1'");
				EndIf;
				CommentText = StringFunctionsClientServer.SubstituteParametersToString(AdjustmentTemplate, TrimAll(SetsList[0].Presentation));
			Else
				If SetsList.Count() > 1 Then
					If Object.IsAdditionalInfo Then
						AdjustmentTemplate = NStr("ru = '?????????? ???????????????? ???????????? ?? %1 %2'; en = 'The common information is included in %1 %2'; pl = 'Informacje og??lne s?? zawarte w %1 %2';es_ES = 'Informaci??n com??n est?? incluida en %1 %2';es_CO = 'Informaci??n com??n est?? incluida en %1 %2';tr = 'Ortak bilgiler %1 %2''e dahil edildi';it = 'L''informazione comune ?? inclusa in %1 %2';de = 'Gemeinsame Informationen sind enthalten in %1 %2'");
					Else
						AdjustmentTemplate = NStr("ru = '?????????? ???????????????? ???????????? ?? %1 %2'; en = 'The common attribute is included in %1 %2'; pl = 'Wsp??lny atrybut zawarty jest w %1 %2';es_ES = 'Atributo com??n est?? incluido en %1 %2';es_CO = 'Atributo com??n est?? incluido en %1 %2';tr = 'Ortak ??zellik %1 %2''e dahil edildi';it = 'L''attributo comune ?? incluso in %1 %2';de = 'Das gemeinsame Attribut ist enthalten in %1 %2'");
					EndIf;
					
					StringSets = UsersInternalClientServer.IntegerSubject(SetsList.Count(),
						"", NStr("ru = '??????????,????????????,??????????????,,,,,,0'; en = 'set, sets, sets,,,,,,0'; pl = 'zestaw,zestawu,zestaw??w,,,,,,0';es_ES = 'conjunto,del conjunto, de los conjuntos,,,,,,0';es_CO = 'conjunto,del conjunto, de los conjuntos,,,,,,0';tr = 'k??me, k??meler, k??meler,,,,,,0';it = 'insieme, insiemi, insiemi,,,,,,0';de = 'Set,des Set,Sets,,,,,0'"));
					
					CommentText = StringFunctionsClientServer.SubstituteParametersToString(AdjustmentTemplate, Format(SetsList.Count(), "NG="), StringSets);
				Else
					If Object.IsAdditionalInfo Then
						AdjustmentTemplate = NStr("ru = '?????????? ???????????????? ???????????? ?? ??????????: %1'; en = 'The common information is included in set: %1'; pl = 'Wsp??lne informacje s?? zawarte w zestawie: %1';es_ES = 'Informaci??n com??n est?? incluida en el conjunto: %1';es_CO = 'Informaci??n com??n est?? incluida en el conjunto: %1';tr = 'Ortak bilgilerin dahil edildi??i k??me: %1';it = 'L''informazione comune ?? inclusa nell''insieme: %1';de = 'Allgemeine Informationen sind im Satz enthalten: %1'");
					Else
						AdjustmentTemplate = NStr("ru = '?????????? ???????????????? ???????????? ?? ??????????: %1'; en = 'The common attribute is included in set: %1'; pl = 'Wsp??lny atrybut jest zawarty w zestawie: %1';es_ES = 'Atributo com??n est?? incluido en el conjunto: %1';es_CO = 'Atributo com??n est?? incluido en el conjunto: %1';tr = 'Ortak ??zniteli??in dahil oldu??u k??me: %1';it = 'L''attributo comune ?? incluso nell''insieme: %1';de = 'Gemeinsames Attribut ist im Satz enthalten: %1'");
					EndIf;
					
					CommentText = StringFunctionsClientServer.SubstituteParametersToString(AdjustmentTemplate, TrimAll(SetsList[0].Presentation));
				EndIf;
			EndIf;
		Else
			Items.SetsAdjustmentComment.Hyperlink = False;
			Items.SetsAdjustmentChange.Visible = False;
			
			If ValueIsFilled(Object.PropertySet) Then
				If Object.IsAdditionalInfo Then
					CommentText = NStr("ru = '???????????????? ???? ???????????? ?? ??????????'; en = 'The information is not included in the set'; pl = 'Dane nie s?? zawarte w zestawie';es_ES = 'Datos no est??n incluido en el conjunto';es_CO = 'Datos no est??n incluido en el conjunto';tr = 'Veri k??meye dahil edilmedi';it = 'L''informazione non ?? inclusa nell''insieme';de = 'Daten sind nicht im Set enthalten'");
				Else
					CommentText = NStr("ru = '???????????????? ???? ???????????? ?? ??????????'; en = 'The attribute is not used in the set'; pl = 'Atrybut nie nale??y do zestawu';es_ES = 'El atributo no pertenece al conjunto';es_CO = 'El atributo no pertenece al conjunto';tr = '??zellik k??meye dahil edilmedi';it = 'Attributo non utilizzato nel set';de = 'Das Attribut geh??rt nicht zum Satz'");
				EndIf;
			Else
				If Object.IsAdditionalInfo Then
					CommentText = NStr("ru = '?????????? ???????????????? ???? ???????????? ?? ????????????'; en = 'The common information is not included in sets'; pl = 'Wsp??lne informacje nie s?? zawarte w zestawach';es_ES = 'Informaci??n com??n no est?? incluida en los conjuntos';es_CO = 'Informaci??n com??n no est?? incluida en los conjuntos';tr = 'Ortak bilgi k??melere dahil edilmedi';it = 'L''informazione comune non ?? inclusa negli insiemi';de = 'Allgemeine Informationen sind nicht in S??tzen enthalten'");
				Else
					CommentText = NStr("ru = '?????????? ???????????????? ???? ???????????? ?? ????????????'; en = 'The common attribute is not used in sets'; pl = 'Wsp??lny atrybut nie wchodzi w sk??ad zestaw??w';es_ES = 'El requisito com??n no se incluye en los conjuntos';es_CO = 'El requisito com??n no se incluye en los conjuntos';tr = 'Ortak ??znitelik k??meye dahil edilmedi';it = 'L''attributo comune non ?? utilizzato nei set';de = 'Allgemeine Attribute sind nicht in den Sets enthalten'");
				EndIf;
			EndIf;
		EndIf;
		
		Items.SetsAdjustmentComment.Title = CommentText + " ";
		
		If Items.SetsAdjustmentComment.Hyperlink Then
			Items.SetsAdjustmentComment.ToolTip = NStr("ru = '?????????????? ?? ????????????'; en = 'Go to set'; pl = 'Przejd?? do zestawu';es_ES = 'Ir al conjunto';es_CO = 'Ir al conjunto';tr = 'K??meye git';it = 'Vai ad impostare';de = 'Gehe zum Satz'");
		Else
			Items.SetsAdjustmentComment.ToolTip = "";
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure SwitchAttributeDisplaySettings(ValueType)
	
	AllowMultilineFieldSelection = (Object.ValueType.Types().Count() = 1)
		AND (Object.ValueType.ContainsType(Type("String")));
	AllowDisplayAsHyperlink   = AllowMultilineFieldSelection
		Or (Not Object.ValueType.ContainsType(Type("String"))
			AND Not Object.ValueType.ContainsType(Type("Date"))
			AND Not Object.ValueType.ContainsType(Type("Boolean"))
			AND Not Object.ValueType.ContainsType(Type("Number")));
	
	Items.SingleLineKind.Visible                       = AllowMultilineFieldSelection;
	Items.MultilineInputFieldGroupSettings.Visible = AllowMultilineFieldSelection;
	Items.OutputAsHyperlink.Visible              = AllowDisplayAsHyperlink;
	
EndProcedure

&AtServer
Procedure ClearEnteredWeightCoefficients()
	
	If Object.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues")) Then
		ValueTableName = "Catalog.ObjectsPropertiesValues";
	Else
		ValueTableName = "Catalog.ObjectPropertyValueHierarchy";
	EndIf;
	
	Lock = New DataLock;
	LockItem = Lock.Add(ValueTableName);
	
	BeginTransaction();
	Try
		Lock.Lock();
		Query = New Query;
		Query.Text =
		"SELECT
		|	CurrentTable.Ref AS Ref
		|FROM
		|	Catalog.ObjectsPropertiesValues AS CurrentTable
		|WHERE
		|	CurrentTable.Weight <> 0";
		Query.Text = StrReplace(Query.Text , "Catalog.ObjectsPropertiesValues", ValueTableName);
		
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			ValueObject = Selection.Ref.GetObject();
			ValueObject.Weight = 0;
			ValueObject.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServer
Procedure RefreshSetsList()
	
	SetsList.Clear();
	
	If ValueIsFilled(Object.Ref) Then
		
		Query = New Query(
		"SELECT
		|	AdditionalAttributes.Ref AS Set,
		|	AdditionalAttributes.Ref.Description
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS AdditionalAttributes
		|WHERE
		|	AdditionalAttributes.Property = &Property
		|	AND NOT AdditionalAttributes.Ref.IsFolder
		|
		|UNION ALL
		|
		|SELECT
		|	AdditionalInfo.Ref,
		|	AdditionalInfo.Ref.Description
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo AS AdditionalInfo
		|WHERE
		|	AdditionalInfo.Property = &Property
		|	AND NOT AdditionalInfo.Ref.IsFolder");
		
		Query.SetParameter("Property", Object.Ref);
		
		BeginTransaction();
		Try
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				SetsList.Add(Selection.Set, Selection.Description + "         ");
			EndDo;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangePage(Direction, MainPage, CurrentPage)
	
	MainPage.CurrentPage = CurrentPage;
	If CurrentPage = Items.ActionChoice Then
		If Direction = "Forward" Then
			SelectedItem = Items.Properties.CurrentData;
			PassedFormParameters.AdditionalValuesOwner = SelectedItem.Property;
			FillActionListOnAddAttribute();
		EndIf;
	ElsIf CurrentPage = Items.AttributeCard Then
		FillAttributeOrInfoCard();
	EndIf;
	
EndProcedure

&AtServer
Function IsCommonAdditionalAttribute(SelectedItem)
	AttributePropertiesSet = Common.ObjectAttributesValues(SelectedItem, "PropertySet");
	Return Not ValueIsFilled(AttributePropertiesSet.PropertySet);
EndFunction

&AtServer
Function AttributeWithAdditionalValuesList()
	
	AttributeWithAdditionalValuesList = True;
	OwnerProperties = Common.ObjectAttributesValues(
		PassedFormParameters.AdditionalValuesOwner, "ValueType");
	If Not OwnerProperties.ValueType.ContainsType(Type("CatalogRef.ObjectsPropertiesValues"))
		AND Not OwnerProperties.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
		AttributeWithAdditionalValuesList = False;
	EndIf;
	
	Return AttributeWithAdditionalValuesList;
EndFunction

&AtServer
Procedure FillActionListOnAddAttribute()
	
	IsCommonAdditionalAttribute = IsCommonAdditionalAttribute(PassedFormParameters.AdditionalValuesOwner);
	UseCommonAdditionalValues = GetFunctionalOption("UseCommonAdditionalValues");
	UseAdditionalCommonAttributesAndInfo = GetFunctionalOption("UseAdditionalCommonAttributesAndInfo");
	
	AttributeWithAdditionalValuesList = AttributeWithAdditionalValuesList();
	
	If PassedFormParameters.IsAdditionalInfo Then
		AddCommon = NStr("ru = '???????????????? ?????????? ???????????????? ?? ?????????? (??????????????????????????)
			|
			|?????????????????? ???????????????? ?????? ???????????? ?? ?????????????????? ??????????????, ?????????????? ?????????????????????????? ?????????? ???????????????? ?????? ?? ???????? ?????????? ""?????? ????????"".
			|?? ???????? ???????????? ?????????? ???????????????? ???????????????? ???? ???????? ???????????? ???????????? ?????????? ?? ?????????????? ?? ??????????????.'; 
			|en = 'Add common information to the set (recommended)
			|
			|The selected information is already included in several sets. That is way it is recommended that you include it in this set ""as it is"".
			|In such case, you will be able to filter data of different types by it in lists and reports.'; 
			|pl = 'Dodaj wsp??ln?? informacj?? do zestawu (zalecane) 
			|
			|Wybrana informacja wchodzi ju?? w sk??ad kilku zestaw??w, dlatego jest zalecane w????czenie do r??wnie?? do tego zestawu ""tak jak jest"".
			|W tym wypadku b??dzie mo??liwy wyb??r wed??ug niej danych r????nych typ??w w listach i sprawozdaniach.';
			|es_ES = 'A??adir la informaci??n com??n en el conjunto (se recomienda)
			|
			| La informaci??n seleccionada ya forma parte de unos conjuntos por eso se recomienda tambi??n incluirlo en este conjunto ""como es"".
			|En este caso ser?? posible seleccionar los datos de diferentes tipos en las listas e informes.';
			|es_CO = 'A??adir la informaci??n com??n en el conjunto (se recomienda)
			|
			| La informaci??n seleccionada ya forma parte de unos conjuntos por eso se recomienda tambi??n incluirlo en este conjunto ""como es"".
			|En este caso ser?? posible seleccionar los datos de diferentes tipos en las listas e informes.';
			|tr = 'Bir k??meye ortak bilgi ekle (??nerilen) 
			|
			|Se??ilen ayr??nt?? zaten birka?? k??meye girer, bu nedenle bu k??meye ""oldu??u gibi"" de dahil etmeniz ??nerilir.
			|Bu durumda, listelerde ve raporlarda farkl?? t??rde verileri se??mek m??mk??nd??r.';
			|it = 'Aggiungere informazioni comuni al set (consigliato)
			|
			|Le informazioni selezionate sono gi?? incluse in diversi set. Si consiglia di includerle in questo set ""cos?? come sono"".
			|In questo caso, sar?? possibile filtrare dati di tipi diversi in base a tali informazioni in elenchi e report.';
			|de = 'Hinzuf??gen einer allgemeinen Information zum Set (empfohlen)
			|
			|Die ausgew??hlte Information ist bereits in mehreren Sets enthalten, daher wird empfohlen, sie auch in diesem Set ""so wie sie ist"" aufzunehmen.
			|In diesem Fall wird es m??glich sein, Daten unterschiedlicher Art in Listen und Berichten auszuw??hlen.'");
		MakeCommon = NStr("ru = '?????????????? ???????????????????????????? ???????????????? ?????????? ?? ???????????????? ?? ??????????
			|
			|???????? ?????????????? ???????????????? ?????? ?????? ??????????????, ?????????? ???????????????? ???????????? ???????? ?????????????????? ?????? ?????????? ??????????????.
			|?? ???????? ???????????? ?????????? ???????????????? ???????????????? ???? ???????? ???????????? ???????????? ?????????? ?? ?????????????? ?? ??????????????.'; 
			|en = 'Make additional information common and add it to the set
			|
			|This option is suitable when information is to be the same for both sets.
			|In such case, you will be able to filter data of different types by it in lists and reports.'; 
			|pl = 'Okre??l dodatkow?? informacj?? jako wsp??ln?? i dodaj do zestawu
			|
			|Ten wariant jest odpowiedni dla tych sytuacji, kiedy informacja musi by?? jednakowa dla obu zestaw??w.
			|W tym przypadku b??dzie mo??liwy wyb??r wed??ug niej kilku danych r????nych typ??w w listach i sprawozdaniach.';
			|es_ES = 'Hacer la informaci??n adicional como com??n y a??adirla en el conjunto
			|
			|Esta variante es conveniente para los casos cuando la informaci??n debe ser la misma para ambos conjuntos.
			|En este caso ser?? posible seleccionar los datos de diferentes tipos en las listas e informes.';
			|es_CO = 'Hacer la informaci??n adicional como com??n y a??adirla en el conjunto
			|
			|Esta variante es conveniente para los casos cuando la informaci??n debe ser la misma para ambos conjuntos.
			|En este caso ser?? posible seleccionar los datos de diferentes tipos en las listas e informes.';
			|tr = 'Ek bilgiyi ortak yap ve 
			|
			| k??meye ekle. Bu se??enek, her iki k??me i??in de ayn?? olmas?? gereken durumlar i??in uygundur.
			|Bu durumda, listelerde ve raporlarda farkl?? t??rde verileri se??mek m??mk??nd??r.';
			|it = 'Rendere comuni le informazioni aggiuntive e aggiungerle al set
			|
			|Questa opzione ?? utile quando le informazioni devono essere le stesse per entrambi i set.
			|In tal caso, sar?? possibile filtrare i dati di tipi diversi in base a queste informazioni in elenchi e report.';
			|de = 'Zusatzinformationen allgemein machen und zum Set hinzuf??gen
			|
			|Diese Option ist f??r die F??lle geeignet, in denen die Informationen f??r beide Sets gleich sein sollten.
			|In diesem Fall wird es m??glich sein, Daten unterschiedlicher Art aus Listen und Berichten auszuw??hlen.'");
		MakeBySample = NStr("ru = '?????????????? ?????????? ???????????????? ???? ?????????????? (?? ?????????? ?????????????? ????????????????)
			|
			|???????????? ???????????????? ?????????? ???????????????? ?????????? ???????????????? ?????? ?????????? ??????????????.
			|?? ?????????????? ?????????? ???????????????? ???????????? ?????????????????? ???????????????????????????????? ?????????????????? ???????????? ???????????????? ?????????? ?????? ???????????????????? ???????????????????? ????????????????.
			|?????? ???????? ?????????? ?????????????????????????????? ???????????????????????? ?? ?????? ???????????? ?????????????? ????????????????.'; 
			|en = 'Copy information by sample (with common value list)
			|
			|The value list of this information will be the same for both sets.
			|With this option, you can configure the value list for information of the same type with a single action.
			|You can edit description and some other information properties.'; 
			|pl = 'Utw??rz kopi?? informacji wed??ug wzoru (ze wsp??ln?? list?? warto??ci)
			|
			|Lista warto??ci tej informacji b??dzie jednakowa dla obu zestaw??w.
			|Przy pomocy tego wariantu mo??na wygodnie wykonywa?? scentralizowan?? konfiguracj?? listy warto??ci od razu dla kilku informacji tego samego typu.
			|Przy czym jest mo??liwa edycja nazw i wielu innych w??a??ciwo??ci informacji.';
			|es_ES = 'Hacer la copia de respaldo seg??n el modelo (con lista com??n de valores)
			|
			|La lista de valores de esta informaci??n ser?? igual para ambos conjuntos.
			|Con esta variante es m??s c??modo realizar el ajuste centralizado de la lista de valores para unos tipos de informaci??n de un tipo.
			|As?? se puede editar el nombre y otras propiedades de informaci??n.';
			|es_CO = 'Hacer la copia de respaldo seg??n el modelo (con lista com??n de valores)
			|
			|La lista de valores de esta informaci??n ser?? igual para ambos conjuntos.
			|Con esta variante es m??s c??modo realizar el ajuste centralizado de la lista de valores para unos tipos de informaci??n de un tipo.
			|As?? se puede editar el nombre y otras propiedades de informaci??n.';
			|tr = '??rnek bilgileri (ortak bir de??er listesi ile) bir kopyas??n?? yap 
			|
			| Bu bilgilerin de??er listesi her iki k??me i??in de ayn?? olacakt??r.
			|Bu se??enek, birden ??ok tek tip bilgi i??in bir kerede merkezi bir de??er listesi ayar??n?? yapmak i??in kullan????l??d??r.
			|Bu durumda, bilginin ad?? ve di??er ??zelliklerini d??zenleyebilirsiniz.';
			|it = 'Copiare informazioni per campione (con elenco valori comune)
			|
			|L''elenco valori di queste informazioni sar?? lo stesso per entrambi i set.
			|Con questa opzione sar?? possibile configurare l''elenco valori per informazioni dello stesso tipo con una singola azione.
			|Sar?? possibile modificare la descrizione e altre propriet?? di informazione.';
			|de = 'Machen Sie eine Kopie der Informationen nach dem Muster (mit der allgemeinen Werteliste)
			|
			|Die Werteliste dieser Informationen ist f??r beide Sets gleich.
			|Diese Option erleichtert die zentrale Konfiguration der Werteliste f??r mehr als eine Art von Informationen gleichzeitig.
			|Sie k??nnen den Namen und andere Eigenschaften der Informationen bearbeiten.'");
		CreateByCopying = NStr("ru = '?????????????? ?????????? ????????????????
			|
			|?????????? ?????????????? ?????????? ????????????????%1'; 
			|en = 'Copy information
			|
			|Copy of the %1 information will be created'; 
			|pl = 'Utw??rz kopi?? informacji
			|
			|Zostanie utworzona kopia informacji%1';
			|es_ES = 'Hacer la copia de informaci??n
			|
			|Ser?? creada una copia de informaci??n %1';
			|es_CO = 'Hacer la copia de informaci??n
			|
			|Ser?? creada una copia de informaci??n %1';
			|tr = 'Bilgiyi kopyala
			|
			|%1 bilgisinin kopyas?? olu??turulacak';
			|it = 'Copiare informazioni
			|
			|Sar?? creata una copia dell''informazione %1';
			|de = 'Eine Kopie der Informationen erstellen
			|
			|Eine Kopie der Informationen wird erstellt%1'");
	Else
		AddCommon = NStr("ru = '???????????????? ?????????? ???????????????? ?? ?????????? (??????????????????????????)
			|
			|?????????????????? ???????????????? ?????? ???????????? ?? ?????????????????? ??????????????, ?????????????? ?????????????????????????? ?????????? ???????????????? ?????? ?? ???????? ?????????? ""?????? ????????"".
			|?? ???????? ???????????? ?????????? ???????????????? ???????????????? ???? ???????? ???????????? ???????????? ?????????? ?? ?????????????? ?? ??????????????.'; 
			|en = 'Add common attribute to set (recommended)
			|
			|The selected attribute is already included in several sets. That is way it is recommended that you include it in this set ""as it is"".
			|In such case, you will be able to filter data of different types by it in lists and reports.'; 
			|pl = 'Dodaj wsp??lny atrybut do zestawu (zalecane) 
			|
			|Wybrany atrybut wchodzi ju?? w sk??ad kilku zestaw??w, dlatego jest zalecane w????czenie do r??wnie?? do tego zestawu ""tak jak jest"".
			|W tym wypadku b??dzie mo??liwy wyb??r wed??ug niego danych r????nych typ??w w listach i sprawozdaniach.';
			|es_ES = 'A??adir el requisito com??n en el conjunto (se recomienda)
			|
			| El requisito seleccionado ya forma parte de unos conjuntos por eso se recomienda tambi??n incluirlo en este conjunto ""como es"".
			|En este caso ser?? posible seleccionar los datos de diferentes tipos en las listas e informes.';
			|es_CO = 'A??adir el requisito com??n en el conjunto (se recomienda)
			|
			| El requisito seleccionado ya forma parte de unos conjuntos por eso se recomienda tambi??n incluirlo en este conjunto ""como es"".
			|En este caso ser?? posible seleccionar los datos de diferentes tipos en las listas e informes.';
			|tr = 'Bir k??meye ortak ??zellik ekle (??nerilen) 
			|
			|Se??ilen ayr??nt?? zaten birka?? k??meye girer, bu nedenle bu k??meye ""oldu??u gibi"" de dahil etmeniz ??nerilir.
			|Bu durumda, listelerde ve raporlarda farkl?? t??rde verileri se??mek m??mk??nd??r.';
			|it = 'Aggiungere attributo comune a set (consigliato)
			|
			|L''attributo selezionato ?? gi?? incluso in diversi set. Si consiglia di includerlo in questo set ""cos?? com''??"".
			|In questo caso, sar?? possibile filtrare i dati di tipi diversi in base ad esso in elenchi e report.';
			|de = 'Hinzuf??gen eines allgemeinen Attributs zum Set (empfohlen)
			|
			|Das ausgew??hlte Attribut ist bereits in mehreren Sets enthalten, daher wird empfohlen, sie auch in diesem Set ""so wie sie ist"" aufzunehmen.
			|In diesem Fall wird es m??glich sein, Daten unterschiedlicher Art in Listen und Berichten auszuw??hlen.'");
		MakeCommon = NStr("ru = '?????????????? ???????????????? ?????????? ?? ???????????????? ?? ??????????
			|
			|???????? ?????????????? ???????????????? ?????? ?????? ??????????????, ?????????? ???????????????? ???????????? ???????? ???????????????? ?????? ?????????? ??????????????.
			|?? ???????? ???????????? ?????????? ???????????????? ???????????????? ???? ???????? ???????????? ???????????? ?????????? ?? ?????????????? ?? ??????????????.'; 
			|en = 'Make attribute common and add it to set
			|
			|This option is suitable when the attribute is to be the same for both sets.
			|In such case, you will be able to filter data of different types by it in lists and reports.'; 
			|pl = 'Okre??l dodatkowy atrybut jako wsp??lny i dodaj do zestawu
			|
			|Ten wariant jest odpowiedni dla tych sytuacji, kiedy atrybut musi by?? jednakowy dla obu zestaw??w.
			|W tym przypadku b??dzie mo??liwy wyb??r wed??ug niego danych r????nych typ??w w listach i sprawozdaniach.';
			|es_ES = 'Hacer el requisito adicional como com??n y a??adirlo en el conjunto
			|
			|Esta variante es conveniente para los casos cuando el requisito debe ser el mismo para ambos conjuntos.
			|En este caso ser?? posible seleccionar los datos de diferentes tipos en las listas e informes.';
			|es_CO = 'Hacer el requisito adicional como com??n y a??adirlo en el conjunto
			|
			|Esta variante es conveniente para los casos cuando el requisito debe ser el mismo para ambos conjuntos.
			|En este caso ser?? posible seleccionar los datos de diferentes tipos en las listas e informes.';
			|tr = 'Ek ??zelli??i ortak yap ve 
			|
			| k??meye ekle. Bu se??enek, ??zelli??in her iki k??me i??in de ayn?? olmas?? gereken durumlar i??in uygundur.
			|Bu durumda, listelerde ve raporlarda farkl?? t??rde verileri se??mek m??mk??nd??r.';
			|it = 'Rendere attributo comune e aggiungerlo al set
			|
			|Questa opzione ?? indicata quando l''attributo ?? lo stesso per entrambi i set.
			|In tal caso, sar?? possibile filtrare dati di tipo diverso in base ad esso in elenchi e report.';
			|de = 'Zusatzinattribute allgemein machen und zum Set hinzuf??gen
			|
			|Diese Option ist f??r die F??lle geeignet, in denen die Attribute f??r beide Sets gleich sein sollten.
			|In diesem Fall wird es m??glich sein, Daten unterschiedlicher Art aus Listen und Berichten auszuw??hlen.'");
		MakeBySample = NStr("ru = '?????????????? ?????????? ?????????????????? ???? ?????????????? (?? ?????????? ?????????????? ????????????????)
			|
			|???????????? ???????????????? ?????????? ?????????????????? ?????????? ???????????????? ?????? ?????????? ??????????????.
			|?? ?????????????? ?????????? ???????????????? ???????????? ?????????????????? ???????????????????????????????? ?????????????????? ???????????? ???????????????? ?????????? ?????? ???????????????????? ???????????????????? ????????????????????.
			|?????? ???????? ?????????? ?????????????????????????????? ???????????????????????? ?? ?????? ???????????? ?????????????? ??????????????????.'; 
			|en = 'Copy attribute by sample (with common value list)
			|
			|The value list of this attribute will be the same for both sets.
			|With this option, you can configure the value list for several attributes of the same type with a single action.
			|You can edit description and some other attribute properties.'; 
			|pl = 'Utw??rz kopi?? atrybutu wed??ug wzoru (ze wsp??ln?? list?? warto??ci)
			|
			|Lista warto??ci tego atrybutu b??dzie jednakowa dla obu zestaw??w.
			|Przy pomocy tego wariantu mo??na wygodnie wykonywa?? scentralizowan?? konfiguracj?? listy warto??ci od razu dla kilku atrybut??w tego samego typu.
			|Przy czym jest mo??liwa edycja nazw i wielu innych w??a??ciwo??ci atrybutu.';
			|es_ES = 'Hacer la copia de respaldo del requisito seg??n el modelo (con lista com??n de valores)
			|
			|La lista de valores de este requisito ser?? igual para ambos conjuntos.
			|Con esta variante es m??s c??modo realizar el ajuste centralizado de la lista de valores para unos tipos de requisitos de un tipo.
			|As?? se puede editar el nombre y otras propiedades de informaci??n.';
			|es_CO = 'Hacer la copia de respaldo del requisito seg??n el modelo (con lista com??n de valores)
			|
			|La lista de valores de este requisito ser?? igual para ambos conjuntos.
			|Con esta variante es m??s c??modo realizar el ajuste centralizado de la lista de valores para unos tipos de requisitos de un tipo.
			|As?? se puede editar el nombre y otras propiedades de informaci??n.';
			|tr = '??rnek ??zelli??in (ortak bir de??er listesi ile) bir kopyas??n?? yap 
			|
			| Bu ??zelli??in de??erleri listesi her iki k??me i??in de ayn?? olacakt??r.
			|Bu se??enek, birden ??ok tek tip ??zellik i??in bir kerede merkezi bir de??er listesi ayar??n?? yapmak i??in kullan????l??d??r.
			|Bu durumda, ??zelli??in ad?? ve di??er ??zelliklerini d??zenleyebilirsiniz.';
			|it = 'Copiare attributo per campione (con elenco valori comune)
			|
			|L''elenco valori di questo attributo sar?? lo stesso per entrambi i set.
			|Con questa opzione ?? possibile configurare l''elenco valori per diversi attributi dello stesso tipo con una singola azione.
			|Sar?? possibile modificare la descrizione e alcune altre propriet?? di attributo.';
			|de = 'Machen Sie eine Kopie der Informationen nach dem Muster (mit der allgemeinen Werteliste)
			|
			|Die Werteliste dieser Attribute ist f??r beide Sets gleich.
			|Diese Option erleichtert die zentrale Konfiguration der Werteliste f??r mehr als eine Art von Attributen gleichzeitig.
			|Sie k??nnen den Namen und andere Eigenschaften der Attribute bearbeiten.'");
		CreateByCopying = NStr("ru = '?????????????? ?????????? ??????????????????
			|
			|?????????? ?????????????? ?????????? ??????????????????%1'; 
			|en = 'Copy attribute
			|
			|Copy of the %1 attribute'; 
			|pl = 'Utw??rz kopi?? atrybutu
			|
			|Zostanie utworzona kopia atrybutu%1';
			|es_ES = 'Hacer la copia del requisito
			|
			|Ser?? creada una copia del requisito%1';
			|es_CO = 'Hacer la copia del requisito
			|
			|Ser?? creada una copia del requisito%1';
			|tr = '
			|
			|??zelli??in kopyas??n?? yap %1??zelli??in';
			|it = 'Copia attributo
			|
			|Copia dell''attributo %1';
			|de = 'Machen Sie eine Kopie der Attribute
			|
			|Eine Kopie der Attribute wird erstellt%1'");
	EndIf;
	
	ChoiceList = Items.AttributeAddMode.ChoiceList;
	ChoiceList.Clear();
	
	If AttributeWithAdditionalValuesList Then
		PasteTemplate = " " + NStr("ru = '?? ???????? ?????? ????????????????.'; en = 'and all its values will be created.'; pl = 'i wszystkich jego warto??ci.';es_ES = 'y de todos sus valores.';es_CO = 'y de todos sus valores.';tr = 've t??m onun de??erlerinin kopyas?? yap??lacak.';it = 'e tutti i suoi valori saranno creati.';de = 'und all seine Bedeutungen werden erstellt.'");
	Else
		PasteTemplate = ".";
	EndIf;
	CreateByCopying = StringFunctionsClientServer.SubstituteParametersToString(CreateByCopying, PasteTemplate);
	
	ChoiceList.Add("CreateByCopying", CreateByCopying);
	
	If UseCommonAdditionalValues AND AttributeWithAdditionalValuesList Then
		ChoiceList.Add("CreateBySample", MakeBySample);
	EndIf;
	
	If UseAdditionalCommonAttributesAndInfo AND IsCommonAdditionalAttribute Then
		ChoiceList.Add("AddCommonAttributeToSet", AddCommon);
	ElsIf UseAdditionalCommonAttributesAndInfo Then
		ChoiceList.Add("MakeCommon", MakeCommon);
	EndIf;
	
	AttributeAddMode = "CreateByCopying";
	
EndProcedure

&AtServer
Procedure WriteAdditionalAttributeValuesOnCopy(CurrentObject)
	
	If CurrentObject.ValueType.ContainsType(Type("CatalogRef.ObjectPropertyValueHierarchy")) Then
		Parent = Catalogs.ObjectPropertyValueHierarchy.EmptyRef();
	Else
		Parent = Catalogs.ObjectsPropertiesValues.EmptyRef();
	EndIf;
	
	Owner = CurrentObject.Ref;
	TreeRow = AdditionalAttributesValues.GetItems();
	WriteAdditionalAttributeValuesOnCopyRecursively(Owner, TreeRow, Parent);
	TreeRow.Clear();
	Items.AttributeValuePages.CurrentPage = Items.AdditionalValues;
	
EndProcedure

&AtServer
Procedure WriteAdditionalAttributeValuesOnCopyRecursively(Owner, TreeRow, Parent)
	
	For Each TreeItem In TreeRow Do
		ObjectCopy = TreeItem.Ref.GetObject().Copy();
		ObjectCopy.Owner = Owner;
		ObjectCopy.Parent = Parent;
		ObjectCopy.Write();
		
		SubordinateItems = TreeItem.GetItems();
		WriteAdditionalAttributeValuesOnCopyRecursively(Owner, SubordinateItems, ObjectCopy.Ref)
	EndDo;
	
EndProcedure

&AtServer
Procedure SetHyperlinkTitles()
	
	AvailabilityDependenceDefined              = False;
	RequiredFillingDependenceDefined = False;
	VisibilityDependenceDefined                = False;
	PropertiesDependencies = Object.AdditionalAttributesDependencies;
	
	For Each PropertyDependence In PropertiesDependencies Do
		If PropertyDependence.DependentProperty = "Available" Then
			AvailabilityDependenceDefined = True;
		ElsIf PropertyDependence.DependentProperty = "RequiredToFill" Then
			RequiredFillingDependenceDefined = True;
		ElsIf PropertyDependence.DependentProperty = "Visible" Then
			VisibilityDependenceDefined = True;
		EndIf;
	EndDo;
	
	TemplateDependenceDefined = NStr("ru = '?????? ???????????????? ??????????????'; en = 'on the specified condition'; pl = 'przy okre??lonym warunku';es_ES = 'con el valor establecido';es_CO = 'con el valor establecido';tr = 'belirlenen ??artlarda';it = 'alla condizione indicata';de = 'vorbehaltlich'");
	TemplateDependenceNotDefined = NStr("ru = '????????????'; en = 'always'; pl = 'zawsze';es_ES = 'siempre';es_CO = 'siempre';tr = 'her zaman';it = 'sempre';de = 'immer'");
	
	Items.SpecifyAvailabilityCondition.Title = ?(AvailabilityDependenceDefined,
		TemplateDependenceDefined,
		TemplateDependenceNotDefined);
	
	Items.SpecifyFillingCondition.Title = ?(RequiredFillingDependenceDefined,
		TemplateDependenceDefined,
		TemplateDependenceNotDefined);
	
	Items.SpecifyVisibilityCondition.Title = ?(VisibilityDependenceDefined,
		TemplateDependenceDefined,
		TemplateDependenceNotDefined);
	
EndProcedure

&AtClient
Procedure OpenDependenceSettingForm(PropertyToConfigure)
	
	FormParameters = New Structure;
	FormParameters.Insert("AdditionalAttribute", Object.Ref);
	FormParameters.Insert("AttributesDependencies", Object.AdditionalAttributesDependencies);
	FormParameters.Insert("Set", Object.PropertySet);
	FormParameters.Insert("PropertyToConfigure", PropertyToConfigure);
	
	OpenForm("ChartOfCharacteristicTypes.AdditionalAttributesAndInfo.Form.AttributesDependencies", FormParameters);
	
EndProcedure

&AtServer
Procedure SetFormHeader()
	
	If ValueIsFilled(Object.Ref) Then
		
		If ValueIsFilled(Object.PropertySet) Then
			If Object.IsAdditionalInfo Then
				Title = String(Object.Title) + " " + NStr("ru = '(???????????????????????????? ????????????????)'; en = '(Additional information)'; pl = '(Informacje dodatkowe)';es_ES = '(Informaci??n adicional)';es_CO = '(Informaci??n adicional)';tr = '(Ek bilgi)';it = '(Informazione aggiuntiva)';de = '(Zus??tzliche Information)'");
			Else
				Title = String(Object.Title) + " " + NStr("ru = '(???????????????????????????? ????????????????)'; en = '(Additional attribute)'; pl = '(Dodatkowy atrybut)';es_ES = '(Atributo adicional)';es_CO = '(Atributo adicional)';tr = '(Ek ??znitelik)';it = '(Attributo aggiuntivo)';de = '(Zus??tzliches Attribut)'");
			EndIf;
		Else
			If Object.IsAdditionalInfo Then
				Title = String(Object.Title) + " " + NStr("ru = '(?????????? ???????????????????????????? ????????????????)'; en = '(Common additional information)'; pl = '(Wsp??lne informacje dodatkowe)';es_ES = '(Informaci??n adicional com??n)';es_CO = '(Informaci??n adicional com??n)';tr = '(Ortak ek bilgi)';it = '(Ulteriori informazioni comuni)';de = '(Gemeinsame zus??tzliche Informationen)'");
			Else
				Title = String(Object.Title) + " " + NStr("ru = '(?????????? ???????????????????????????? ????????????????)'; en = '(Common additional attribute)'; pl = '(Wsp??lny atrybut dodatkowy)';es_ES = '(Atributo adicional com??n)';es_CO = '(Atributo adicional com??n)';tr = '(Ortak ek ??zellik)';it = '(Attributo aggiuntivo comune)';de = '(Gemeinsames zus??tzliches Attribut)'");
			EndIf;
		EndIf;
	Else
		If ValueIsFilled(Object.PropertySet) Then
			If Object.IsAdditionalInfo Then
				Title = NStr("ru = '???????????????????????????? ???????????????? (????????????????)'; en = 'Additional information (Create)'; pl = 'Informacje dodatkowe (Tworzenie)';es_ES = 'Informaci??n adicional (crear)';es_CO = 'Informaci??n adicional (crear)';tr = 'Ek bilgi (Olu??tur)';it = 'Informazioni aggiuntive (Creare)';de = 'Weitere Informationen (Erstellen)'");
			Else
				Title = NStr("ru = '???????????????????????????? ???????????????? (????????????????)'; en = 'Additional attribute (Create)'; pl = 'Dodatkowy atrybut (Tworzenie)';es_ES = 'Atributo adicional (Crear)';es_CO = 'Atributo adicional (Crear)';tr = 'Ek ??znitelik (Olu??tur)';it = 'Attributo aggiuntivo (Creare)';de = 'Zus??tzliches Attribut (Erstellen)'");
			EndIf;
		Else
			If Object.IsAdditionalInfo Then
				Title = NStr("ru = '?????????? ???????????????????????????? ???????????????? (????????????????)'; en = 'Common additional information (Create)'; pl = 'Wsp??lne informacje dodatkowe (Tworzenie)';es_ES = 'Informaci??n adicional com??n (Crear)';es_CO = 'Informaci??n adicional com??n (Crear)';tr = 'Ortak ek bilgi (Olu??tur)';it = 'Informazioni aggiuntive generali (Creare)';de = 'Gemeinsame weitere Informationen (Erstellen)'");
			Else
				Title = NStr("ru = '?????????? ???????????????????????????? ???????????????? (????????????????)'; en = 'Common additional attribute (Create)'; pl = 'Wsp??lny dodatkowy atrybut (Tworzenie)';es_ES = 'Atributo adicional com??n (Crear)';es_CO = 'Atributo adicional com??n (Crear)';tr = 'Ortak ek ??znitelik (Olu??tur)';it = 'Attributo aggiuntivo generale (Creare)';de = 'Gemeinsame zus??tzliche Attribute (Erstellen)'");
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeCurrentSet()
	
	If Items.PropertySets.CurrentData = Undefined Then
		If ValueIsFilled(SelectedPropertiesSet) Then
			SelectedPropertiesSet = Undefined;
			OnChangeCurrentSetAtServer();
		EndIf;
		
	ElsIf Items.PropertySets.CurrentData.Ref <> SelectedPropertiesSet Then
		SelectedPropertiesSet = Items.PropertySets.CurrentData.Ref;
		CurrentSetIsGroup = Items.PropertySets.CurrentData.IsFolder;
		OnChangeCurrentSetAtServer(CurrentSetIsGroup);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnChangeCurrentSetAtServer(CurrentSetIsGroup = Undefined)
	
	If ValueIsFilled(SelectedPropertiesSet)
		AND NOT CurrentSetIsGroup Then
		UpdateCurrentSetPropertiesList();
	Else
		Properties.Clear();
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateCurrentSetPropertiesList()
	
	Query = New Query;
	
	If Not Items.SharedAttributesNotIncludedInSets.Check Then
		Query.SetParameter("Set", SelectedPropertiesSet);
		Query.Text =
			"SELECT
			|	SetsProperties.LineNumber,
			|	SetsProperties.Property,
			|	SetsProperties.DeletionMark,
			|	ISNULL(Properties.Title, PRESENTATION(SetsProperties.Property)) AS Title,
			|	Properties.AdditionalValuesOwner,
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
			|	END AS PictureNumber,
			|	Properties.ToolTip,
			|	Properties.ValueFormTitle,
			|	Properties.ValueSelectionFormTitle
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
		
		If IsAdditionalInfo Then
			Query.Text = StrReplace(
				Query.Text,
				"Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes",
				"Catalog.AdditionalAttributesAndInfoSets.AdditionalInfo");
		EndIf;
		
	Else
		Query.Text =
		"SELECT
		|	Properties.Ref AS Property,
		|	Properties.DeletionMark AS DeletionMark,
		|	Properties.Title AS Title,
		|	Properties.AdditionalValuesOwner,
		|	Properties.ValueType AS ValueType,
		|	TRUE AS Common,
		|	CASE
		|		WHEN Properties.DeletionMark = TRUE
		|			THEN 4
		|		ELSE 3
		|	END AS PictureNumber,
		|	Properties.ToolTip,
		|	Properties.ValueFormTitle,
		|	Properties.ValueSelectionFormTitle
		|FROM
		|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
		|		
		|WHERE
		|	Properties.PropertySet = VALUE(Catalog.AdditionalAttributesAndInfoSets.EmptyRef)
		|		AND Properties.IsAdditionalInfo = &IsAdditionalInfo
		|
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	""DataVersion"" AS DataVersion";
		
		Query.SetParameter("IsAdditionalInfo", (IsAdditionalInfo = 1));
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
			|UNION ALL
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
					ValuesPresentation = NStr("ru = '???????????????? ?????? ???? ??????????????'; en = 'Values are not entered yet'; pl = 'Nie wprowadzono ??adnych warto??ci';es_ES = 'No hay valores entrados';es_CO = 'No hay valores entrados';tr = 'De??er girilmedi';it = 'I valori non sono ancora stati inseriti';de = 'Keine Werte eingegeben'");
				Else
					ValuesPresentation = NStr("ru = '???????????????? ???????????????? ???? ????????????????'; en = 'Values are marked for deletion'; pl = 'Warto??ci s?? zaznaczone do usuni??cia';es_ES = 'Valores est??n marcados para borrar';es_CO = 'Valores est??n marcados para borrar';tr = 'De??erler silinmek ??zere i??aretlendi';it = 'I valori sono contrassegnati per l''eliminazione';de = 'Die Werte sind zum L??schen markiert'");
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
Procedure NewPassedParametersStructure()
	PassedFormParameters = New Structure;
	PassedFormParameters.Insert("AdditionalValuesOwner");
	PassedFormParameters.Insert("ShowSetAdjustment");
	PassedFormParameters.Insert("CurrentPropertiesSet");
	PassedFormParameters.Insert("IsAdditionalInfo");
	PassedFormParameters.Insert("SelectCommonProperty");
	PassedFormParameters.Insert("SelectedValues");
	PassedFormParameters.Insert("SelectAdditionalValueOwner");
	PassedFormParameters.Insert("CopyingValue");
	PassedFormParameters.Insert("CopyWithQuestion");
	PassedFormParameters.Insert("Drag", False);
	
	FillPropertyValues(PassedFormParameters, Parameters);
EndProcedure

&AtServerNoContext
Function DescriptionAlreadyUsed(Val Header, Val CurrentProperty, Val PropertySet, NewDescription)
	
	If ValueIsFilled(PropertySet) Then
		SetDescription = Common.ObjectAttributeValue(PropertySet, "Description");
		NewDescription = Header + " (" + SetDescription + ")";
	Else
		NewDescription = Header;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Properties.IsAdditionalInfo,
	|	Properties.PropertySet
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
	|WHERE
	|	Properties.Description = &Description
	|	AND Properties.Ref <> &Ref
	|	AND Properties.PropertySet = &Set";
	
	Query.SetParameter("Ref",       CurrentProperty);
	Query.SetParameter("Set",        PropertySet);
	Query.SetParameter("Description", NewDescription);
	
	BeginTransaction();
	Try
		Selection = Query.Execute().Select();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If NOT Selection.Next() Then
		Return "";
	EndIf;
	
	If ValueIsFilled(Selection.PropertySet) Then
		If Selection.IsAdditionalInfo Then
			QuestionText = NStr("ru = '???????????????????? ???????????????????????????? ???????????????? ?? ??????????????????????????
			                          |""%1"".'; 
			                          |en = 'Additional information with the
			                          |""%1"" description is not unique.'; 
			                          |pl = 'Istnieje informacja dodatkowa z pozycj??
			                          |""%1"".';
			                          |es_ES = 'Hay una informaci??n adicional con el nombre 
			                          | ""%1"".';
			                          |es_CO = 'Hay una informaci??n adicional con el nombre 
			                          | ""%1"".';
			                          |tr = '
			                          |""%1"" adl?? ek bilgi mevcut.';
			                          |it = 'Informazioni aggiuntive con la descrizione
			                          |""%1"" non univoche.';
			                          |de = 'Es gibt zus??tzliche Informationen zum Namen
			                          |""%1"".'");
		Else
			QuestionText = NStr("ru = '???????????????????? ???????????????????????????? ???????????????? ?? ??????????????????????????
			                          |""%1"".'; 
			                          |en = 'Additional attribute with the
			                          |""%1"" description is not unique.'; 
			                          |pl = 'Istnieje atrybut dodatkowy z pozycj??
			                          |""%1"".';
			                          |es_ES = 'Hay un requisito adicional con el nombre 
			                          | ""%1"".';
			                          |es_CO = 'Hay un requisito adicional con el nombre 
			                          | ""%1"".';
			                          |tr = '%1"
" adl?? ek ??zellik mevcut.';
			                          |it = 'Attributo aggiuntivo con descrizione 
			                          |""%1"" non univoco.';
			                          |de = 'Es gibt zus??tzliche Attribute zum Namen
			                          |""%1"".'");
		EndIf;
	Else
		If Selection.IsAdditionalInfo Then
			QuestionText = NStr("ru = '???????????????????? ?????????? ???????????????????????????? ???????????????? ?? ??????????????????????????
			                          |""%1"".'; 
			                          |en = 'Common additional information with the
			                          |""%1"" description is not unique.'; 
			                          |pl = 'Istnieje wsp??lna informacja dodatkowa z pozycj??
			                          |""%1"".';
			                          |es_ES = 'Hay una informaci??n adicional com??n con el nombre 
			                          | ""%1"".';
			                          |es_CO = 'Hay una informaci??n adicional com??n con el nombre 
			                          | ""%1"".';
			                          |tr = '""%1"" ad??yla ortak
			                          |ek bilgi mevcuttur.';
			                          |it = 'Informazioni aggiuntive generali con descrizione
			                          |""%1"" non univoche.';
			                          |de = 'Es gibt allgemeine Informationen zum Namen
			                          |""%1"".'");
		Else
			QuestionText = NStr("ru = '???????????????????? ?????????? ???????????????????????????? ???????????????? ?? ??????????????????????????
			                          |""%1"".'; 
			                          |en = 'Common additional attribute with the
			                          |""%1"" description is not unique.'; 
			                          |pl = 'Istnieje wsp??lny atrybut dodatkowy z pozycj??
			                          |""%1"".';
			                          |es_ES = 'Hay un requisito adicional com??n con el nombre 
			                          | ""%1"".';
			                          |es_CO = 'Hay un requisito adicional com??n con el nombre 
			                          | ""%1"".';
			                          |tr = '""%1"" ad??yla ortak
			                          |ek ??zellik mevcuttur.';
			                          |it = 'Attributo aggiuntivo generale con descrizione 
			                          |""%1"" non univoco.';
			                          |de = 'Es gibt allgemeine Attribute zum Namen
			                          |""%1"".'");
		EndIf;
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
		QuestionText + Chars.LF + Chars.LF
		                         + NStr("ru ='?????????????????????????? ???????????????????????? ???????????? ????????????????????????,
		                         |?????????? ?????????????????? ?????????? ???????????????? ??????????????????????.'; 
		                         |en = 'We recommend that you use another description,
		                         |otherwise, the application might not work properly.'; 
		                         |pl = 'Zaleca si?? u??ycie innej pozycji,
		                         |w przeciwnym wypadku program mo??e pracowa?? nieprawid??owo.';
		                         |es_ES = 'Se recomienda usar otro nombre,
		                         |en otro caso el programa puede funcionar incorrectamente.';
		                         |es_CO = 'Se recomienda usar otro nombre,
		                         |en otro caso el programa puede funcionar incorrectamente.';
		                         |tr = '
		                         |Ba??ka bir ad kullanman??z ??nerilir, aksi halde uygulama yanl???? ??al????abilir.';
		                         |it = 'Si raccomanda di utilizzare un''altra denominazione,
		                         |altrimenti l''applicazione potrebbe non funzionare correttamente.';
		                         |de = 'Es wird empfohlen, einen anderen Namen zu verwenden,
		                         |da das Programm sonst m??glicherweise nicht richtig funktioniert.'"),
		NewDescription);
	
	Return QuestionText;
	
EndFunction

&AtServerNoContext
Function NameAlreadyUsed(Val Name, Val CurrentProperty, Val PropertySet, NewDescription)
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Properties.IsAdditionalInfo,
	|	Properties.PropertySet
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS Properties
	|WHERE
	|	Properties.Name = &Name
	|	AND Properties.Ref <> &Ref";
	
	Query.SetParameter("Ref", CurrentProperty);
	Query.SetParameter("Name",    Name);
	
	BeginTransaction();
	Try
		Selection = Query.Execute().Select();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If NOT Selection.Next() Then
		Return "";
	EndIf;
	
	If Selection.IsAdditionalInfo Then
		QuestionText = NStr("ru = '???????????????????? ???????????????????????????? ???????????????? ?? ????????????
		                          |""%1"".'; 
		                          |en = 'Additional information with the
		                          |""%1"" name is not unique.'; 
		                          |pl = 'Istnieje informacja dodatkowa o nazwie
		                          |""%1""';
		                          |es_ES = 'Hay una informaci??n adicional con el nombre 
		                          | ""%1"".';
		                          |es_CO = 'Hay una informaci??n adicional con el nombre 
		                          | ""%1"".';
		                          |tr = '
		                          |""%1"" adl?? ek bilgi mevcut.';
		                          |it = 'Informazioni aggiuntive con la nome
		                          |""%1"" non univoche.';
		                          |de = 'Es gibt zus??tzliche Informationen mit dem Namen
		                          |""%1"".'");
	Else
		QuestionText = NStr("ru = '???????????????????? ???????????????????????????? ???????????????? ?? ????????????
		                          |""%1"".'; 
		                          |en = 'Additional attribute with the
		                          |""%1"" name is not unique.'; 
		                          |pl = 'Istnieje atrybut dodatkowy o nazwie
		                          |""%1"".';
		                          |es_ES = 'Hay un requisito adicional con el nombre 
		                          | ""%1"".';
		                          |es_CO = 'Hay un requisito adicional con el nombre 
		                          | ""%1"".';
		                          |tr = '%1"
" adl?? ek ??zellik mevcut.';
		                          |it = 'Attributo aggiuntivo con nome
		                          |""%1"" non univoco.';
		                          |de = 'Es gibt zus??tzliche Attribute mit dem Namen
		                          |""%1"".'");
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
		QuestionText + Chars.LF + Chars.LF
		                         + NStr("ru = '?????????????????????????? ???????????????????????? ???????????? ??????,
		                         |?????????? ?????????????????? ?????????? ???????????????? ??????????????????????.
		                         |
		                         |?????????????? ?????????? ?????? ?? ???????????????????? ?????????????'; 
		                         |en = 'We recommend that you use another name,
		                         |otherwise, the application might not work properly.
		                         |
		                         |Create a new name and continue writing?'; 
		                         |pl = 'Zaleca si?? u??ycie innej nazwy,
		                         |w przeciwnym wypadku program mo??e pracowa?? nieprawid??owo.
		                         |
		                         |Utworzy?? now?? nazw?? i kontynuowa?? zapis?';
		                         |es_ES = 'Se recomienda usar otro nombre,
		                         |en otro caso el programa puede funcionar incorrectamente.
		                         |
		                         |??Crear el nuevo nombre y seguir guardando?';
		                         |es_CO = 'Se recomienda usar otro nombre,
		                         |en otro caso el programa puede funcionar incorrectamente.
		                         |
		                         |??Crear el nuevo nombre y seguir guardando?';
		                         |tr = 'Ba??ka bir ad kullanman??z ??nerilir, 
		                         |aksi halde uygulama yanl???? ??al????abilir.
		                         |
		                         |Yeni ad olu??tur ve kaydetmeye devam et?';
		                         |it = 'Si raccomanda di utilizzare un altro nome,
		                         |altrimenti l''applicazione potrebbe non funzionare correttamente.
		                         |
		                         |Creare un nuovo nome e continuare la registrazione?';
		                         |de = 'Es wird empfohlen, einen anderen Namen zu verwenden,
		                         |da das Programm sonst m??glicherweise nicht richtig funktioniert.
		                         |
		                         |Einen neuen Namen erstellen und die Aufzeichnung fortsetzen?'"),
		Name);
	
	Return QuestionText;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetFormatButtonTitle(Form)
	
	If IsBlankString(Form.Object.FormatProperties) Then
		TitleText = NStr("ru = '???????????? ???? ??????????????????'; en = 'Default format'; pl = 'Format domy??lnie';es_ES = 'Formato por defecto';es_CO = 'Formato por defecto';tr = 'Varsay??lan format';it = 'Formato predefinito';de = 'Standardformat'");
	Else
		TitleText = NStr("ru = '???????????? ????????????????????'; en = 'Format is set'; pl = 'Format jest ustalony';es_ES = 'Formato se ha establecido';es_CO = 'Formato se ha establecido';tr = 'Bi??im ayarland??';it = 'E'' installato un formato';de = 'Format ist eingestellt'");
	EndIf;
	
	Form.Items.EditValueFormat.Title = TitleText;
	
EndProcedure

#EndRegion
