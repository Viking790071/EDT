#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.Property("FileOwner") Then
		Record.FileOwner = Parameters.FileOwner;
		
		If Not ValueIsFilled(Parameters.Key) Then
			InitializeComposer();
		EndIf;
		
	EndIf;
	
	If AttributesArrayWithDateType.Count() = 0 Then
		Items.AddConditionByDate.Enabled = False;
	EndIf;
	
	If Parameters.Property("FileOwnerType") Then
		Record.FileOwnerType = Parameters.FileOwnerType;
	EndIf;
	
	If Parameters.Property("IsFile") Then
		Record.IsFile = Parameters.IsFile;
	EndIf;
	
	If Parameters.Property("NewSetting") Then
		NewSetting = Parameters.NewSetting;
	EndIf;
	
	If Record.FileOwner = Undefined Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Record.Account) Then
		FillSynchronizationAccount();
	EndIf;
	
	FileOwnerNotMetadataObjectsID = TypeOf(Record.FileOwner) <> Type("CatalogRef.MetadataObjectIDs");
	If FileOwnerNotMetadataObjectsID Then
		
		Common.MetadataObjectID(TypeOf(Record.FileOwner));
		SynchronizationObject = "OnlyItemFiles";
		
		FilesOwnerID = Common.MetadataObjectID(TypeOf(Record.FileOwner));
		PresentationFilesOwnerType = Record.FileOwnerType.Description;
		OwnerPresentationForTitle = Common.SubjectString(Record.FileOwner);
		CatalogItem = Record.FileOwner;
		
		ExistingSettingsList.LoadValues(ExistingSynchronizationObjects(TypeOf(Record.FileOwner)));
		
	Else
		
		ExistingSettingsList.LoadValues(ExistingSynchronizationObjects(TypeOf(Record.FileOwner.EmptyRefValue)));
		SynchronizationObject = "AllFiles";
		
		FilesOwnerID = Record.FileOwner;
		PresentationFilesOwnerType = Record.FileOwner.Description;
		OwnerPresentationForTitle = PresentationFilesOwnerType;
		CatalogItem = Record.FileOwner.EmptyRefValue;
		
	EndIf;
	
	If HasSyncRulesSettings(Record.FileOwner) 
		AND (NewSetting OR TypeOf(Record.FileOwner) <> Type("CatalogRef.MetadataObjectIDs")) Then
		Items.SyncObjectAllFiles.ReadOnly = True;
		Items.SyncRuleGroup.ReadOnly  = True;
		SynchronizationObject                                 = "OnlyItemFiles";
	EndIf;
	
	Title = NStr("ru='Настройка синхронизации файлов:'; en = 'Configure file synchronization:'; pl = 'Dostosowanie synchronizacji plików:';es_ES = 'Ajuste de sincronización de archivos:';es_CO = 'Ajuste de sincronización de archivos:';tr = 'Dosya eşleşmesinin ayarı:';it = 'Configura sincronizzazione file:';de = 'Einrichten der Dateisynchronisation:'") + " " + OwnerPresentationForTitle;
	
	Items.SetupRuleFilter.ExtendedTooltip.Title =
		StringFunctionsClientServer.SubstituteParametersToString(Items.SetupRuleFilter.ExtendedTooltip.Title, PresentationFilesOwnerType);
	Items.SyncObjectAllFiles.ChoiceList[0].Presentation = StringFunctionsClientServer.SubstituteParametersToString(Items.SyncObjectAllFiles.ChoiceList[0].Presentation, PresentationFilesOwnerType);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetFormItemEnabled();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If ValueIsFilled(CurrentObject.FileOwner) Then
		InitializeComposer();
	EndIf;
	If CurrentObject.FilterRule.Get() <> Undefined Then
		Rule.LoadSettings(CurrentObject.FilterRule.Get());
	EndIf;

EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If SynchronizationObject = "OnlyItemFiles" AND Not ValueIsFilled(CatalogItem) Then
		Cancel = True;
		CommonClientServer.MessageToUser(
			NStr("ru = 'Не заполнен объект с присоединенными файлами.'; en = 'Object with attached files is not entered.'; pl = 'Obiekt z dołączonymi plikami nie jest wypełniony.';es_ES = 'No está rellenado el objeto con los archivos adjuntos.';es_CO = 'No está rellenado el objeto con los archivos adjuntos.';tr = 'Ekli dosyalara sahip nesne doldurulmadı.';it = 'L''oggetto con il file allegati non è inserito.';de = 'Das Objekt mit angehängten Dateien wird nicht gefüllt.'"),
			,
			"CatalogItem");
	EndIf;
		
	Record.FileOwner = 
		?(SynchronizationObject = "AllFiles", FilesOwnerID, CatalogItem);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	FilterRule = Rule.GetSettings();
	
	If SynchronizationObject = "OnlyItemFiles" Then
		FilterRule.Filter.Items.Clear();
		CurrentObject.Description = "";
	EndIf;
	
	CurrentObject.FilterRule = New ValueStorage(FilterRule);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ReturnValue = New Structure;
	
	If SynchronizationObject = "OnlyItemFiles" Then
		ReturnValue.Insert("ObjectDescriptionSynonym", CurrentObject.FileOwner);
		HasFilterRules = False;
	Else
		ReturnValue.Insert("ObjectDescriptionSynonym", FilesOwnerID.Synonym);
		HasFilterRules = Rule.GetSettings().Filter.Items.Count() > 0;
	EndIf;
	ReturnValue.Insert("NewSetting",    NewSetting);
	ReturnValue.Insert("FileOwner",     CurrentObject.FileOwner);
	ReturnValue.Insert("FileOwnerType", CurrentObject.FileOwnerType);
	ReturnValue.Insert("Synchronize",  CurrentObject.Synchronize);
	ReturnValue.Insert("Description",      CurrentObject.Description);
	ReturnValue.Insert("Account",     CurrentObject.Account);
	ReturnValue.Insert("IsFile",           CurrentObject.IsFile);
	ReturnValue.Insert("Rule",           CurrentObject.FilterRule);
	ReturnValue.Insert("HasFilterRules", HasFilterRules);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "InformationRegister.FileSynchronizationSettings.Form.AddConditionByDate" Then
		AddToFilterIntervalException(SelectedValue);
	EndIf;
	
EndProcedure

&AtClient
Procedure SynchronizationObjectOnChange(Item)
	
	SetFormItemEnabled();
	Record.FileOwner = FilesOwnerID;
	
EndProcedure

&AtClient
Procedure SynchronizationObjectItemFilesOnChange(Item)
	
	SetFormItemEnabled();
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	NotifyChoice(ReturnValue);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure InitializeComposer()
	
	If Not ValueIsFilled(Record.FileOwner) Then
		Return;
	EndIf;
	
	Rule.Settings.Filter.Items.Clear();
	
	DCS = New DataCompositionSchema;
	DataSource = DCS.DataSources.Add();
	DataSource.Name = "DataSource1";
	DataSource.DataSourceType = "Local";
	
	DataSet = DCS.DataSets.Add(Type("DataCompositionSchemaDataSetQuery"));
	DataSet.Name = "DataSet1";
	DataSet.DataSource = DataSource.Name;
	
	DCS.TotalFields.Clear();
	
	DCS.DataSets[0].Query = GetQueryText();
	
	DataCompositionSchema = PutToTempStorage(DCS, UUID);
	
	Rule.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	
	Rule.Refresh(); 
	Rule.Settings.Structure.Clear();
	
EndProcedure

&AtServer
Function GetQueryText()
	
	AttributesArrayWithDateType.Clear();
	If TypeOf(Record.FileOwner) = Type("CatalogRef.MetadataObjectIDs") Then
		ObjectType = Record.FileOwner;
	Else
		ObjectType = Common.MetadataObjectID(TypeOf(Record.FileOwner));
	EndIf;
	AllCatalogs = Catalogs.AllRefsType();
	AllDocuments = Documents.AllRefsType();
	HasTypeDate = False;
	QueryText = 
		"SELECT
		|	" + ObjectType.Name + ".Ref,";
	If AllCatalogs.ContainsType(TypeOf(ObjectType.EmptyRefValue)) Then
		Catalog = Metadata.Catalogs[ObjectType.Name];
		For Each Attribute In Catalog.Attributes Do
			QueryText = QueryText + Chars.LF + ObjectType.Name + "." + Attribute.Name + ",";
		EndDo;
	ElsIf
		AllDocuments.ContainsType(TypeOf(ObjectType.EmptyRefValue)) Then
		Document = Metadata.Documents[ObjectType.Name];
		For Each Attribute In Document.Attributes Do
			QueryText = QueryText + Chars.LF + ObjectType.Name + "." + Attribute.Name + ",";
			If Attribute.Type.ContainsType(Type("Date")) Then
				AttributesArrayWithDateType.Add(Attribute.Name, Attribute.Synonym);
				QueryText = QueryText + Chars.LF + "DATEDIFF(" + Attribute.Name + ", &CurrentDate, DAY) AS DaysBeforeDeletionFrom" + Attribute.Name + ",";
				HasTypeDate = True;
			EndIf;
		EndDo;
	EndIf;
	
	// Deleting an extra comma
	QueryText= Left(QueryText, StrLen(QueryText) - 1);
	QueryText = QueryText + "
	               |FROM
	               |	" + ObjectType.FullName+ " AS " + ObjectType.Name;
	
	Return QueryText;
	
EndFunction

&AtClient
Procedure AddConditionByDate(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("ArrayOfValues", AttributesArrayWithDateType);
	OpenForm("InformationRegister.FileSynchronizationSettings.Form.AddConditionByDate", FormParameters, ThisObject);
	
EndProcedure

&AtServer
Procedure AddToFilterIntervalException(SelectedValue)
	
	FilterByInterval = Rule.Settings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterByInterval.LeftValue = New DataCompositionField("DaysBeforeDeletionFrom" + SelectedValue.DateTypeAttribute);
	FilterByInterval.ComparisonType = DataCompositionComparisonType.GreaterOrEqual;
	FilterByInterval.RightValue = SelectedValue.IntervalException;
	PresentationOfAttributeWithDateType = AttributesArrayWithDateType.FindByValue(SelectedValue.DateTypeAttribute).Presentation;
	PresentationText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Очищать спустя %1 дней относительно даты (%2)'; en = 'Clear after %1 days from date (%2)'; pl = 'Oczyszczaj po %1 dniach w stosunku do daty (%2)';es_ES = 'Vaciar pasados %1 días de la fecha (%2)';es_CO = 'Vaciar pasados %1 días de la fecha (%2)';tr = '(%1) tarihe göre %2 gün sonra temizle';it = 'Cancella dopo %1 giorni dalla data (%2)';de = 'Bereinigen nach %1 Tagen relativ zum Datum (%2)'"), 
		SelectedValue.IntervalException, PresentationOfAttributeWithDateType);
	FilterByInterval.Presentation = PresentationText;

EndProcedure

&AtClient
Procedure SetFormItemEnabled()
	
	CatalogSynchronization = SynchronizationObject = "AllFiles";
	
	Items.SyncRuleGroup.Enabled = CatalogSynchronization;
	Items.CatalogItem.Enabled = Not CatalogSynchronization;
	
EndProcedure

&AtClient
Procedure CatalogItemStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	ChoiceFormParameters = New Structure;
	
	ChoiceFormParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.FoldersAndItems);
	ChoiceFormParameters.Insert("CloseOnChoice", True);
	ChoiceFormParameters.Insert("CloseOnOwnerClose", True);
	ChoiceFormParameters.Insert("MultipleChoice", False);
	ChoiceFormParameters.Insert("ChoiceMode", True);
	
	ChoiceFormParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	ChoiceFormParameters.Insert("SelectFolders", True);
	ChoiceFormParameters.Insert("UsersGroupsSelection", True);
	
	ChoiceFormParameters.Insert("AdvancedPick", True);
	ChoiceFormParameters.Insert("PickFormHeader", NStr("ru = 'Подбор элементов настроек'; en = 'Settings item selection'; pl = 'Dobór elementów ustalania';es_ES = 'Selección de elementos de ajustes';es_CO = 'Selección de elementos de ajustes';tr = 'Ayar öğelerini seç';it = 'Impostazioni selezione elemento';de = 'Auswahl der Einstellmöglichkeiten'"));
	
	FixedSettings = New DataCompositionSettings;
	SettingItem = FixedSettings.Filter.Items.Add(Type("DataCompositionFilterItem"));
	SettingItem.LeftValue = New DataCompositionField("Ref");
	SettingItem.ComparisonType = DataCompositionComparisonType.NotInList;
	SettingItem.RightValue = ExistingSettingsList;
	SettingItem.Use = True;
	SettingItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ChoiceFormParameters.Insert("FixedSettings", FixedSettings);
	
	OpenForm(ChoiceFormPath(CatalogItem, FilesOwnerID), ChoiceFormParameters, Items.CatalogItem);
	
EndProcedure
 
&AtServerNoContext
Function ChoiceFormPath(FileOwner, FilesOwnerID)
	
	MetadataObject = Common.MetadataObjectByID(FilesOwnerID);
	Return MetadataObject.FullName() + ".ChoiceForm";
	
EndFunction

&AtServer
Function ExistingSynchronizationObjects(FileOwnerType)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	FileSynchronizationSettings.FileOwner
		|FROM
		|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|WHERE
		|	VALUETYPE(FileSynchronizationSettings.FileOwner) = &FileOwnerType";
	
	Query.SetParameter("FileOwnerType", FileOwnerType);
	
	QueryResult = Query.Execute();
	
	Return QueryResult.Unload().UnloadColumn("FileOwner");
	
EndFunction

&AtServer
Function HasSyncRulesSettings(FileOwner)
	
	Query = New Query;
	Query.Text = "SELECT TRUE AS HasSyncRulesSettings
		|FROM
		|	InformationRegister.FileSynchronizationSettings AS FileSynchronizationSettings
		|WHERE
		|	FileSynchronizationSettings.FileOwner = &FileOwner";
	
	Query.SetParameter("FileOwner", FileOwner);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return False;
	EndIf;
	
	Result = QueryResult.Unload()[0];

	Return ValueIsFilled(Result.HasSyncRulesSettings);
	
EndFunction

&AtServer
Procedure FillSynchronizationAccount()
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	FileSynchronizationAccounts.Ref
		|FROM
		|	Catalog.FileSynchronizationAccounts AS FileSynchronizationAccounts
		|WHERE
		|	NOT FileSynchronizationAccounts.DeletionMark";
	
	QueryResult = Query.Execute();
	
	DetailedRecordsSelection = QueryResult.Select();
	
	If DetailedRecordsSelection.Count() = 1 Then
		While DetailedRecordsSelection.Next() Do
			Record.Account = DetailedRecordsSelection.Ref;
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion