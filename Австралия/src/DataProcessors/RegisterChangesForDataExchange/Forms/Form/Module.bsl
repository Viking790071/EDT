// This form is used to edit exchange object registration changes for a specified node.
// You can use the following parameters in the OnCreateAtServer handler.
// 
// ExchangeNode                  - ExchangePlanRef - an exchange node reference.
// SelectExchangeNodeProhibited - Boolean           - a flag showing whether a user can change the specified node.
//                                                  The ExchangeNode parameter must be specified.
// NamesOfMetadataToHide   - ValueList   - contains metadata names to exclude from a registration 
//                                                  tree.
//
// If this form is called from the additional reports and data processors subsystem, the following additional parameters are available:
//
// AdditionalDataProcessorRef - Arbitrary - a reference to the item of the additional reports and 
//                                                data processors catalog that calls the form.
//                                                If this parameter is specified, the TargetObjects parameter must be specified too.
// TargetObjects             - Array       - objects to process. A first array element is used in 
//                                                the OnCreateAtServer procedure. If this parameter 
//                                                is specified, the CommandID parameter must be specified too.
//

#Region Variables

&AtClient
Var MetadataCurrentRow;

#EndRegion

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AdditionalReportsAndDataProcessors

// Command export handler for the additional reports and data processors subsystem.
//
// Parameters:
//     CommandID - String - command ID to execute.
//     TargetObjects             - Array       - references to process. This parameter is not used 
//                                     in the current procedure, expected that a similar parameter is passed and processed during the from creation.
//     CreatedObjects     - Array - a return value, an array of references to created objects.
//                                     This parameter is not used in the current data processor.
//
&AtClient
Procedure ExecuteCommand(CommandID, RelatedObjects, CreatedObjects) Export
	
	If CommandID = "OpenRegistrationEditingForm" Then
		
		If RegistrationObjectParameter <> Undefined Then
			// Using parameters that are set in the OnCreateAtServer procedure.
			
			RegistrationFormParameters = New Structure;
			RegistrationFormParameters.Insert("RegistrationObject",  RegistrationObjectParameter);
			RegistrationFormParameters.Insert("RegistrationTable", RegistrationTableParameter);

			OpenForm(ThisFormName + "Form.ObjectRegistrationNodes", RegistrationFormParameters);
		EndIf;
		
	EndIf;
	
EndProcedure

// End StandardSubsystems.AdditionalReportsAndDataProcessors

#EndRegion

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CheckPlatformVersionAndCompatibilityMode();
	
	RegistrationTableParameter = Undefined;
	RegistrationObjectParameter  = Undefined;
	
	OpenWithNodeParameter = False;
	CurrentObject = ThisObject();
	ThisFormName = GetFormName();
	// Analyzing form parameters and setting options
	If Parameters.AdditionalDataProcessorRef = Undefined Then
		// Starting the data processor in standalone mode, with the ExchangeNodeRef parameter specified.
		ExchangeNodeRef = Parameters.ExchangeNode;
		Parameters.Property("SelectExchangeNodeProhibited", SelectExchangeNodeProhibited);
		OpenWithNodeParameter = True;
		
	Else
		// This data processor is called from the additional reports and data processors subsystem.
		If TypeOf(Parameters.RelatedObjects) = Type("Array") AND Parameters.RelatedObjects.Count() > 0 Then
			
			// The form is opened with the specified object.
			RelatedObject = Parameters.RelatedObjects[0];
			Type = TypeOf(RelatedObject);
			
			If ExchangePlans.AllRefsType().ContainsType(Type) Then
				ExchangeNodeRef = RelatedObject;
				OpenWithNodeParameter = True;
			Else
				// Filling internal attributes.
				Details = CurrentObject.MetadataCharacteristics(RelatedObject.Metadata());
				If Details.IsReference Then
					RegistrationObjectParameter = RelatedObject;
					
				ElsIf Details.IsSet Then
					// Structure and table name
					RegistrationTableParameter = Details.TableName;
					RegistrationObjectParameter  = New Structure;
					For Each Dimension In CurrentObject.RecordSetDimensions(RegistrationTableParameter) Do
						CurName = Dimension.Name;
						RegistrationObjectParameter.Insert(CurName, RelatedObject.Filter[CurName].Value);
					EndDo;
					
				EndIf;
			EndIf;
			
		Else
			Raise StrReplace(
				NStr("ru = 'Некорректные параметры объектов назначения открытия команды ""%1""'; en = 'Invalid destination object parameters for the ""%1"" command'; pl = 'Nieprawidłowy cel obiektów przeznaczenia otwarcia polecenia ""%1""';es_ES = 'Destinación incorrecta de parámetros del objeto para el comando ""%1""';es_CO = 'Destinación incorrecta de parámetros del objeto para el comando ""%1""';tr = '""%1"" komutu için geçersiz hedef nesne parametreleri';it = 'Parametri oggetto destinazione non validi per il comando ""%1""';de = 'Ungültige Zielobjektparameter für den ""%1"" Befehl'"),
				"%1", Parameters.CommandID);
		EndIf;
		
	EndIf;
	
	// Initializing object settings.
	CurrentObject.ReadSettings();
	CurrentObject.ReadSSLSupportFlags();
	ThisObject(CurrentObject);
	
	// Initializing other parameters only if this form will be opened
	If RegistrationObjectParameter <> Undefined Then
		Return;
	EndIf;
	Items.PagesGroup.CurrentPage = Items.Default;
	// Filling the list of prohibited metadata objects based on form parameters.
	Parameters.Property("NamesOfMetadataToHide", NamesOfMetadataToHide);
	AddNameOfMetadataToHide();
	
	MetadataCurrentRow = Undefined;
	Items.ObjectsListOptions.CurrentPage = Items.BlankPage;
	Parameters.Property("SelectExchangeNodeProhibited", SelectExchangeNodeProhibited);
	
	ExchangePlanNodeDescription = String(ExchangeNodeRef);
	
	If Not ControlSettings() AND OpenWithNodeParameter Then
		
		MessageText = StrReplace(
			NStr("ru = 'Для ""%1"" редактирование регистрации объектов недоступно.'; en = 'Cannot change item stage state for node ""%1"".'; pl = 'Nie można zmienić statusu rejestracji dla węzła ""%1"".';es_ES = 'No se puede cambiar el estado del registro del elemento para el nodo ""%1"".';es_CO = 'No se puede cambiar el estado del registro del elemento para el nodo ""%1"".';tr = '""%1"" düğümü için öğe hazırlama durumu değiştirilemiyor.';it = 'Impossibile modificare lo stato di impostazione dell''elemento per il nodo ""%1"".';de = 'Fehler beim Ändern von Status von Aufbereitung des Elementes für Knoten ""%1"".'"),
			"%1", ExchangePlanNodeDescription);
		
		Raise MessageText;
		
	EndIf;
		
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	// Autosaving settings
	SavedInSettingsDataModified = True;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	// Analyzing selected value, it must be a structure.
	If TypeOf(SelectedValue) <> Type("Structure") 
		Or (Not SelectedValue.Property("ChoiceAction"))
		Or (Not SelectedValue.Property("ChoiceData"))
		Or TypeOf(SelectedValue.ChoiceAction) <> Type("Boolean")
		Or TypeOf(SelectedValue.ChoiceData) <> Type("String") Then
		Error = NStr("ru = 'Неожиданный результат выбора из консоли запросов'; en = 'Unexpected query result'; pl = 'Nieoczekiwany wynik zapytania';es_ES = 'Resultado inesperado de la solicitud';es_CO = 'Resultado inesperado de la solicitud';tr = 'Beklenmeyen sorgu sonucu';it = 'Risultato di query inatteso';de = 'Unerwartetes Abfrageergebnis'");
	Else
		Error = RefControlForQuerySelection(SelectedValue.ChoiceData);
	EndIf;
	
	If Error <> "" Then 
		ShowMessageBox(,Error);
		Return;
	EndIf;
		
	If SelectedValue.ChoiceAction Then
		Text = NStr("ru = 'Зарегистрировать результат запроса
		                 |на узле ""%1""?'; 
		                 |en = 'Do you want to stage the query result
		                 |at node ""%1""?'; 
		                 |pl = 'Czy chcesz zarejestrować wynik zapytania
		                 |na węźle ""%1""?';
		                 |es_ES = '¿Quiere registrar el resultado de la solicitud 
		                 |en el nodo ""%1""?';
		                 |es_CO = '¿Quiere registrar el resultado de la solicitud 
		                 |en el nodo ""%1""?';
		                 |tr = '""%1"" düğümünde
		                 |sorgu sonucu hazırlansın mı?';
		                 |it = 'Impostare il risultato di query
		                 |al nodo ""%1""?';
		                 |de = 'Möchten Sie das Abfrageergebnis 
		                 |beim Knoten node ""%1"" aufbereiten?'"); 
	Else
		Text = NStr("ru = 'Отменить регистрацию результата запроса
		                 |на узле ""%1""?'; 
		                 |en = 'Do you want to unstage the query result
		                 |at node ""%1""?'; 
		                 |pl = 'Czy chcesz anulować rejestrację wyniku zapytania
		                 |na węźle ""%1""?';
		                 |es_ES = '¿Quiere cancelar el registro del resultado de la solicitud 
		                 |en el nodo ""%1""?';
		                 |es_CO = '¿Quiere cancelar el registro del resultado de la solicitud 
		                 |en el nodo ""%1""?';
		                 |tr = '""%1"" düğümünde
		                 |sorgu sonucu kaldırılsın mı?';
		                 |it = 'Rimuovere il risultato di query
		                 |al nodo ""%1""?';
		                 |de = 'Möchten Sie die Aufbereitung des Abfrageergebnisses 
		                 |beim Knoten node ""%1"" aufheben?'"); 
	EndIf;
	Text = StrReplace(Text, "%1", String(ExchangeNodeRef));
					 
	QuestionTitle = NStr("ru = 'Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
	
	Notification = New NotifyDescription("ChoiceProcessingCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("SelectedValue", SelectedValue);
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ObjectDataExchangeRegistrationEdit" Then
		FillRegistrationCountInTreeRows();
		UpdatePageContent();

	ElsIf EventName = "ExchangeNodeDataEdit" AND ExchangeNodeRef = Parameter Then
		SetMessageNumberTitle();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	// Automatic settings
	CurrentObject = ThisObject();
	CurrentObject.SaveSettings();
	ThisObject(CurrentObject);
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If RegistrationObjectParameter <> Undefined Then
		// Another form will be used.
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.ExchangeNode) Then
		ExchangeNodeRef = Parameters.ExchangeNode;
	Else
		ExchangeNodeRef = Settings["ExchangeNodeRef"];
		// If restored exchange node is deleted, clearing the ExchangeNodeRef value.
		If ExchangeNodeRef <> Undefined 
		    AND ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodeRef))
		    AND IsBlankString(ExchangeNodeRef.DataVersion) Then
			ExchangeNodeRef = Undefined;
		EndIf;
	EndIf;
	
	ControlSettings();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers
//

&AtClient
Procedure ExchangeNodeRefStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	CurFormName = ThisFormName + "Form.SelectExchangePlanNode";
	CurParameters = New Structure("MultipleChoice, ChoiceInitialValue", False, ExchangeNodeRef);
	OpenForm(CurFormName, CurParameters, Item);
EndProcedure

&AtClient
Procedure ExchangeNodeRefChoiceProcessing(Item, ValueSelected, StandardProcessing)
	If ExchangeNodeRef <> ValueSelected Then
		ExchangeNodeRef = ValueSelected;
		AttachIdleHandler("ExchangeNodeChoiceProcessing", 0.1, True);
	EndIf;
EndProcedure

&AtClient
Procedure ExchangeNodeRefOnChange(Item)
	ExchangeNodeChoiceProcessingServer();
	ExpandMetadataTree();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure ExchangeNodeRefClear(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure FilterVariantByMessageNoOnChange(Item)
	SetFiltersInDynamicLists();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure ObjectListVariantsOnCurrentPageChange(Item, CurrentPage)
	UpdatePageContent(CurrentPage);
EndProcedure

#EndRegion

#Region MetadataTreeFormTableItemEventHandlers
//

&AtClient
Procedure MetadataTreeMarkOnChange(Item)
	ChangeMark(Items.MetadataTree.CurrentRow);
EndProcedure

&AtClient
Procedure MetadataTreeOnActivateRow(Item)
	If Items.MetadataTree.CurrentRow <> MetadataCurrentRow Then
		MetadataCurrentRow  = Items.MetadataTree.CurrentRow;
		AttachIdleHandler("SetUpChangeEditing", 0.1, True);
	EndIf;
EndProcedure

#EndRegion

#Region ConstantListFormTableItemEventHandlers
//

&AtClient
Procedure ConstantListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	Result = AddRegistrationAtServer(True, ValueSelected);
	Items.ConstantsList.Refresh();
	FillRegistrationCountInTreeRows();
	ReportRegistrationResults(Result);
	
	If TypeOf(ValueSelected) = Type("Array") AND ValueSelected.Count() > 0 Then
		Item.CurrentRow = ValueSelected[0];
	Else
		Item.CurrentRow = ValueSelected;
	EndIf;
	
EndProcedure

#EndRegion

#Region RefListFormTableItemsEventHandlers
//
&AtClient
Procedure ReferenceListChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	CurrentRef = Item.CurrentData.Ref;
	If Not ValueIsFilled(CurrentRef)
		Or Not ValueIsFilled(ReferencesListTableName) Then
		Return;
	EndIf;
	ParametersStructure = New Structure("Key, ReadOnly", CurrentRef, True);
	OpenForm(ReferencesListTableName + ".ObjectForm", ParametersStructure, ThisObject);
EndProcedure

&AtClient
Procedure ReferenceListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	DataChoiceProcessing(Item, ValueSelected);
EndProcedure

#EndRegion

#Region RecordSetListFormTableItemEventHandlers
//

&AtClient
Procedure RecordSetListSelection(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	
	WriteParameters = RecordSetKeyStructure(Item.CurrentData);
	If WriteParameters <> Undefined Then
		OpenForm(WriteParameters.FormName, New Structure(WriteParameters.Parameter, WriteParameters.Value));
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordSetListChoiceProcessing(Item, ValueSelected, StandardProcessing)
	DataChoiceProcessing(Item, ValueSelected);
EndProcedure

#EndRegion

#Region FormCommandHandlers
//

&AtClient
Procedure AddRegistrationForSingleObject(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurrRow = Items.ObjectsListOptions.CurrentPage;
	If CurrRow = Items.ConstantsPage Then
		AddConstantRegistrationInList();
		
	ElsIf CurrRow = Items.ReferencesListPage Then
		AddRegistrationInReferenceList();
		
	ElsIf CurrRow = Items.RecordSetPage Then
		AddRegistrationInRecordSetFilter();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteRegistrationForSingleObject(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurrRow = Items.ObjectsListOptions.CurrentPage;
	If CurrRow = Items.ConstantsPage Then
		DeleteConstantRegistrationInList();
		
	ElsIf CurrRow = Items.ReferencesListPage Then
		DeleteRegistrationFromReferenceList();
		
	ElsIf CurrRow = Items.RecordSetPage Then
		DeleteRegistrationInRecordSet();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AddRegistrationFilter(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurrRow = Items.ObjectsListOptions.CurrentPage;
	If CurrRow = Items.ReferencesListPage Then
		AddRegistrationInListFilter();
		
	ElsIf CurrRow = Items.RecordSetPage Then
		AddRegistrationInRecordSetFilter();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DeleteRegistrationFilter(Command)
	
	If Not ValueIsFilled(ExchangeNodeRef) Then
		Return;
	EndIf;
	
	CurrRow = Items.ObjectsListOptions.CurrentPage;
	If CurrRow = Items.ReferencesListPage Then
		DeleteRegistrationInListFilter();
		
	ElsIf CurrRow = Items.RecordSetPage Then
		DeleteRegistrationInRecordSetFilter();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenNodeRegistrationForm(Command)
	
	If SelectExchangeNodeProhibited Then
		Return;
	EndIf;
		
	Data = GetCurrentObjectToEdit();
	If Data <> Undefined Then
		RegistrationTable = ?(TypeOf(Data) = Type("Structure"), RecordSetsListTableName, "");
		OpenForm(ThisFormName + "Form.ObjectRegistrationNodes",
			New Structure("RegistrationObject, RegistrationTable, NotifyAboutChanges", 
				Data, RegistrationTable, True), ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowExportResult(Command)
	
	CurPage = Items.ObjectsListOptions.CurrentPage;
	Serializing = New Array;
	
	If CurPage = Items.ConstantsPage Then 
		FormItem = Items.ConstantsList;
		For Each Row In FormItem.SelectedRows Do
			curData = FormItem.RowData(Row);
			Serializing.Add(New Structure("TypeFlag, Data", 1, curData.MetaFullName));
		EndDo;
		
	ElsIf CurPage = Items.RecordSetPage Then
		MeasurementList = RecordSetKeyNameArray(RecordSetsListTableName);
		FormItem = Items.RecordSetsList;
		Prefix = "RecordSetsList";
		For Each Item In FormItem.SelectedRows Do
			curData = New Structure();
			Data = FormItem.RowData(Item);
			For Each Name In MeasurementList Do
				curData.Insert(Name, Data[Prefix + Name]);
			EndDo;
			Serializing.Add(New Structure("TypeFlag, Data", 2, curData));
		EndDo;
		
	ElsIf CurPage = Items.ReferencesListPage Then
		FormItem = Items.RefsList;
		For Each Item In FormItem.SelectedRows Do
			curData = FormItem.RowData(Item);
			Serializing.Add(New Structure("TypeFlag, Data", 3, curData.Ref));
		EndDo;
		
	Else
		Return;
		
	EndIf;
	
	If Serializing.Count() > 0 Then
		Text = SerializationText(Serializing);
		TextTitle = NStr("ru = 'Результат стандартной выгрузки (РИБ)'; en = 'Export result (DIB)'; pl = 'Wynik eksportu (DIB)';es_ES = 'Resultado de exportación (DIB)';es_CO = 'Resultado de exportación (DIB)';tr = 'Dışa aktarım sonucu (DIB)';it = 'Risultato esportazione (DIB)';de = 'Ergebnis des Exports (DIB)'");
		Text.Show(TextTitle);
	EndIf;
	
EndProcedure

&AtClient
Procedure EditMessagesNumbers(Command)
	
	If ValueIsFilled(ExchangeNodeRef) Then
		CurFormName = ThisFormName + "Form.ExchangePlanNodeMessageNumbers";
		CurParameters = New Structure("ExchangeNodeRef", ExchangeNodeRef);
		OpenForm(CurFormName, CurParameters, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

&AtClient
Procedure AddConstantRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddConstantRegistrationInList();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteConstantRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteConstantRegistrationInList();
	EndIf;
EndProcedure

&AtClient
Procedure AddRefRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInReferenceList();
	EndIf;
EndProcedure

&AtClient
Procedure AddObjectDeletionRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddObjectDeletionRegistrationInReferenceList();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRefRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationFromReferenceList();
	EndIf;
EndProcedure

&AtClient
Procedure AddRefRegistrationPickup(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInReferenceList(True);
	EndIf;
EndProcedure

&AtClient
Procedure AddRefRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInListFilter();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRefRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationInListFilter();
	EndIf;
EndProcedure

&AtClient
Procedure AddRegistrationForAutoObjects(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddSelectedObjectRegistration(False);
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRegistrationForAutoObjects(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteSelectedObjectRegistration(False);
	EndIf;
EndProcedure

&AtClient
Procedure AddRegistrationForAllObjects(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddSelectedObjectRegistration();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRegistrationForAllObjects(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteSelectedObjectRegistration();
	EndIf;
EndProcedure

&AtClient
Procedure AddRecordSetRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		AddRegistrationInRecordSetFilter();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRecordSetRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationInRecordSet();
	EndIf;
EndProcedure

&AtClient
Procedure DeleteRecordSetRegistrationFilter(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		DeleteRegistrationInRecordSetFilter();
	EndIf;
EndProcedure

&AtClient
Procedure UpdateAllData(Command)
	FillRegistrationCountInTreeRows();
	UpdatePageContent();
EndProcedure

&AtClient
Procedure AddQueryResultRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		ActionWithQueryResult(True);
	EndIf;
EndProcedure

&AtClient
Procedure DeleteQueryResultRegistration(Command)
	If ValueIsFilled(ExchangeNodeRef) Then
		ActionWithQueryResult(False);
	EndIf;
EndProcedure

&AtClient
Procedure OpenSettingsForm(Command)
	OpenDataProcessorSettingsForm();
EndProcedure

&AtClient
Procedure EditObjectMessageNumber(Command)
	
	If Items.ObjectsListOptions.CurrentPage = Items.ConstantsPage Then
		EditConstantMessageNo();
		
	ElsIf Items.ObjectsListOptions.CurrentPage = Items.ReferencesListPage Then
		EditRefMessageNo();
		
	ElsIf Items.ObjectsListOptions.CurrentPage = Items.RecordSetPage Then
		EditMessageNoSetList()
		
	EndIf;
	
EndProcedure

&AtClient
Procedure RegisterMOIDAndPredefinedItems(Command)
	
	QuestionTitle = NStr("ru = 'Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
	QuestionText     = StrReplace( 
		NStr("ru = 'Зарегистрировать данные для восстановления подчиненного узла РИБ
		     |на узле ""%1""?'; 
		     |en = 'Do you want to stage items to recover the DIB subnode
		     |at node ""%1""?'; 
		     |pl = 'Czy chcesz zarejestrować elementy do przywrócenia podwęzła DIB
		     |na węźle ""%1""?';
		     |es_ES = '¿Quiere registrar los elementos para recuperar el nodo subordinado DIB 
		     |en el nodo ""%1""?';
		     |es_CO = '¿Quiere registrar los elementos para recuperar el nodo subordinado DIB 
		     |en el nodo ""%1""?';
		     |tr = '""%1"" düğümünde
		     |DIB alt düğümünü kurtarmak için öğeler hazırlansın mı?';
		     |it = 'Impostare gli elementi per ripristinare il sottonodo DIB
		     |al nodo ""%1""?';
		     |de = 'Möchten Sie Elemente aufbereiten, um den DIB-Unterknoten
		     | bei Knoten ""%1"" wiederherzustellen?'"),
		"%1", ExchangeNodeRef);
	
	Notification = New NotifyDescription("RegisterMetadataObjectIDCompletion", ThisObject);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , , QuestionTitle);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReferencesListMessageNumber.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RefsList.NotExported");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.LightGray);
	Item.Appearance.SetParameterValue("Text", NStr("ru = 'Не выгружалось'; en = 'Pending export'; pl = 'Trwa eksport';es_ES = 'Pendiente de exportación';es_CO = 'Pendiente de exportación';tr = 'Dışa aktarım bekleniyor';it = 'Esportazione in attesa';de = 'Export anstehend'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ConstantsListMessageNumber.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ConstantsList.NotExported");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.LightGray);
	Item.Appearance.SetParameterValue("Text", NStr("ru = 'Не выгружалось'; en = 'Pending export'; pl = 'Trwa eksport';es_ES = 'Pendiente de exportación';es_CO = 'Pendiente de exportación';tr = 'Dışa aktarım bekleniyor';it = 'Esportazione in attesa';de = 'Export anstehend'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.RecordSetsListMessageNumber.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RecordSetsList.NotExported");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	Item.Appearance.SetParameterValue("TextColor", WebColors.LightGray);
	Item.Appearance.SetParameterValue("Text", NStr("ru = 'Не выгружалось'; en = 'Pending export'; pl = 'Trwa eksport';es_ES = 'Pendiente de exportación';es_CO = 'Pendiente de exportación';tr = 'Dışa aktarım bekleniyor';it = 'Esportazione in attesa';de = 'Export anstehend'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.MetadataTreeChangesCountAsString.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("MetadataTree.ChangeCount");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;

	Item.Appearance.SetParameterValue("TextColor", WebColors.DarkGray);
	Item.Appearance.SetParameterValue("Text", NStr("ru = 'Не изменялись'; en = 'Unchanged'; pl = 'Bez zmian';es_ES = 'Sin cambios';es_CO = 'Sin cambios';tr = 'Değiştirilmemiş';it = 'Invariato';de = 'Unverändert'"));
	
EndProcedure
//

// Dialog continuation notification handler.
&AtClient 
Procedure RegisterMetadataObjectIDCompletion(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ReportRegistrationResults(RegisterMOIDAndPredefinedItemsAtServer() );
		
	FillRegistrationCountInTreeRows();
	UpdatePageContent();
EndProcedure

// Dialog continuation notification handler.
&AtClient 
Procedure ChoiceProcessingCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return
	EndIf;
	SelectedValue = AdditionalParameters.SelectedValue;
	If Object.AsynchronousRegistrationAvailable Then
		BackgroundJobParameters = PrepareRegistrationChangeParameters(SelectedValue.ChoiceAction, 
		AdditionalParameters.Property("NoAutoRegistration") AND AdditionalParameters.NoAutoRegistration,
		Undefined);
		BackgroundJobParameters.Insert("AddressData", SelectedValue.ChoiceData);
		BackgroundJobStartClient(BackgroundJobParameters);
	Else
		ReportRegistrationResults(ChangeQueryResultRegistrationServer(SelectedValue.ChoiceAction, SelectedValue.ChoiceData));
		
		FillRegistrationCountInTreeRows();
		UpdatePageContent();
	EndIf;
EndProcedure

&AtClient
Procedure EditConstantMessageNo()
	curData = Items.ConstantsList.CurrentData;
	If curData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EditConstantMessageNoCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("MetaFullName", curData.MetaFullName);
	
	MessageNumber = curData.MessageNo;
	Tooltip = NStr("ru = 'Номер отправленного'; en = 'Number of sent message'; pl = 'Numer wysłanej wiadomości';es_ES = 'Número de mensaje enviado';es_CO = 'Número de mensaje enviado';tr = 'Gönderilen mesajın numarası';it = 'Numero di messaggio inviato';de = 'Nummer der gesendeten Nachricht'"); 
	
	ShowInputNumber(Notification, MessageNumber, Tooltip);
EndProcedure

// Dialog continuation notification handler.
&AtClient
Procedure EditConstantMessageNoCompletion(Val MessageNumber, Val AdditionalParameters) Export
	If MessageNumber = Undefined Then
		// Canceling input.
		Return;
	EndIf;
	
	ReportRegistrationResults(EditMessageNumberAtServer(MessageNumber, AdditionalParameters.MetaFullName));
		
	Items.ConstantsList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure EditRefMessageNo()
	curData = Items.RefsList.CurrentData;
	If curData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EditRefMessageNoCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Ref", curData.Ref);
	
	MessageNumber = curData.MessageNo;
	Tooltip = NStr("ru = 'Номер отправленного'; en = 'Number of sent message'; pl = 'Numer wysłanej wiadomości';es_ES = 'Número de mensaje enviado';es_CO = 'Número de mensaje enviado';tr = 'Gönderilen mesajın numarası';it = 'Numero di messaggio inviato';de = 'Nummer der gesendeten Nachricht'"); 
	
	ShowInputNumber(Notification, MessageNumber, Tooltip);
EndProcedure

// Dialog continuation notification handler.
&AtClient
Procedure EditRefMessageNoCompletion(Val MessageNumber, Val AdditionalParameters) Export
	If MessageNumber = Undefined Then
		// Canceling input.
		Return;
	EndIf;
	
	ReportRegistrationResults(EditMessageNumberAtServer(MessageNumber, AdditionalParameters.Ref));
		
	Items.RefsList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure EditMessageNoSetList()
	curData = Items.RecordSetsList.CurrentData;
	If curData = Undefined Then
		Return;
	EndIf;
	
	Notification = New NotifyDescription("EditMessageNoSetListCompletion", ThisObject, New Structure);
	
	RowData = New Structure;
	KeyNames = RecordSetKeyNameArray(RecordSetsListTableName);
	For Each Name In KeyNames Do
		RowData.Insert(Name, curData["RecordSetsList" + Name]);
	EndDo;
	
	Notification.AdditionalParameters.Insert("RowData", RowData);
	
	MessageNumber = curData.MessageNo;
	Tooltip = NStr("ru = 'Номер отправленного'; en = 'Number of sent message'; pl = 'Numer wysłanej wiadomości';es_ES = 'Número de mensaje enviado';es_CO = 'Número de mensaje enviado';tr = 'Gönderilen mesajın numarası';it = 'Numero di messaggio inviato';de = 'Nummer der gesendeten Nachricht'"); 
	
	ShowInputNumber(Notification, MessageNumber, Tooltip);
EndProcedure

// Dialog continuation notification handler.
&AtClient
Procedure EditMessageNoSetListCompletion(Val MessageNumber, Val AdditionalParameters) Export
	If MessageNumber = Undefined Then
		// Canceling input.
		Return;
	EndIf;
	
	ReportRegistrationResults(EditMessageNumberAtServer(
		MessageNumber, AdditionalParameters.RowData, RecordSetsListTableName));
	
	Items.RecordSetsList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure SetUpChangeEditing()
	SetUpChangeEditingServer(MetadataCurrentRow);
EndProcedure

&AtClient
Procedure ExpandMetadataTree()
	For Each Row In MetadataTree.GetItems() Do
		Items.MetadataTree.Expand( Row.GetID() );
	EndDo;
EndProcedure

&AtServer
Procedure SetMessageNumberTitle()
	
	Text = NStr("ru = '№ отправленного: %1,\n№ принятого: %2'; en = 'Number of sent message: %1
		|Number of received message: %2'; pl = 'Numer wysłanej wiadomości: %1\nNumer otrzymanej wiadomości: %2';es_ES = 'Número de mensaje enviado: %1\nNúmero de mensaje recibido: %2';es_CO = 'Número de mensaje enviado: %1\nNúmero de mensaje recibido: %2';tr = 'Gönderilen mesajın numarası: %1\nAlınan mesajın numarası: %2';it = 'Numero di messaggio inviato: %1\nNumero di messaggio ricevuto: %2';de = 'Nummer der gesendeten Nachricht: %1\nNummer der eingenangenen Nachricht: %2'");
	
	Data = ReadMessageNumbers();
	Text = StrReplace(Text, "%1", Format(Data.SentNo, "NFD=0; NZ="));
	Text = StrReplace(Text, "%2", Format(Data.ReceivedNo, "NFD=0; NZ="));
	
	Items.FormEditMessagesNumbers.Title = Text;
EndProcedure	

&AtClient
Procedure ExchangeNodeChoiceProcessing()
	ExchangeNodeChoiceProcessingServer();
EndProcedure

&AtServer
Procedure ExchangeNodeChoiceProcessingServer()
	
	// Modifying node numbers in the FormEditMessageNumbers title.
	SetMessageNumberTitle();
	
	// Updating metadata tree.
	ReadMetadataTree();
	FillRegistrationCountInTreeRows();
	
	// Updating active page.
	LastActiveMetadataColumn = Undefined;
	LastActiveMetadataRow  = Undefined;
	Items.ObjectsListOptions.CurrentPage = Items.BlankPage;
	
	// Setting visibility for related buttons.
	
	MetaNodeExchangePlan = ExchangeNodeRef.Metadata();
	
	If Object.DIBModeAvailable                             // Current SSL version supports MOID.
		AND (ExchangePlans.MasterNode() = Undefined)          // Current infobase is a master node.
		AND MetaNodeExchangePlan.DistributedInfoBase Then // Current node is DIB.
		Items.FormRegisterMOIDAndPredefinedItems.Visible = True;
	Else
		Items.FormRegisterMOIDAndPredefinedItems.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportRegistrationResults(Results)
	Command = Results.Command;
	If TypeOf(Command) = Type("Boolean") Then
		If Command Then
			WarningTitle = NStr("ru = 'Регистрация изменений:'; en = 'Staged items:'; pl = 'Zarejestrowane elementy:';es_ES = 'Registrar los elementos:';es_CO = 'Registrar los elementos:';tr = 'Hazırlanan öğeler:';it = 'Elementi impostati:';de = 'Aufbereitete Elemente:'");
			WarningText = NStr("ru = 'Зарегистрировано %1 изменений из %2
			                           |на узле ""%0""'; 
			                           |en = '%1 out of %2 items are staged.
			                           |Node: %0'; 
			                           |pl = '%1 z %2 elementów są zarejestrowane.
			                           |Węzeł: %0';
			                           |es_ES = '%1 de %2 elementos se ha registrado.
			                           |Nodo: %0';
			                           |es_CO = '%1 de %2 elementos se ha registrado.
			                           |Nodo: %0';
			                           |tr = '%1 / %2 öğe hazırlandı.
			                           |Düğüm: %0';
			                           |it = '%1 di %2 elementi sono impostati.
			                           |Nodo: %0';
			                           |de = '%1 von %2 Elemente sind aufbereitet.
			                           |Knoten: %0'");
		Else
			WarningTitle = NStr("ru = 'Отмена регистрации:'; en = 'Unstaged items:'; pl = 'Niezarejestrowane elementy:';es_ES = 'Cancelar el registro de elementos:';es_CO = 'Cancelar el registro de elementos:';tr = 'Kaldırılan öğeler:';it = 'Elementi non impostati:';de = 'Nicht aufbereitete Elemente:'");
			WarningText = NStr("ru = 'Отменена регистрация %1 изменений 
			                           |на узле ""%0""'; 
			                           |en = '%1 items are unstaged.
			                           |Node: %0'; 
			                           |pl = '%1 elementów są niezarejestrowane.
			                           |Węzeł: %0';
			                           |es_ES = 'Se han cancelado el registro de %1 elementos.
			                           |Nodo: %0';
			                           |es_CO = 'Se han cancelado el registro de %1 elementos.
			                           |Nodo: %0';
			                           |tr = '%1 öğe kaldırıldı.
			                           |Düğüm: %0';
			                           |it = '%1 elementi sono stati rimossi.
			                           |Nodo: %0';
			                           |de = '%1 Elemente sind nicht aufbereitet.
			                           |Knoten: %0'");
		EndIf;
	Else
		WarningTitle = NStr("ru = 'Изменение номера сообщения:'; en = 'Message number changed:'; pl = 'Zmieniono numer wiadomości:';es_ES = 'Se ha cambiado el número de mensaje:';es_CO = 'Se ha cambiado el número de mensaje:';tr = 'Mesaj numarası değiştirildi:';it = 'Numero messaggio modificato:';de = 'Nachrichtennummer geändert:'");
		WarningText = NStr("ru = 'Номер сообщения изменен на %3
		                           |у %1 объекта(ов).'; 
		                           |en = 'Message number changed to %3
		                           |for %1 item(s).'; 
		                           |pl = 'Zmieniono numer wiadomości nd %3
		                           |dla %1 elementu (ów).';
		                           |es_ES = 'El número de mensaje ha cambiado a %3
		                           |para %1 elemento(s).';
		                           |es_CO = 'El número de mensaje ha cambiado a %3
		                           |para %1 elemento(s).';
		                           |tr = '%1 öğe için mesaj numarası
		                           |%3 olarak değiştirildi.';
		                           |it = 'Numero messaggio modificato in %3
		                           | per %1 elemento/i.';
		                           |de = 'Nachrichtennummer geändert für %3
		                           |für %1 Element(e).'");
	EndIf;
	
	WarningText = StrReplace(WarningText, "%0", ExchangeNodeRef);
	WarningText = StrReplace(WarningText, "%1", Format(Results.Success, "NZ="));
	WarningText = StrReplace(WarningText, "%2", Format(Results.Total, "NZ="));
	WarningText = StrReplace(WarningText, "%3", Command);
	
	WarningRequired = Results.Total <> Results.Success;
	If WarningRequired Then
		RefreshDataRepresentation();
		ShowMessageBox(, WarningText, , WarningTitle);
	Else
		ShowUserNotification(WarningTitle,
			GetURL(ExchangeNodeRef),
			WarningText,
			Items.HiddenPictureInformation32.Picture);
	EndIf;
EndProcedure

&AtServer
Function GetQueryResultChoiceForm()
	
	CurrentObject = ThisObject();
	CurrentObject.ReadSettings();
	ThisObject(CurrentObject);
	
	CheckSSL = CurrentObject.CheckSettingCorrectness();
	ThisObject(CurrentObject);
	
	If CheckSSL.QueryExternalDataProcessorAddressSetting <> Undefined Then
		Return Undefined;
		
	ElsIf IsBlankString(CurrentObject.QueryExternalDataProcessorAddressSetting) Then
		Return Undefined;
		
	ElsIf Lower(Right(TrimAll(CurrentObject.QueryExternalDataProcessorAddressSetting), 4)) = ".epf" Then
		Return Undefined;
		
	Else
		DataProcessor = DataProcessors[CurrentObject.QueryExternalDataProcessorAddressSetting].Create();
		FormID = ".Form";
		
	EndIf;
	
	Return DataProcessor.Metadata().FullName() + FormID;
EndFunction

&AtClient
Procedure AddConstantRegistrationInList()
	CurFormName = ThisFormName + "Form.SelectConstant";
	CurParameters = New Structure();
	CurParameters.Insert("ExchangeNode",ExchangeNodeRef);
	CurParameters.Insert("MetadataNamesArray",MetadataNamesStructure.Constants);
	CurParameters.Insert("PresentationsArray",MetadataPresentationsStructure.Constants);
	CurParameters.Insert("AutoRecordsArray",MetadataAutoRecordStructure.Constants);
	OpenForm(CurFormName, CurParameters, Items.ConstantsList);
EndProcedure

&AtClient
Procedure DeleteConstantRegistrationInList()
	
	Item = Items.ConstantsList;
	
	PresentationsList = New Array;
	NamesList          = New Array;
	For Each Row In Item.SelectedRows Do
		Data = Item.RowData(Row);
		PresentationsList.Add(Data.Description);
		NamesList.Add(Data.MetaFullName);
	EndDo;
	
	Count = NamesList.Count();
	If Count = 0 Then
		Return;
	ElsIf Count = 1 Then
		Text = NStr("ru = 'Отменить регистрацию ""%2""
		                 |на узле ""%1""?'; 
		                 |en = 'Do you want to unstage ""%2""
		                 |at node ""%1""?'; 
		                 |pl = 'Czy chcesz anulować rejestrację ""%2""
		                 |na węźle ""%1""?';
		                 |es_ES = '¿Quiere cancelar el registro de ""%2""
		                 |en el nodo ""%1""?';
		                 |es_CO = '¿Quiere cancelar el registro de ""%2""
		                 |en el nodo ""%1""?';
		                 |tr = '""%1"" düğümünde
		                 |""%2"" kaldırılsın mı?';
		                 |it = 'Rimuovere ""%2""
		                 |al nodo ""%1""?';
		                 |de = 'Möchten Sie Aufbereitung für ""%2""
		                 | beim Knoten node ""%1"" aufheben?'"); 
	Else
		Text = NStr("ru = 'Отменить регистрацию выбранных констант
		                 |на узле ""%1""?'; 
		                 |en = 'Do you want to unstage the constants
		                 |at node ""%1""?'; 
		                 |pl = 'Czy chcesz anulować rejestrację stałych
		                 |na węźle ""%1""?';
		                 |es_ES = '¿Quiere cancelar el registro de las constantes
		                 |en el nodo ""%1""?';
		                 |es_CO = '¿Quiere cancelar el registro de las constantes
		                 |en el nodo ""%1""?';
		                 |tr = '""%1"" düğümünde
		                 |sabitler kaldırılsın mı?';
		                 |it = 'Rimuovere costanti
		                 |al nodo ""%1""?';
		                 |de = 'Möchten Sie Aufbereitung der Konstanten 
		                 |beim Knoten node ""%1"" aufheben?'"); 
	EndIf;
	Text = StrReplace(Text, "%1", ExchangeNodeRef);
	Text = StrReplace(Text, "%2", PresentationsList[0]);
	
	QuestionTitle = NStr("ru = 'Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
	
	Notification = New NotifyDescription("DeleteConstantRegistrationInListCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("NamesList", NamesList);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

// Dialog continuation notification handler.
&AtClient
Procedure DeleteConstantRegistrationInListCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
		
	ReportRegistrationResults(DeleteRegistrationAtServer(True, AdditionalParameters.NamesList));
		
	Items.ConstantsList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure AddRegistrationInReferenceList(IsPick = False)
	CurFormName = ReferencesListTableName + ".ChoiceForm";
	CurParameters = New Structure();
	CurParameters.Insert("ChoiceMode", True);
	CurParameters.Insert("MultipleChoice", True);
	CurParameters.Insert("CloseOnChoice", IsPick);
	CurParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.FoldersAndItems);

	OpenForm(CurFormName, CurParameters, Items.RefsList);
EndProcedure

&AtClient
Procedure AddObjectDeletionRegistrationInReferenceList()
	Ref = ObjectRefToDelete();
	DataChoiceProcessing(Items.RefsList, Ref);
EndProcedure

&AtServer
Function ObjectRefToDelete(Val UUID = Undefined)
	Details = ThisObject().MetadataCharacteristics(ReferencesListTableName);
	If UUID = Undefined Then
		Return Details.Manager.GetRef();
	EndIf;
	Return Details.Manager.GetRef(UUID);
EndFunction

&AtClient 
Procedure AddRegistrationInListFilter()
	CurFormName = ThisFormName + "Form.SelectObjectsUsingFilter";
	CurParameters = New Structure("ChoiceAction, TableName", 
		True,
		ReferencesListTableName);
	OpenForm(CurFormName, CurParameters, Items.RefsList);
EndProcedure

&AtClient 
Procedure DeleteRegistrationInListFilter()
	CurFormName = ThisFormName + "Form.SelectObjectsUsingFilter";
	CurParameters = New Structure("ChoiceAction, TableName", 
		False,
		ReferencesListTableName);
	OpenForm(CurFormName, CurParameters, Items.RefsList);
EndProcedure

&AtClient
Procedure DeleteRegistrationFromReferenceList()
	
	Item = Items.RefsList;
	
	DeletionList = New Array;
	For Each Row In Item.SelectedRows Do
		Data = Item.RowData(Row);
		DeletionList.Add(Data.Ref);
	EndDo;
	
	Count = DeletionList.Count();
	If Count = 0 Then
		Return;
	ElsIf Count = 1 Then
		Text = NStr("ru = 'Отменить регистрацию ""%2""
		                 |на узле ""%1""?'; 
		                 |en = 'Do you want to unstage ""%2""
		                 |at node ""%1""?'; 
		                 |pl = 'Czy chcesz anulować rejestrację ""%2""
		                 |na węźle ""%1""?';
		                 |es_ES = '¿Quiere cancelar el registro de ""%2""
		                 |en el nodo ""%1""?';
		                 |es_CO = '¿Quiere cancelar el registro de ""%2""
		                 |en el nodo ""%1""?';
		                 |tr = '""%1"" düğümünde
		                 |""%2"" kaldırılsın mı?';
		                 |it = 'Rimuovere ""%2""
		                 |al nodo ""%1""?';
		                 |de = 'Möchten Sie Aufbereitung für ""%2""
		                 | beim Knoten node ""%1"" aufheben?'"); 
	Else
		Text = NStr("ru = 'Отменить регистрацию выбранных констант
		                 |на узле ""%1""?'; 
		                 |en = 'Do you want to unstage the constants
		                 |at node ""%1""?'; 
		                 |pl = 'Czy chcesz anulować rejestrację stałych
		                 |na węźle ""%1""?';
		                 |es_ES = '¿Quiere cancelar el registro de las constantes 
		                 |en el nodo ""%1""?';
		                 |es_CO = '¿Quiere cancelar el registro de las constantes 
		                 |en el nodo ""%1""?';
		                 |tr = '""%1"" düğümünde
		                 |sabitler kaldırılsın mı?';
		                 |it = 'Rimuovere costanti
		                 |al nodo ""%1""?';
		                 |de = 'Möchten Sie Aufbereitung der Konstanten 
		                 |beim Knoten node ""%1"" aufheben?'"); 
	EndIf;
	Text = StrReplace(Text, "%1", ExchangeNodeRef);
	Text = StrReplace(Text, "%2", DeletionList[0]);
	
	QuestionTitle = NStr("ru = 'Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
	
	Notification = New NotifyDescription("DeleteRegistrationFromReferenceListCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("DeletionList", DeletionList);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Dialog continuation notification handler.
&AtClient 
Procedure DeleteRegistrationFromReferenceListCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ReportRegistrationResults(DeleteRegistrationAtServer(True, AdditionalParameters.DeletionList));
		
	Items.RefsList.Refresh();
	FillRegistrationCountInTreeRows();
EndProcedure

&AtClient
Procedure AddRegistrationInRecordSetFilter()
	CurFormName = ThisFormName + "Form.SelectObjectsUsingFilter";
	CurParameters = New Structure("ChoiceAction, TableName", 
		True,
		RecordSetsListTableName);
	OpenForm(CurFormName, CurParameters, Items.RecordSetsList);
EndProcedure

&AtClient
Procedure DeleteRegistrationInRecordSet()
	
	DataStructure = "";
	KeyNames = RecordSetKeyNameArray(RecordSetsListTableName);
	For Each Name In KeyNames Do
		DataStructure = DataStructure +  "," + Name;
	EndDo;
	DataStructure = Mid(DataStructure, 2);
	
	Data = New Array;
	Item = Items.RecordSetsList;
	For Each Row In Item.SelectedRows Do
		curData = Item.RowData(Row);
		RowData = New Structure;
		For Each Name In KeyNames Do
			RowData.Insert(Name, curData["RecordSetsList" + Name]);
		EndDo;
		Data.Add(RowData);
	EndDo;
	
	If Data.Count() = 0 Then
		Return;
	EndIf;
	
	Choice = New Structure();
	Choice.Insert("TableName",RecordSetsListTableName);
	Choice.Insert("ChoiceData",Data);
	Choice.Insert("ChoiceAction",False);
	Choice.Insert("FieldStructure",DataStructure);
	DataChoiceProcessing(Items.RecordSetsList, Choice);
EndProcedure

&AtClient
Procedure DeleteRegistrationInRecordSetFilter()
	CurFormName = ThisFormName + "Form.SelectObjectsUsingFilter";
	CurParameters = New Structure("ChoiceAction, TableName", 
		False,
		RecordSetsListTableName);
	OpenForm(CurFormName, CurParameters, Items.RecordSetsList);
EndProcedure

&AtClient
Procedure AddSelectedObjectRegistration(NoAutoRegistration = True)
	
	Data = GetSelectedMetadataNames(NoAutoRegistration);
	Count = Data.MetaNames.Count();
	If Count = 0 Then
		// Current row
		Data = GetCurrentRowMetadataNames(NoAutoRegistration);
	EndIf;
	
	Text = NStr("ru = 'Добавить регистрацию %1 для выгрузки на узле ""%2""?
	                 |
	                 |Операция может занять некоторое время.'; 
	                 |en = 'Do you want to stage %1  to export to node ""%2""?
	                 |
	                 |This operation might take a while.'; 
	                 |pl = 'Czy chcesz zarejestrować %1 eksport do węzła ""%2""?
	                 |
	                 |Ta operacja może zająć jakiś czas.';
	                 |es_ES = '¿Quiere registrar %1 para exportar al nodo ""%2""?
	                 |
	                 |Esta operación puede tardar un poco.';
	                 |es_CO = '¿Quiere registrar %1 para exportar al nodo ""%2""?
	                 |
	                 |Esta operación puede tardar un poco.';
	                 |tr = '%1 öğesi, ""%2"" düğümüne aktarılmak üzere hazırlansın mı?
	                 |
	                 |Bu işlem uzun sürebilir.';
	                 |it = 'Impostare %1 per esportazione al nodo ""%2""?
	                 |
	                 |Questa operazione potrebbe richiedere un po'' di tempo.';
	                 |de = 'Möchten Sie %1  aufbereiten um zu Knoten ""%2"" zu exportieren?
	                 |
	                 |Diese Operation kann eine Weile dauern.'");
					 
	Text = StrReplace(Text, "%1", Data.Details);
	Text = StrReplace(Text, "%2", ExchangeNodeRef);
	
	QuestionTitle = NStr("ru = 'Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
	
	Notification = New NotifyDescription("AddSelectedObjectRegistrationCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("MetaNames", Data.MetaNames);
	Notification.AdditionalParameters.Insert("NoAutoRegistration", NoAutoRegistration);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Dialog continuation notification handler.
&AtClient 
Procedure AddSelectedObjectRegistrationCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	If Object.AsynchronousRegistrationAvailable Then
		BackgroundJobParameters = PrepareRegistrationChangeParameters(True, AdditionalParameters.NoAutoRegistration, 
										AdditionalParameters.MetaNames);
		BackgroundJobStartClient(BackgroundJobParameters);
	Else
		Result = AddRegistrationAtServer(AdditionalParameters.NoAutoRegistration, 
			AdditionalParameters.MetaNames);
		
		FillRegistrationCountInTreeRows();
		UpdatePageContent();
		ReportRegistrationResults(Result);
	EndIf;
EndProcedure

&AtClient
Procedure DeleteSelectedObjectRegistration(NoAutoRegistration = True)
	
	Data = GetSelectedMetadataNames(NoAutoRegistration);
	Count = Data.MetaNames.Count();
	If Count = 0 Then
		Data = GetCurrentRowMetadataNames(NoAutoRegistration);
	EndIf;
	
	Text = NStr("ru = 'Отменить регистрацию %1 для выгрузки на узле ""%2""?
	                 |
	                 |Изменение регистрации большого количества объектов может занять продолжительное время.'; 
	                 |en = 'Do you want to unstage %1 for export to node ""%2""? 
	                 |
	                 |This might take a while.'; 
	                 |pl = 'Czy chcesz anulować rejestrację %1 eksportu do węzła ""%2""?
	                 |
	                 |Ta operacja może zająć jakiś czas.';
	                 |es_ES = '¿Quiere cancelar el registro %1 para exportarlo al nodo ""%2""?
	                 |
	                 |Esto puede llevar un tiempo.';
	                 |es_CO = '¿Quiere cancelar el registro %1 para exportarlo al nodo ""%2""?
	                 |
	                 |Esto puede llevar un tiempo.';
	                 |tr = '""%2"" düğümüne aktarılacak %1 öğesi kaldırılsın mı?
	                 |
	                 |Bu işlem uzun sürebilir.';
	                 |it = 'Rimuovoere %1 per l''esportazione al nodo ""%2""?
	                 |
	                 |Questa operazione potrebbe richiedere un po'' di tempo.';
	                 |de = 'Möchten Sie Aufbereitung von %1 aufheben um zu Knoten ""%2"" zu exportieren?
	                 |
	                 |Dies kann eine Weile dauern.'");
	
	QuestionTitle = NStr("ru = 'Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
	
	Text = StrReplace(Text, "%1", Data.Details);
	Text = StrReplace(Text, "%2", ExchangeNodeRef);
	
	Notification = New NotifyDescription("DeleteSelectedObjectRegistrationCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("MetaNames", Data.MetaNames);
	Notification.AdditionalParameters.Insert("NoAutoRegistration", NoAutoRegistration);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Dialog continuation notification handler.
&AtClient
Procedure DeleteSelectedObjectRegistrationCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	If Object.AsynchronousRegistrationAvailable Then
		BackgroundJobParameters = PrepareRegistrationChangeParameters(False, AdditionalParameters.NoAutoRegistration, 
										AdditionalParameters.MetaNames);
		BackgroundJobStartClient(BackgroundJobParameters);
	Else
		ReportRegistrationResults(DeleteRegistrationAtServer(AdditionalParameters.NoAutoRegistration, 
				AdditionalParameters.MetaNames));
			
		FillRegistrationCountInTreeRows();
		UpdatePageContent();
	EndIf;
EndProcedure

&AtClient
Procedure BackgroundJobStartClient(BackgroundJobParameters)
	TimeConsumingOperationStarted = True;
	TimeConsumingOperationKind = ?(BackgroundJobParameters.Command, True, False);
	AttachIdleHandler("TimeConsumingOperationPage", 0.1, True);
	Result = ScheduledJobStartAtServer(BackgroundJobParameters);
	If Result = Undefined Then
		TimeConsumingOperationStarted = False;
		WarningText = NStr("ru='При запуске фонового задания с целью изменения регистрации произошла ошибка.'; en = 'Error starting background job.'; pl = 'Błąd podczas uruchomienia zadania w tle.';es_ES = 'Error al iniciar la tarea de fondo.';es_CO = 'Error al iniciar la tarea de fondo.';tr = 'Arka plan işi başlatılırken hata oluştu.';it = 'Errore durante l''avvio del processo in background.';de = 'Fehler beim Starten des Hintergrundjobs.'");
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	CommonModuleTimeConsumingOperationsClient = CommonModuleTimeConsumingOperationsClient();
	If Result.Status = "Running" Then
		IdleParameters = CommonModuleTimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow  = False;
		IdleParameters.OutputMessages     = True;
		
		CompletionNotification = New NotifyDescription("BackgroundJobCompletion", ThisObject);
		CommonModuleTimeConsumingOperationsClient.WaitForCompletion(Result, CompletionNotification, IdleParameters);
	Else
		BackgroundJobExecutionResult = Result;
		AttachIdleHandler("BackgroundJobExecutionResult", 0.1, True);
	EndIf;
EndProcedure

&AtClient
Procedure TimeConsumingOperationPage()
	If NOT TimeConsumingOperationStarted Then
		Return;
	EndIf;
	If TimeConsumingOperationKind Then
		OperationStatus = NStr("ru='Выполняется регистрация изменений. Пожалуйста, подождите.'; en = 'Staging in progress. Please wait.'; pl = 'Rejestracja w toku. Proszę czekać.';es_ES = 'Registro en progreso. Por favor, espere.';es_CO = 'Registro en progreso. Por favor, espere.';tr = 'Hazırlama devam ediyor. Lütfen bekleyin.';it = 'Impostazione in corso, attendere...';de = 'Aufbereitung läuft. Bitte warten.'");
	Else
		OperationStatus = NStr("ru='Выполняется отмена регистрации изменений. Пожалуйста, подождите.'; en = 'Unstaging in progress. Please wait.'; pl = 'Anulowanie rejestracji w toku. Proszę czekać.';es_ES = 'Cancelación del registro en progreso. Por favor, espere.';es_CO = 'Cancelación del registro en progreso. Por favor, espere.';tr = 'Kaldırma devam ediyor. Lütfen bekleyin.';it = 'Rimozione in corso, attendere...';de = 'Aufhebung der Aufbereitung läuft. Bitte warten.'");
	EndIf;
	Items.TimeConsumingOperationStatus.Title = OperationStatus;
	Items.PagesGroup.CurrentPage = Items.Wait;
EndProcedure

&AtClient
Procedure BackgroundJobCompletion(Result, AdditionalParameters) Export
	
	BackgroundJobExecutionResult = Result;
	BackgroundJobExecutionResult();
	
EndProcedure

&AtClient
Procedure BackgroundJobExecutionResult()
	BackgroundJobGetResultAtServer();
	TimeConsumingOperationStarted = False;
	
	Items.PagesGroup.CurrentPage = Items.Default;
	CurrentItem = Items.MetadataTree;
	
	If ValueIsFilled(ErrorMessage) Then
		Message = New UserMessage;
		Message.Text = ErrorMessage;
		Message.Message();
	EndIf;
	If BackgroundJobExecutionResult.Property("AdditionalResultData")
		AND BackgroundJobExecutionResult.AdditionalResultData.Property("Command") Then
		ReportRegistrationResults(BackgroundJobExecutionResult.AdditionalResultData);
		FillRegistrationCountInTreeRows();
		UpdatePageContent();
	EndIf;
EndProcedure

&AtServer
Function ScheduledJobStartAtServer(BackgroundJobParameters)
	ModuleTimeConsumingOperations = CommonModuleTimeConsumingOperations();
	ExecutionParameters = ModuleTimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.AdditionalResult = False;
	
	If BackgroundJobParameters.Property("AddressData") Then
		// Data storage address is passed.
		Result = GetFromTempStorage(BackgroundJobParameters.AddressData);
		Result= Result[Result.UBound()];
		Data = Result.Unload().UnloadColumn("Ref");
		BackgroundJobParameters.Insert("Data", Data);
	EndIf;
	ProcedureName = FormAttributeToValue("Object").Metadata().FullName() + ".ObjectModule.ChangeRegistration";
	Result = ModuleTimeConsumingOperations.ExecuteInBackground(ProcedureName, BackgroundJobParameters, ExecutionParameters);
	BackgroundJobID  = Result.JobID;
	BackgroundJobStorageAddress = Result.ResultAddress;
	Return Result;
EndFunction

&AtServer
Procedure BackgroundJobGetResultAtServer()
	BackgroundJobExecutionResult.Insert("AdditionalResultData", New Structure());
	ErrorMessage = "";
	StandardErrorPresentation = NStr("ru='При изменении регистрации произошла ошибка. Подробности см. в журнале регистрации.'; en = 'Error changing stage state. See the Event log for details.'; pl = 'Błąd podczas zmiany statusu rejestracji. Zobacz szczegóły w dzienniku.';es_ES = 'Error al cambiar el estado del registro. Véase el registro de eventos para más detalles.';es_CO = 'Error al cambiar el estado del registro. Véase el registro de eventos para más detalles.';tr = 'Hazırlama durumu değiştirilirken hata oluştu. Ayrıntılar için olay günlüğüne başvurabilirsiniz.';it = 'Errore durante la modifica dello stato impostazione. Visualizzare il Registro degli eventi per dettagli.';de = 'Fehler beim Ändern des Etappenstatus. Siehe Ereignisprotokoll für Details.'");
	If BackgroundJobExecutionResult.Status = "Error" Then
		ErrorMessage = BackgroundJobExecutionResult.DetailedErrorPresentation;
	Else
		
		BackgroundExecutionResult = GetFromTempStorage(BackgroundJobStorageAddress);
		
		If BackgroundExecutionResult = Undefined Then
			ErrorMessage = StandardErrorPresentation;
		Else
			BackgroundJobExecutionResult.AdditionalResultData = BackgroundExecutionResult;
			DeleteFromTempStorage(BackgroundJobStorageAddress);
		EndIf;
	EndIf;
	BackgroundJobStorageAddress = Undefined;
	BackgroundJobID  = Undefined;
EndProcedure

// Returns a reference to the TimeConsumingOperationsClient common module.
//
// Returns:
//  CommonModule - the TimeConsumingOperationsClient common module.
//
&AtClient
Function CommonModuleTimeConsumingOperationsClient()
	
	// Calling CalculateInSafeMode is not required as a string literal is being passed for calculation.
	Module = Eval("TimeConsumingOperationsClient");
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise NStr("ru = 'Общий модуль ""TimeConsumingOperationsClient"" не найден.'; en = 'Common module TimeConsumingOperationsClient is not found.'; pl = 'Wspólny moduł TimeConsumingOperationsClient nie został znaleziony.';es_ES = 'Módulo común TimeConsumingOperationsClient no se ha encontrado.';es_CO = 'Módulo común TimeConsumingOperationsClient no se ha encontrado.';tr = 'Ortak modül ""TimeConsumingOperationsClient"" bulunamadı.';it = 'Modulo generale TimeConsumingOperationsClient non trovato.';de = 'Das allgemeine Modul ""LangfristigerBetriebsClient"" wurde nicht gefunden.'");
	EndIf;
	
	Return Module;
	
EndFunction

// Returns a reference to the TimeConsumingOperations common module.
//
// Returns:
//  CommonModule - the TimeConsumingOperations common module.
//
&AtServerNoContext
Function CommonModuleTimeConsumingOperations()

	If Metadata.CommonModules.Find("TimeConsumingOperations") <> Undefined Then
		// Calling CalculateInSafeMode is not required as a string literal is being passed for calculation.
		Module = Eval("TimeConsumingOperations");
	Else
		Module = Undefined;
	EndIf;
	
	If TypeOf(Module) <> Type("CommonModule") Then
		Raise NStr("ru = 'Общий модуль ""TimeConsumingOperations"" не найден.'; en = 'Common module TimeConsumingOperations is not found.'; pl = 'Wspólny moduł TimeConsumingOperations nie został znaleziony.';es_ES = 'Módulo común TimeConsumingOperations no se ha encontrado.';es_CO = 'Módulo común TimeConsumingOperations no se ha encontrado.';tr = 'Ortak modül ""TimeConsumingOperations"" bulunamadı.';it = 'Modulo generale TimeConsumingOperations non trovato.';de = 'Das allgemeine Modul ""LangristigerBetrieb"" wurde nicht gefunden.'");
	EndIf;
	
	Return Module;
	
EndFunction

&AtClient
Procedure DataChoiceProcessing(FormTable, SelectedValue)
	
	Ref = Undefined;
	Type    = TypeOf(SelectedValue);
	
	If Type = Type("Structure") Then
		If Not (SelectedValue.Property("TableName")
			AND SelectedValue.Property("ChoiceAction")
			AND SelectedValue.Property("ChoiceData")) Then
			// Waiting for the structure in the specified format.
			Return;
		EndIf;
		TableName = SelectedValue.TableName;
		Action   = SelectedValue.ChoiceAction;
		Data     = SelectedValue.ChoiceData;
	Else
		TableName = Undefined;
		Action = True;
		If Type = Type("Array") Then
			Data = SelectedValue;
		Else		
			Data = New Array;
			Data.Add(SelectedValue);
		EndIf;
		
		If Data.Count() = 1 Then
			Ref = Data[0];
		EndIf;
	EndIf;
	
	If Action Then
		Result = AddRegistrationAtServer(True, Data, TableName);
		
		FormTable.Refresh();
		FillRegistrationCountInTreeRows();
		ReportRegistrationResults(Result);
		
		FormTable.CurrentRow = Ref;
		Return;
	EndIf;
	
	If Ref = Undefined Then
		Text = NStr("ru = 'Отменить регистрацию выбранных объектов
		                 |на узле ""%1""?'; 
		                 |en = 'Do you want to unstage selected items
		                 |at node ""%1""?'; 
		                 |pl = 'Czy chesz anulować rejestrację wybranych elementów
		                 |na węźle ""%1""?';
		                 |es_ES = '¿Quiere cancelar el registro de los elementos seleccionados
		                 |en el nodo ""%1""?';
		                 |es_CO = '¿Quiere cancelar el registro de los elementos seleccionados
		                 |en el nodo ""%1""?';
		                 |tr = '""%1"" düğümünde
		                 |seçilen öğeler kaldırılsın mı?';
		                 |it = 'Rimuovere gli elementi selezionati
		                 |al nodo ""%1""?';
		                 |de = 'Möchten Sie Aufbereitung der ausgewählten Elemente 
		                 |beim Knoten node ""%1"" aufheben?'"); 
	Else
		Text = NStr("ru = 'Отменить регистрацию ""%2""
		                 |на узле ""%1?'; 
		                 |en = 'Do you want to unstage ""%2""
		                 |at node ""%1?'; 
		                 |pl = 'Czy chcesz anulować rejestrację ""%2""
		                 |na węźle ""%1?';
		                 |es_ES = '¿Quiere cancelar el registro de ""%2""
		                 |en el nodo ""%1""?';
		                 |es_CO = '¿Quiere cancelar el registro de ""%2""
		                 |en el nodo ""%1""?';
		                 |tr = '""%1"" düğümünde
		                 |""%2"" kaldırılsın mı?';
		                 |it = 'Rimuovere ""%2""
		                 |al nodo ""%1""?';
		                 |de = 'Möchten Sie Aufbereitung für ""%2""
		                 | beim Knoten node ""%1"" aufheben?'"); 
	EndIf;
		
	Text = StrReplace(Text, "%1", ExchangeNodeRef);
	Text = StrReplace(Text, "%2", Ref);
	
	QuestionTitle = NStr("ru = 'Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
		
	Notification = New NotifyDescription("DataChoiceProcessingCompletion", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("Action",     Action);
	Notification.AdditionalParameters.Insert("FormTable", FormTable);
	Notification.AdditionalParameters.Insert("Data",       Data);
	Notification.AdditionalParameters.Insert("TableName",   TableName);
	Notification.AdditionalParameters.Insert("Ref",       Ref);
	
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

// Dialog continuation notification handler.
&AtClient
Procedure DataChoiceProcessingCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	If Object.AsynchronousRegistrationAvailable Then
		BackgroundJobParameters = PrepareRegistrationChangeParameters(False, True, AdditionalParameters.Data, 
										AdditionalParameters.TableName);
		BackgroundJobStartClient(BackgroundJobParameters);
	Else
		Result = DeleteRegistrationAtServer(True, AdditionalParameters.Data, AdditionalParameters.TableName);
	
		AdditionalParameters.FormTable.Refresh();
		FillRegistrationCountInTreeRows();
		ReportRegistrationResults(Result);
	EndIf;
	
	AdditionalParameters.FormTable.CurrentRow = AdditionalParameters.Ref;
EndProcedure

&AtServer
Procedure UpdatePageContent(Page = Undefined)
	CurrRow = ?(Page = Undefined, Items.ObjectsListOptions.CurrentPage, Page);
	
	If CurrRow = Items.ReferencesListPage Then
		Items.RefsList.Refresh();
		
	ElsIf CurrRow = Items.ConstantsPage Then
		Items.ConstantsList.Refresh();
		
	ElsIf CurrRow = Items.RecordSetPage Then
		Items.RecordSetsList.Refresh();
		
	ElsIf CurrRow = Items.BlankPage Then
		Row = Items.MetadataTree.CurrentRow;
		If Row <> Undefined Then
			Data = MetadataTree.FindByID(Row);
			If Data <> Undefined Then
				SetUpEmptyPage(Data.Description, Data.MetaFullName);
			EndIf;
		EndIf;
	EndIf;
EndProcedure	

&AtClient
Function GetCurrentObjectToEdit()
	
	CurrRow = Items.ObjectsListOptions.CurrentPage;
	
	If CurrRow = Items.ReferencesListPage Then
		Data = Items.RefsList.CurrentData;
		If Data <> Undefined Then
			Return Data.Ref; 
		EndIf;
		
	ElsIf CurrRow = Items.ConstantsPage Then
		Data = Items.ConstantsList.CurrentData;
		If Data <> Undefined Then
			Return Data.MetaFullName; 
		EndIf;
		
	ElsIf CurrRow = Items.RecordSetPage Then
		Data = Items.RecordSetsList.CurrentData;
		If Data <> Undefined Then
			Result = New Structure;
			Dimensions = RecordSetKeyNameArray(RecordSetsListTableName);
			For Each Name In Dimensions  Do
				Result.Insert(Name, Data["RecordSetsList" + Name]);
			EndDo;
		EndIf;
		Return Result;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

&AtClient
Procedure OpenDataProcessorSettingsForm()
	CurFormName = ThisFormName + "Form.Settings";
	OpenForm(CurFormName, , ThisObject);
EndProcedure

&AtClient
Procedure ActionWithQueryResult(ActionCommand)
	
	CurFormName = GetQueryResultChoiceForm();
	If CurFormName <> Undefined Then
		// Opening form
		If ActionCommand Then
			Text = NStr("ru = 'Регистрация изменений результата запроса'; en = 'Stage query results'; pl = 'Rejestracja wyników zapytania';es_ES = 'Registro de los resultados de la solicitud';es_CO = 'Registro de los resultados de la solicitud';tr = 'Sorgu sonuçlarını hazırla';it = 'Impostare risultati query';de = 'Abfrageergebnisse aufbereiten'");
		Else
			Text = NStr("ru = 'Отмена регистрации изменений результата запроса'; en = 'Unstage query results'; pl = 'Anulowanie rejestracji wyników zapytania';es_ES = 'Cancelar el registro de los resultados de la solicitud';es_CO = 'Cancelar el registro de los resultados de la solicitud';tr = 'Sorgu sonuçlarını kaldır';it = 'Rimuovere risultati query';de = 'Aufbereitung von Abfrageergebnissen aufheben'");
		EndIf;
		ParametersStructure = New Structure();
		ParametersStructure.Insert("Title", Text);
		ParametersStructure.Insert("ChoiceAction", ActionCommand);
		ParametersStructure.Insert("ChoiceMode", True);
		ParametersStructure.Insert("CloseOnChoice", False);
		OpenForm(CurFormName, ParametersStructure, ThisObject);
		Return;
	EndIf;
	
	// If the query execution handler is not specified, prompting the user to specify it.
	Text = NStr("ru = 'В настройках не указана обработка для выполнения запросов.
	                        |Настроить сейчас?'; 
	                        |en = 'Query data processor not specified.
							|Do you want to specify it now?'; 
	                        |pl = 'Nie wybrano zapytania procesora danych.
	                        |Czy chcesz wybrać go teraz?';
	                        |es_ES = 'No se ha especificado el procesador de datos de la solicitud.
	                        |¿Quiere especificarlo ahora?';
	                        |es_CO = 'No se ha especificado el procesador de datos de la solicitud.
	                        |¿Quiere especificarlo ahora?';
	                        |tr = 'Sorgu veri işlemcisi belirtilmedi.
	                        |Şimdi belirtmek ister misiniz?';
	                        |it = 'Elaboratore dati query non indicato.
	                        | Indicarlo adesso?';
	                        |de = 'Abfragedatenprozessor nicht angegeben.
	                        |Möchten Sie ihn jetzt angeben?'");
	
	QuestionTitle = NStr("ru = 'Настройки'; en = 'Settings'; pl = 'Ustawienia';es_ES = 'Configuraciones';es_CO = 'Configuraciones';tr = 'Ayarlar';it = 'Impostazioni';de = 'Einstellungen'");

	Notification = New NotifyDescription("ActionWithQueryResultsCompletion", ThisObject);
	ShowQueryBox(Notification, Text, QuestionDialogMode.YesNo, , , QuestionTitle);
EndProcedure

// Dialog continuation notification handler.
&AtClient 
Procedure ActionWithQueryResultsCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	OpenDataProcessorSettingsForm();
EndProcedure

&AtServer
Function ProcessQuotationMarksInRow(Row)
	Return StrReplace(Row, """", """""");
EndFunction

&AtServer
Function ThisObject(CurrentObject = Undefined) 
	If CurrentObject = Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(CurrentObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function GetFormName(CurrentObject = Undefined)
	Return ThisObject().GetFormName(CurrentObject);
EndFunction

&AtServer
Procedure ChangeMark(Row)
	DataItem = MetadataTree.FindByID(Row);
	ThisObject().ChangeMark(DataItem);
EndProcedure

&AtServer
Procedure ReadMetadataTree()
	Data = ThisObject().GenerateMetadataStructure(ExchangeNodeRef);
	
	// Deleting rows that cannot be edited.
	MetaTree = Data.Tree;
	For Each ListItem In NamesOfMetadataToHide Do
		DeleteMetadataValueTreeRows(ListItem.Value, MetaTree.Rows);
	EndDo;
	
	ValueToFormAttribute(MetaTree, "MetadataTree");
	MetadataAutoRecordStructure = Data.AutoRecordStructure;
	MetadataPresentationsStructure   = Data.PresentationStructure;
	MetadataNamesStructure            = Data.NamesStructure;
EndProcedure

&AtServer 
Procedure DeleteMetadataValueTreeRows(Val MetaFullName, TreeRows)
	If IsBlankString(MetaFullName) Then
		Return;
	EndIf;
	
	// In the current set
	Filter = New Structure("MetaFullName", MetaFullName);
	For Each DeletionRow In TreeRows.FindRows(Filter, False) Do
		TreeRows.Delete(DeletionRow);
		// If there are no subordinate rows left, deleting the parent row.
		If TreeRows.Count() = 0 Then
			ParentString = TreeRows.Parent;
			If ParentString.Parent <> Undefined Then
				ParentString.Parent.Rows.Delete(ParentString);
				// There are no subordinate rows.
				Return;
			EndIf;
		EndIf;
	EndDo;
	
	// Deleting subordinate row recursively.
	For Each TreeRow In TreeRows Do
		DeleteMetadataValueTreeRows(MetaFullName, TreeRow.Rows);
	EndDo;
EndProcedure

&AtServer
Procedure FormatChangeCount(Row)
	Row.ChangeCountString = Format(Row.ChangeCount, "NZ=") + " / " + Format(Row.NotExportedCount, "NZ=");
EndProcedure

&AtServer
Procedure FillRegistrationCountInTreeRows()
	
	Data = ThisObject().GetChangeCount(MetadataNamesStructure, ExchangeNodeRef);
	
	// Calculating and filling the number of changes, the number of exported items, and the number of items that are not exported
	Filter = New Structure("MetaFullName, ExchangeNode", Undefined, ExchangeNodeRef);
	Zeros   = New Structure("ChangeCount, ExportedCount, NotExportedCount", 0,0,0);
	
	For Each Root In MetadataTree.GetItems() Do
		RootSum = New Structure("ChangeCount, ExportedCount, NotExportedCount", 0,0,0);
		
		For Each Folder In Root.GetItems() Do
			GroupSum = New Structure("ChangeCount, ExportedCount, NotExportedCount", 0,0,0);
			
			NodesList = Folder.GetItems();
			If NodesList.Count() = 0 AND MetadataNamesStructure.Property(Folder.MetaFullName) Then
				// Node collection without nodes, sum manually and take auto record from structure.
				For Each MetaName In MetadataNamesStructure[Folder.MetaFullName] Do
					Filter.MetaFullName = MetaName;
					Found = Data.FindRows(Filter);
					If Found.Count() > 0 Then
						Row = Found[0];
						GroupSum.ChangeCount     = GroupSum.ChangeCount     + Row.ChangeCount;
						GroupSum.ExportedCount   = GroupSum.ExportedCount   + Row.ExportedCount;
						GroupSum.NotExportedCount = GroupSum.NotExportedCount + Row.NotExportedCount;
					EndIf;
				EndDo;
				
			Else
				// Calculating count values for each node
				For Each Node In NodesList Do
					Filter.MetaFullName = Node.MetaFullName;
					Found = Data.FindRows(Filter);
					If Found.Count() > 0 Then
						Row = Found[0];
						FillPropertyValues(Node, Row, "ChangeCount, ExportedCount, NotExportedCount");
						GroupSum.ChangeCount     = GroupSum.ChangeCount     + Row.ChangeCount;
						GroupSum.ExportedCount   = GroupSum.ExportedCount   + Row.ExportedCount;
						GroupSum.NotExportedCount = GroupSum.NotExportedCount + Row.NotExportedCount;
					Else
						FillPropertyValues(Node, Zeros);
					EndIf;
					
					FormatChangeCount(Node);
				EndDo;
				
			EndIf;
			FillPropertyValues(Folder, GroupSum);
			
			RootSum.ChangeCount     = RootSum.ChangeCount     + Folder.ChangeCount;
			RootSum.ExportedCount   = RootSum.ExportedCount   + Folder.ExportedCount;
			RootSum.NotExportedCount = RootSum.NotExportedCount + Folder.NotExportedCount;
			
			FormatChangeCount(Folder);
		EndDo;
		
		FillPropertyValues(Root, RootSum);
		
		FormatChangeCount(Root);
	EndDo;
	
EndProcedure

&AtServer
Function ChangeQueryResultRegistrationServer(Command, Address)
	
	Result = GetFromTempStorage(Address);
	Result= Result[Result.UBound()];
	Data = Result.Unload().UnloadColumn("Ref");
	
	If Command Then
		Return AddRegistrationAtServer(True, Data);
	EndIf;
		
	Return DeleteRegistrationAtServer(True, Data);
EndFunction

&AtServer
Function RefControlForQuerySelection(Address)
	
	Result = ?(Address = Undefined, Undefined, GetFromTempStorage(Address));
	If TypeOf(Result) = Type("Array") Then 
		Result = Result[Result.UBound()];	
		If Result.Columns.Find("Ref") = Undefined Then
			Return NStr("ru = 'В последнем результате запроса отсутствует колонка ""Ссылка""'; en = 'The last query result is missing the ""Reference"" column'; pl = 'W ostatnim wyniku zapytania brakuje kolumny ""Odniesienie""';es_ES = 'En el último resultado de la solicitud falta la columna ""Referencia""';es_CO = 'En el último resultado de la solicitud falta la columna ""Referencia""';tr = '""Referans"" sütununda son sorgu sonucu eksik';it = 'Nell''ultimo risultato di query manca la colonna ""Riferimento""';de = 'Das letzte Abfrageergebnis fehlt in der Spalte ""Referenz""'");
		EndIf;
	Else		
		Return NStr("ru = 'Ошибка получения данных результата запроса'; en = 'Error getting query result'; pl = 'Błąd podczas pobierania wyniku zapytania';es_ES = 'Error al recibir el resultado de la solicitud';es_CO = 'Error al recibir el resultado de la solicitud';tr = 'Sorgu sonucu alınırken hata oluştu';it = 'Errore durante la ricezione del risultato di query';de = 'Fehler beim Empfang des Abfrageergebnisses'");
	EndIf;
	
	Return "";
EndFunction

&AtServer
Procedure SetUpChangeEditingServer(CurrentRow)
	
	Data = MetadataTree.FindByID(CurrentRow);
	If Data = Undefined Then
		Return;
	EndIf;
	
	TableName   = Data.MetaFullName;
	Description = Data.Description;
	CurrentObject   = ThisObject();
	
	If IsBlankString(TableName) Then
		Meta = Undefined;
	Else		
		Meta = CurrentObject.MetadataByFullName(TableName);
	EndIf;
	
	If Meta = Undefined Then
		SetUpEmptyPage(Description, TableName);
		NewPage = Items.BlankPage;
		
	ElsIf Meta = Metadata.Constants Then
		// All constants are included in the list
		SetUpConstantList();
		NewPage = Items.ConstantsPage;
		
	ElsIf TypeOf(Meta) = Type("MetadataObjectCollection") Then
		// All catalogs, all documents, and so on
		SetUpEmptyPage(Description, TableName);
		NewPage = Items.BlankPage;
		
	ElsIf Metadata.Constants.Contains(Meta) Then
		// Single constant
		SetUpConstantList(TableName, Description);
		NewPage = Items.ConstantsPage;
		
	ElsIf Metadata.Catalogs.Contains(Meta) 
		Or Metadata.Documents.Contains(Meta)
		Or Metadata.ChartsOfCharacteristicTypes.Contains(Meta)
		Or Metadata.ChartsOfAccounts.Contains(Meta)
		Or Metadata.ChartsOfCalculationTypes.Contains(Meta)
		Or Metadata.BusinessProcesses.Contains(Meta)
		Or Metadata.Tasks.Contains(Meta) Then
		// Reference type
		SetUpRefList(TableName, Description);
		NewPage = Items.ReferencesListPage;
		
	Else
		// Checking whether a record set is passed
		Dimensions = CurrentObject.RecordSetDimensions(TableName);
		If Dimensions <> Undefined Then
			SetUpRecordSet(TableName, Dimensions, Description);
			NewPage = Items.RecordSetPage;
		Else
			SetUpEmptyPage(Description, TableName);
			NewPage = Items.BlankPage;
		EndIf;
		
	EndIf;
	
	Items.ConstantsPage.Visible    = False;
	Items.ReferencesListPage.Visible = False;
	Items.RecordSetPage.Visible = False;
	Items.BlankPage.Visible       = False;
	
	Items.ObjectsListOptions.CurrentPage = NewPage;
	NewPage.Visible = True;
	
	SetUpGeneralMenuCommandVisibility();
EndProcedure

// Displaying changes for a reference type (catalog, document, chart of characteristic types, chart 
// of accounts, calculation type, business processes, tasks.
//
&AtServer
Procedure SetUpRefList(TableName, Description)
	
	ListProperties = DynamicListPropertiesStructure();
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText = 
	"SELECT
	|	ChangesTable.Ref AS Ref,
	|	ChangesTable.MessageNo AS MessageNo,
	|	CASE
	|		WHEN ChangesTable.MessageNo IS NULL
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS NotExported,
	|	MainTable.Ref AS ObjectRef
	|FROM
	|	#ChangeTableName# AS ChangesTable
	|		LEFT JOIN #TableName# AS MainTable
	|		ON (MainTable.Ref = ChangesTable.Ref)
	|WHERE
	|	ChangesTable.Node = &SelectedNode";
	
	ListProperties.QueryText = StrReplace(ListProperties.QueryText, "#TableName#", TableName);
	ListProperties.QueryText = StrReplace(ListProperties.QueryText, "#ChangeTableName#", TableName + ".Changes");
		
	SetDynamicListProperties(Items.RefsList, ListProperties);
	
	RefsList.Parameters.SetParameterValue("SelectedNode", ExchangeNodeRef);
	ReferencesListTableName = TableName;
	
	// Object presentation
	Meta = ThisObject().MetadataByFullName(TableName);
	CurTitle = Meta.ObjectPresentation;
	If IsBlankString(CurTitle) Then
		CurTitle = Description;
	EndIf;
	Items.ReferencesListRefPresentation.Title = CurTitle;
EndProcedure

// Displaying changes for constants.
//
&AtServer
Procedure SetUpConstantList(TableName = Undefined, Description = "")
	
	If TableName = Undefined Then
		// All constants
		Names = MetadataNamesStructure.Constants;
		Presentations = MetadataPresentationsStructure.Constants;
		AutoRegistration = MetadataAutoRecordStructure.Constants;
	Else
		Names = New Array;
		Names.Add(TableName);
		Presentations = New Array;
		Presentations.Add(Description);
		Index = MetadataNamesStructure.Constants.Find(TableName);
		AutoRegistration = New Array;
		AutoRegistration.Add(MetadataAutoRecordStructure.Constants[Index]);
	EndIf;
	
	// The limit to the number of tables must be considered.
	Text = "";
	For Index = 0 To Names.UBound() Do
		Name = Names[Index];
		Text = Text + ?(Text = "", "SELECT", "UNION ALL SELECT") + "
		|	" + Format(AutoRegistration[Index], "NZ=; NG=") + " AS AutoRecordPictureIndex,
		|	2                                                   AS PictureIndex,
		|
		|	""" + ProcessQuotationMarksInRow(Presentations[Index]) + """ AS Description,
		|	""" + Name +                                     """ AS MetaFullName,
		|
		|	ChangesTable.MessageNo AS MessageNo,
		|	CASE 
		|		WHEN ChangesTable.MessageNo IS NULL THEN TRUE ELSE FALSE
		|	END AS NotExported
		|FROM
		|	" + Name + ".Changes AS ChangesTable
		|WHERE
		|	ChangesTable.Node = &SelectedNode
		|";
	EndDo;
	
	ListProperties = DynamicListPropertiesStructure();
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText = 
	"SELECT
	|	AutoRecordPictureIndex, PictureIndex, MetaFullName, NotExported,
	|	Description, MessageNo
	|
	|{SELECT
	|	AutoRecordPictureIndex, PictureIndex, 
	|	Description, MetaFullName, 
	|	MessageNo, NotExported
	|}
	|
	|FROM (" + Text + ") Data
	|
	|{WHERE
	|	Description, MessageNo, NotExported
	|}";
	
	SetDynamicListProperties(Items.ConstantsList, ListProperties);
		
	ListItems = ConstantsList.Order.Items;
	If ListItems.Count() = 0 Then
		Item = ListItems.Add(Type("DataCompositionOrderItem"));
		Item.Field = New DataCompositionField("Description");
		Item.Use = True;
	EndIf;
	
	ConstantsList.Parameters.SetParameterValue("SelectedNode", ExchangeNodeRef);
EndProcedure	

// Displaying cap with an empty page
&AtServer
Procedure SetUpEmptyPage(Description, TableName = Undefined)
	
	If TableName = Undefined Then
		CountsText = "";
	Else
		Tree = FormAttributeToValue("MetadataTree");
		Row = Tree.Rows.Find(TableName, "MetaFullName", True);
		If Row <> Undefined Then
			CountsText = NStr("ru = 'Объектов: 
			                          | • Зарегистрировано объектов: %1
			                          | • Выгружено объектов:%2
			                          | • Не выгружено объектов: %3'; 
			                          |en = 'Items:
									  | • Staged: %1
									  | • Exported: %2
									  | • Pending export: %3'; 
			                          |pl = 'Elementy:
			                          | • Zarejestrowano: %1
			                          | • Eksportowano: %2
			                          | • Eksport w toku: %3';
			                          |es_ES = 'Elementos:
			                          | • Registrar: %1
			                          | • Exportar: %2
			                          | • Pendiente de exportación: %3';
			                          |es_CO = 'Elementos:
			                          | • Registrar: %1
			                          | • Exportar: %2
			                          | • Pendiente de exportación: %3';
			                          |tr = 'Öğeler:
			                          | • Hazırlanan: %1
			                          | • Dışa aktarılan: %2
			                          | • Dışa aktarım bekleyen: %3';
			                          |it = 'Elementi:
			                          | • Impostati: %1
			                          | • Esportati: %2
			                          | • Esportazioni in attesa: %3';
			                          |de = 'Elemente:
			                          | • Aufbereitet: %1
			                          | • Exportiert: %2
			                          | • Export anstehend: %3'");
	
			CountsText = StrReplace(CountsText, "%1", Format(Row.ChangeCount, "NFD=0; NZ="));
			CountsText = StrReplace(CountsText, "%2", Format(Row.ExportedCount, "NFD=0; NZ="));
			CountsText = StrReplace(CountsText, "%3", Format(Row.NotExportedCount, "NFD=0; NZ="));
		EndIf;
	EndIf;
	
	Text = NStr("ru = '%1.
	                 |
	                 |%2
	                 |Для регистрации или отмены регистрации обмена данными на узле
	                 |""%3""
	                 |выберите тип объекта слева в дереве метаданных и воспользуйтесь
	                 |командами ""Зарегистрировать"" или ""Отменить регистрацию"".'; 
	                 |en = '%1.
					 |
					 |%2
					 |
					 |To stage or unstage items for exchange with node ""%3"",
					 |select an object in the metadata object tree
					 |and click Stage or Unstage.'; 
	                 |pl = '%1.
	                 |
	                 |%2
	                 |
	                 |Aby zarejestrować lub anulować rejestrację elementów do wymiany z węzłem ""%3"",
	                 |wybierz obiekt w drzewie obiektów metadanych
	                 |i kliknij Rejestruj lub Anuluj rejestrację.';
	                 |es_ES = '%1.
	                 |
	                 |%2
	                 |
	                 |Para registrar o cancelar el registro de los elementos para su intercambio con el nodo""%3"",
	                 |seleccione un objeto en el árbol de objetos de metadatos y 
	                 |haga clic en Registrar o Cancelar el registro.';
	                 |es_CO = '%1.
	                 |
	                 |%2
	                 |
	                 |Para registrar o cancelar el registro de los elementos para su intercambio con el nodo""%3"",
	                 |seleccione un objeto en el árbol de objetos de metadatos y 
	                 |haga clic en Registrar o Cancelar el registro.';
	                 |tr = '%1.
	                 |
	                 |%2
	                 |
	                 |Öğeleri ""%3"" düğümüyle değişime hazırlamak veya kaldırmak için,
	                 |meta veri nesne ağacında bir öğe seçin
	                 |ve Hazırla''ya veya Kaldır''a tıklayın.';
	                 |it = '%1.
	                 |
	                 |%2
	                 |
	                 |Per impostare o rimuovere elementi per lo scambio con il nodo ""%3"",
	                 | selezionare un oggetto nell''albero oggetti di metadati
	                 |e clicca Impostare o Rimuovere.';
	                 |de = '%1.
	                 |
	                 |%2
	                 |
	                 |Um Elemente für Austausch mit Knoten ""%3"" aufzubereiten oder deren Aufbereitung aufzuheben,
	                 |wählen Sie ein Objekt im Objektbaum von Metadaten aus
	                 |und klicken auf Aufbereiten oder Aufbereitung aufheben.'");
		
	Text = StrReplace(Text, "%1", Description);
	Text = StrReplace(Text, "%2", CountsText);
	Text = StrReplace(Text, "%3", ExchangeNodeRef);
	Items.EmptyPageDecoration.Title = Text;
EndProcedure

// Displaying changes for record sets.
//
&AtServer
Procedure SetUpRecordSet(TableName, Dimensions, Description)
	
	ChoiceText = "";
	Prefix     = "RecordSetsList";
	For Each Row In Dimensions Do
		Name = Row.Name;
		ChoiceText = ChoiceText + ",ChangesTable." + Name + " AS " + Prefix + Name + Chars.LF;
		// Adding the prefix to exclude the MessageNo and NotExported dimensions.
		Row.Name = Prefix + Name;
	EndDo;
	
	ListProperties = DynamicListPropertiesStructure();
	ListProperties.DynamicDataRead = True;
	ListProperties.QueryText = 
	"SELECT ALLOWED
	|	ChangesTable.MessageNo AS MessageNo,
	|	CASE 
	|		WHEN ChangesTable.MessageNo IS NULL THEN TRUE ELSE FALSE
	|	END AS NotExported
	|
	|	" + ChoiceText + "
	|FROM
	|	" + TableName + ".Changes AS ChangesTable
	|WHERE
	|	ChangesTable.Node = &SelectedNode";
	
	SetDynamicListProperties(Items.RecordSetsList, ListProperties);
	
	RecordSetsList.Parameters.SetParameterValue("SelectedNode", ExchangeNodeRef);
	
	// Adding columns to the appropriate group.
	ThisObject().AddColumnsToFormTable(
		Items.RecordSetsList, 
		"MessageNo, NotExported, 
		|Order, Filter, Group, StandardPicture, Parameters, ConditionalAppearance",
		Dimensions,
		Items.RecordSetsListDimensionsGroup);
	
	RecordSetsListTableName = TableName;
EndProcedure

// Common filter by the MessageNumber field.
//
&AtServer
Procedure SetFilterByMessageNo(DynamList, Option)
	
	Field = New DataCompositionField("NotExported");
	// Iterating through the filter item list to delete a specific item.
	ListItems = DynamList.Filter.Items;
	Index = ListItems.Count();
	While Index > 0 Do
		Index = Index - 1;
		Item = ListItems[Index];
		If Item.LeftValue = Field Then 
			ListItems.Delete(Item);
		EndIf;
	EndDo;
	
	FilterItem = ListItems.Add(Type("DataCompositionFilterItem"));
	FilterItem.LeftValue = Field;
	FilterItem.ComparisonType  = DataCompositionComparisonType.Equal;
	FilterItem.Use = False;
	FilterItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	If Option = 1 Then 		// Exported
		FilterItem.RightValue = False;
		FilterItem.Use  = True;
		
	ElsIf Option = 2 Then	// Not exported
		FilterItem.RightValue = True;
		FilterItem.Use  = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetUpGeneralMenuCommandVisibility()
	
	CurrRow = Items.ObjectsListOptions.CurrentPage;
	
	If CurrRow = Items.ConstantsPage Then
		Items.FormAddRegistrationForSingleObject.Enabled = True;
		Items.FormAddRegistrationFilter.Enabled         = False;
		Items.FormDeleteRegistrationForSingleObject.Enabled  = True;
		Items.FormDeleteRegistrationFilter.Enabled          = False;
		
	ElsIf CurrRow = Items.ReferencesListPage Then
		Items.FormAddRegistrationForSingleObject.Enabled = True;
		Items.FormAddRegistrationFilter.Enabled         = True;
		Items.FormDeleteRegistrationForSingleObject.Enabled  = True;
		Items.FormDeleteRegistrationFilter.Enabled          = True;
		
	ElsIf CurrRow = Items.RecordSetPage Then
		Items.FormAddRegistrationForSingleObject.Enabled = True;
		Items.FormAddRegistrationFilter.Enabled         = False;
		Items.FormDeleteRegistrationForSingleObject.Enabled  = True;
		Items.FormDeleteRegistrationFilter.Enabled          = False;
		
	Else
		Items.FormAddRegistrationForSingleObject.Enabled = False;
		Items.FormAddRegistrationFilter.Enabled         = False;
		Items.FormDeleteRegistrationForSingleObject.Enabled  = False;
		Items.FormDeleteRegistrationFilter.Enabled          = False;
		
	EndIf;
EndProcedure	

&AtServer
Function RecordSetKeyNameArray(TableName, NamesPrefix = "")
	Result = New Array;
	Dimensions = ThisObject().RecordSetDimensions(TableName);
	If Dimensions <> Undefined Then
		For Each Row In Dimensions Do
			Result.Add(NamesPrefix + Row.Name);
		EndDo;
	EndIf;
	Return Result;
EndFunction	

&AtServer
Function GetManagerByMetadata(TableName) 
	Details = ThisObject().MetadataCharacteristics(TableName);
	If Details <> Undefined Then
		Return Details.Manager;
	EndIf;
	Return Undefined;
EndFunction

&AtServer
Function SerializationText(Serializing)
	
	Text = New TextDocument;
	
	Record = New XMLWriter;
	For Each Item In Serializing Do
		Record.SetString("UTF-16");	
		Value = Undefined;
		
		If Item.TypeFlag = 1 Then
			// Metadata
			Manager = GetManagerByMetadata(Item.Data);
			Value = Manager.CreateValueManager();
			
		ElsIf Item.TypeFlag = 2 Then
			// Creating record set with a filter
			Manager = GetManagerByMetadata(RecordSetsListTableName);
			Value = Manager.CreateRecordSet();
			Filter = Value.Filter;
			For Each NameValue In Item.Data Do
				Filter[NameValue.Key].Set(NameValue.Value);
			EndDo;
			Value.Read();
			
		ElsIf Item.TypeFlag = 3 Then
			// Ref
			Value = Item.Data.GetObject();
			If Value = Undefined Then
				Value = New ObjectDeletion(Item.Data);
			EndIf;
		EndIf;
		
		WriteXML(Record, Value); 
		Text.AddLine(Record.Close());
	EndDo;
	
	Return Text;
EndFunction	

&AtServer
Function DeleteRegistrationAtServer(NoAutoRegistration, ToDelete, TableName = Undefined)
	RegistrationParameters = PrepareRegistrationChangeParameters(False, NoAutoRegistration, ToDelete, TableName);
	Return ThisObject().ChangeRegistration(RegistrationParameters);
EndFunction

&AtServer
Function AddRegistrationAtServer(NoAutoRegistration, ItemsToAdd, TableName = Undefined)
	RegistrationParameters = PrepareRegistrationChangeParameters(True, NoAutoRegistration, ItemsToAdd, TableName);
	Return ThisObject().ChangeRegistration(RegistrationParameters);
EndFunction

&AtServer
Function EditMessageNumberAtServer(MessageNumber, Data, TableName = Undefined)
	RegistrationParameters = PrepareRegistrationChangeParameters(MessageNumber, True, Data, TableName);
	Return ThisObject().ChangeRegistration(RegistrationParameters);
EndFunction

&AtServer
Function GetSelectedMetadataDetails(NoAutoRegistration, MetaGroupName = Undefined, MetaNodeName = Undefined)
    
	If MetaGroupName = Undefined AND MetaNodeName = Undefined Then
		// No item selected
		Text = NStr("ru = 'все объекты %1 по выбранной иерархии типа'; en = 'all items %1 of the metadata type'; pl = 'wszystkie elementy %1 typu metadanych';es_ES = 'todos los elementos %1 del tipo de metadatos';es_CO = 'todos los elementos %1 del tipo de metadatos';tr = 'meta veri türündeki tüm öğeler %1';it = 'tutti gli elementi %1 del tipo metadati';de = 'alle Elemente %1 des Metadatentyps'");
		
	ElsIf MetaGroupName <> Undefined AND MetaNodeName = Undefined Then
		// Only a group is specified.
		Text = "%2 %1";
		
	ElsIf MetaGroupName = Undefined AND MetaNodeName <> Undefined Then
		// Only a node is specified.
		Text = NStr("ru = 'все объекты %1 по выбранной иерархии типа'; en = 'all items %1 of the metadata type'; pl = 'wszystkie elementy %1 typu metadanych';es_ES = 'todos los elementos %1 del tipo de metadatos';es_CO = 'todos los elementos %1 del tipo de metadatos';tr = 'meta veri türündeki tüm öğeler %1';it = 'tutti gli elementi %1 del tipo metadati';de = 'alle Elemente %1 des Metadatentyps'");
		
	Else
		// A group and a node are specified, using these values to obtain a metadata presentation.
		Text = NStr("ru = 'все объекты ""%3"" типа %1'; en = 'all items of the ""%3"" type %1'; pl = 'wszystkie elementy ""%3"" typu %1';es_ES = 'todos los elementos ""%3"" del tipo %1';es_CO = 'todos los elementos ""%3"" del tipo %1';tr = '""%3"" türündeki %1 tüm öğeler';it = 'tutti gli elementi del tipo ""%3"" %1';de = 'alle Elemente des ""%3"" Typs %1'");
		
	EndIf;
	
	If NoAutoRegistration Then
		FlagText = "";
	Else
		FlagText = NStr("ru = 'с признаком авторегистрации'; en = 'with Autostage flag'; pl = 'z flagą automatycznej rejestracji';es_ES = 'con atributo de Auto registro';es_CO = 'con atributo de Auto registro';tr = 'Otomatik hazırlama işaretli';it = 'con contrassegno Autostage';de = 'mit Kennzeichen Automatische Aufbereitung'");
	EndIf;
	
	Presentation = "";
	For Each KeyValue In MetadataPresentationsStructure Do
		If KeyValue.Key = MetaGroupName Then
			Index = MetadataNamesStructure[MetaGroupName].Find(MetaNodeName);
			Presentation = ?(Index = Undefined, "", KeyValue.Value[Index]);
			Break;
		EndIf;
	EndDo;
	
	Text = StrReplace(Text, "%1", FlagText);
	Text = StrReplace(Text, "%2", Lower(MetaGroupName));
	Text = StrReplace(Text, "%3", Presentation);
	
	Return TrimAll(Text);
EndFunction

&AtServer
Function GetCurrentRowMetadataNames(NoAutoRegistration) 
	
	Row = MetadataTree.FindByID(Items.MetadataTree.CurrentRow);
	If Row = Undefined Then
		Return Undefined;
	EndIf;
	
	Result = New Structure("MetaNames, Details", 
		New Array, GetSelectedMetadataDetails(NoAutoRegistration));
	MetaName = Row.MetaFullName;
	If IsBlankString(MetaName) Then
		Result.MetaNames.Add(Undefined);	
	Else
		Result.MetaNames.Add(MetaName);	
		
		Parent = Row.GetParent();
		MetaParentName = Parent.MetaFullName;
		If IsBlankString(MetaParentName) Then
			Result.Details = GetSelectedMetadataDetails(NoAutoRegistration, Row.Description);
		Else
			Result.Details = GetSelectedMetadataDetails(NoAutoRegistration, MetaParentName, MetaName);
		EndIf;
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function GetSelectedMetadataNames(NoAutoRegistration)
	
	Result = New Structure("MetaNames, Details", 
		New Array, GetSelectedMetadataDetails(NoAutoRegistration));
	
	For Each Root In MetadataTree.GetItems() Do
		
		If Root.Check = 1 Then
			Result.MetaNames.Add(Undefined);
			Return Result;
		EndIf;
		
		NumberOfPartial = 0;
		GroupsCount     = 0;
		NodeCount     = 0;
		For Each Folder In Root.GetItems() Do
			
			If Folder.Check = 0 Then
				Continue;
			ElsIf Folder.Check = 1 Then
				//	Getting data of the selected group.
				GroupsCount = GroupsCount + 1;
				GroupDetails = GetSelectedMetadataDetails(NoAutoRegistration, Folder.Description);
				
				If Folder.GetItems().Count() = 0 Then
					// Reading marked data from the metadata names structure.
					PresentationsArray = MetadataPresentationsStructure[Folder.MetaFullName];
					AutoArray          = MetadataAutoRecordStructure[Folder.MetaFullName];
					NamesArray          = MetadataNamesStructure[Folder.MetaFullName];
					For Index = 0 To NamesArray.UBound() Do
						If NoAutoRegistration Or AutoArray[Index] = 2 Then
							Result.MetaNames.Add(NamesArray[Index]);
							NodeDetails = GetSelectedMetadataDetails(NoAutoRegistration, Folder.MetaFullName, NamesArray[Index]);
						EndIf;
					EndDo;
					
					Continue;
				EndIf;
				
			Else
				NumberOfPartial = NumberOfPartial + 1;
			EndIf;
			
			For Each Node In Folder.GetItems() Do
				If Node.Check = 1 Then
					// Node.AutoRecord = 2 -> allowed
					If NoAutoRegistration Or Node.AutoRegistration = 2 Then
						Result.MetaNames.Add(Node.MetaFullName);
						NodeDetails = GetSelectedMetadataDetails(NoAutoRegistration, Folder.MetaFullName, Node.MetaFullName);
						NodeCount = NodeCount + 1;
					EndIf;
				EndIf
			EndDo;
			
		EndDo;
		
		If GroupsCount = 1 AND NumberOfPartial = 0 Then
			Result.Details = GroupDetails;
		ElsIf GroupsCount = 0 AND NodeCount = 1 Then
			Result.Details = NodeDetails;
		EndIf;
		
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function ReadMessageNumbers()
	
	QueryAttributes = "SentNo, ReceivedNo";
	
	Data = ThisObject().GetExchangeNodeParameters(ExchangeNodeRef, QueryAttributes);
	
	Return Data;
	
EndFunction

&AtServer
Procedure ProcessNodeChangeProhibition()
	OperationsAllowed = Not SelectExchangeNodeProhibited;
	
	If OperationsAllowed Then
		Items.ExchangeNodeRef.Visible = True;
		Title = NStr("ru = 'Регистрация изменений для обмена данными'; en = 'Data staging manager'; pl = 'Menedżer rejestrowania danych';es_ES = 'Fecha de registro del gerente';es_CO = 'Fecha de registro del gerente';tr = 'Veri hazırlama yöneticisi';it = 'Responsabile data staging';de = 'Datenaufbereitungsmanager'");
	Else
		Items.ExchangeNodeRef.Visible = False;
		Title = StrReplace(NStr("ru = 'Регистрация изменений для обмена с  ""%1""'; en = 'Changes registration for exchange with ""%1""'; pl = 'Rejestracja zmian dla wymiany z ""%1""';es_ES = 'Registrar los cambios para intercambiar con ""%1""';es_CO = 'Registrar los cambios para intercambiar con ""%1""';tr = '""%1"" ile veri alışverişi için değişiklikleri kaydedin';it = 'Modifica della registrazione per lo scambio con ""%1""';de = 'Registrierung von Änderungen zum Austausch mit ""%1""'"), "%1", String(ExchangeNodeRef));
	EndIf;
	
	Items.FormOpenNodeRegistrationForm.Visible = OperationsAllowed;
	
	Items.ConstantsListContextMenuOpenNodeRegistrationForm.Visible       = OperationsAllowed;
	Items.ReferencesListContextMenuOpenNodeRegistrationForm.Visible         = OperationsAllowed;
	Items.RecordSetsListContextMenuOpenNodeRegistrationForm.Visible = OperationsAllowed;
EndProcedure

&AtServer
Function ControlSettings()
	Result = True;
	
	// Checking a specified exchange node.
	CurrentObject = ThisObject();
	If ExchangeNodeRef <> Undefined AND ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodeRef)) Then
		AllowedExchangeNodes = CurrentObject.GenerateNodeTree();
		PlanName = ExchangeNodeRef.Metadata().Name;
		If AllowedExchangeNodes.Rows.Find(PlanName, "ExchangePlanName", True) = Undefined Then
			// A node with an invalid exchange plan.
			ExchangeNodeRef = Undefined;
			Result = False;
		ElsIf ExchangeNodeRef = ExchangePlans[PlanName].ThisNode() Then
			// This node
			ExchangeNodeRef = Undefined;
			Result = False;
		EndIf;
	EndIf;
	
	If ValueIsFilled(ExchangeNodeRef) Then
		ExchangeNodeChoiceProcessingServer();
	EndIf;
	ProcessNodeChangeProhibition();
	
	// Settings relation
	SetFiltersInDynamicLists();
	
	Return Result;
EndFunction

&AtServer
Procedure SetFiltersInDynamicLists()
	SetFilterByMessageNo(ConstantsList,       FilterByMessageNumberOption);
	SetFilterByMessageNo(RefsList,         FilterByMessageNumberOption);
	SetFilterByMessageNo(RecordSetsList, FilterByMessageNumberOption);
EndProcedure

&AtServer
Function RecordSetKeyStructure(Val CurrentData)
	
	Details = ThisObject().MetadataCharacteristics(RecordSetsListTableName);
	
	If Details = Undefined Then
		// Unknown source
		Return Undefined;
	EndIf;
	
	Result = New Structure("FormName, Parameter, Value");
	
	Dimensions = New Structure;
	KeyNames = RecordSetKeyNameArray(RecordSetsListTableName);
	For Each Name In KeyNames Do
		Dimensions.Insert(Name, CurrentData["RecordSetsList" + Name]);
	EndDo;
	
	If Dimensions.Property("Recorder") Then
		MetaRecorder = Metadata.FindByType(TypeOf(Dimensions.Recorder));
		If MetaRecorder = Undefined Then
			Result = Undefined;
		Else
			Result.FormName = MetaRecorder.FullName() + ".ObjectForm";
			Result.Parameter = "Key";
			Result.Value = Dimensions.Recorder;
		EndIf;
		
	ElsIf Dimensions.Count() = 0 Then
		// Degenerated record set
		Result.FormName = RecordSetsListTableName + ".ListForm";
		
	Else
		Set = Details.Manager.CreateRecordSet();
		For Each KeyValue In Dimensions Do
			Set.Filter[KeyValue.Key].Set(KeyValue.Value);
		EndDo;
		Set.Read();
		If Set.Count() = 1 Then
			// Single item
			Result.FormName = RecordSetsListTableName + ".RecordForm";
			Result.Parameter = "Key";
			
			varKey = New Structure;
			For Each SetColumn In Set.Unload().Columns Do
				ColumnName = SetColumn.Name;
				varKey.Insert(ColumnName, Set[0][ColumnName]);
			EndDo;
			Result.Value = Details.Manager.CreateRecordKey(varKey);
		Else
			// List
			Result.FormName = RecordSetsListTableName + ".ListForm";
			Result.Parameter = "Filter";
			Result.Value = Dimensions;
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Function CheckPlatformVersionAndCompatibilityMode()
	
	Information = New SystemInfo;
	If Not (Left(Information.AppVersion, 3) = "8.3"
		AND (Metadata.CompatibilityMode = Metadata.ObjectProperties.CompatibilityMode.DontUse
		Or (Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_1
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode.Version8_2_13
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_2_16"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_1"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_2"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_3"]
		AND Metadata.CompatibilityMode <> Metadata.ObjectProperties.CompatibilityMode["Version8_3_4"]))) Then
		
		Raise NStr("ru = 'Обработка предназначена для запуска на версии платформы
			|1С:Предприятие 8.3.5 с отключенным режимом совместимости или выше'; 
			|en = 'The data processor is intended for use with 
			|1C:Enterprise 8.3.5 or later, with disabled compatibility mode'; 
			|pl = 'Przetwarzanie jest przeznaczona do uruchomienia na wersji platformy 
			|1C:Enterprise 8.3.5 z odłączonym trybem kompatybilności lub wyżej';
			|es_ES = 'El procesamiento se utiliza para lanzar en la versión de la plataforma
			|1C:Enterprise 8.3.5 con el modo de compatibilidad desactivado o superior';
			|es_CO = 'El procesamiento se utiliza para lanzar en la versión de la plataforma
			|1C:Enterprise 8.3.5 con el modo de compatibilidad desactivado o superior';
			|tr = 'İşlem, 
			|1C: İşletme 8.3 platform sürümü (veya üzeri) uyumluluk modu kapalı olarak başlamak için kullanılır';
			|it = 'L''elaborazione è predisposta per essere eseguita sulla versione della piattaforma
			|1C:Enterprise 8.3.5 con la modalità di compatibilità disabilitata o superiore';
			|de = 'Die Verarbeitung ist für
			|1C:Enterprise 8.3.5-Plattformversionen mit deaktiviertem oder höherem Kompatibilitätsmodus ausgelegt'");
		
	EndIf;
	
EndFunction

&AtServer
Function RegisterMOIDAndPredefinedItemsAtServer()
	
	CurrentObject = ThisObject();
	Return CurrentObject.SSL_UpdateAndRegisterMasterNodeMetadataObjectID(ExchangeNodeRef);
	
EndFunction

&AtServer
Function PrepareRegistrationChangeParameters(Command, NoAutoRegistration, Data, TableName = Undefined)
	Result = New Structure;
	Result.Insert("Command", Command);
	Result.Insert("NoAutoRegistration", NoAutoRegistration);
	Result.Insert("Node", ExchangeNodeRef);
	Result.Insert("Data", Data);
	Result.Insert("TableName", TableName);
	
	Result.Insert("ConfigurationSupportsSSL",       Object.ConfigurationSupportsSSL);
	Result.Insert("RegisterWithSSLMethodsAvailable",  Object.RegisterWithSSLMethodsAvailable);
	Result.Insert("DIBModeAvailable",                 Object.DIBModeAvailable);
	Result.Insert("ObjectExportControlSetting", Object.ObjectExportControlSetting);
	Return Result;
EndFunction

&AtServer
Procedure AddNameOfMetadataToHide()
	// Registers with the Node dimension are hidden
	For Each InformationRegisterMetadata In Metadata.InformationRegisters Do
		For Each RegisterDimension In Metadata.InformationRegisters[InformationRegisterMetadata.Name].Dimensions Do
			If Lower(RegisterDimension.Name) = "node" Then
				NamesOfMetadataToHide.Add("InformationRegister." + InformationRegisterMetadata.Name);
				Break;
			EndIf;
		EndDo;
	EndDo;
EndProcedure

&AtServer
Procedure SetDynamicListProperties(List, ParametersStructure)
	
	Form = List.Parent;
	ManagedFormType = Type("ClientApplicationForm");
	
	While TypeOf(Form) <> ManagedFormType Do
		Form = Form.Parent;
	EndDo;
	
	DynamicList = Form[List.DataPath];
	QueryText = ParametersStructure.QueryText;
	
	If Not IsBlankString(QueryText) Then
		DynamicList.QueryText = QueryText;
	EndIf;
	
	MainTable = ParametersStructure.MainTable;
	
	If Not IsBlankString(MainTable) Then
		DynamicList.MainTable = MainTable;
	EndIf;
	
	DynamicDataRead = ParametersStructure.DynamicDataRead;
	
	If TypeOf(DynamicDataRead) = Type("Boolean") Then
		DynamicList.DynamicDataRead = DynamicDataRead;
	EndIf;
	
EndProcedure

&AtServer
Function DynamicListPropertiesStructure()
	
	Return New Structure("QueryText, MainTable, DynamicDataRead");
	
EndFunction

#EndRegion
