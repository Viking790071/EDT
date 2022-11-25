#Region Variables

&AtClient
Var IdleHandlerParameters;
&AtClient
Var LongOperationForm;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("Template",Template);
	
	If ValueIsFilled(Template) Then
		
		Items.Template.Visible = False;
		
		TemplatePresentation = StringFunctionsClientServer.SubstituteParametersToString("%1 (%2)", Template, Template.Metadata().Synonym);
		
		TemplateOnChangeAtServer();
		
	EndIf;
	
	DoNotCheckTemplateValidityPeriod = True;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	IsFileInfobase = StandardSubsystemsClientCached.ClientRunParameters().FileInfobase;
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(DocumentList, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtServer
Procedure TemplateOnChangeAtServer()
	
	If ValueIsFilled(Template) Then
		
		FilterCompany	= Template.Company;
		IsEmptyCompany	= Not ValueIsFilled(FilterCompany);
		TemplateStatus	= Template.Status;
		
		If ValueIsFilled(Template.DocumentType) Then
			RightValue = TypeOf(Template.DocumentType.EmptyRefValue);
		Else
			RightValue = Type("Undefined");
		EndIf;
		
		DriveClientServer.SetListFilterItem(
			DocumentList,
			"Type",
			RightValue,
			,
			DataCompositionComparisonType.Equal);
		
		If Not IsEmptyCompany Then
			
			DriveClientServer.SetListFilterItem(DocumentList, "Company", FilterCompany, Not IsEmptyCompany);
			
		EndIf;
		
	Else
		
		Filter = DocumentList.Filter;
		CommonClientServer.DeleteFilterItems(Filter, "Type");
		CommonClientServer.DeleteFilterItems(Filter, "Company");
		
		FilterCompany	= Undefined;
		IsEmptyCompany	= True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TemplateOnChange(Item)
	
	TemplateOnChangeAtServer();
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure FilterPeriodOnChange(Item)
	
	SetPeriod();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FormManagement()
	
	If TemplateStatus = PredefinedValue("Enum.AccountingEntriesTemplatesStatuses.Draft") Then
		Items.DoNotCheckTemplateValidityPeriod.Title = NStr("en = 'Do not apply template planned validity period'; ru = 'Не применять планируемый срок действия шаблона';pl = 'Nie stosuj planowanego okresu ważności szablonu';es_ES = 'No aplique la plantilla planificada para el período de validez';es_CO = 'No aplique la plantilla planificada para el período de validez';tr = 'Şablonun planlanan geçerlilik dönemini uygulama';it = 'Non applicare il periodo di validità previsto del modello';de = 'Geplante Vorlagengültigkeitsdauer nicht verwenden'");
	EndIf;
	
	Items.FilterCompany.Visible	 = Not IsEmptyCompany;
	Items.FilterCompany.Enabled	 = IsEmptyCompany;
	Items.RecordSetGroup.Visible = (RecordSet.Count() > 0);
	
EndProcedure

&AtServer
Procedure SetPeriod()

	Filter = DocumentList.Filter;
	CommonClientServer.DeleteFilterItems(Filter, "Date");
	
	If ValueIsFilled(FilterPeriodOfSourceDocuments.StartDate) Then
	
		CommonClientServer.AddCompositionItem(
			Filter,
			"Date",
			DataCompositionComparisonType.GreaterOrEqual,
			FilterPeriodOfSourceDocuments.StartDate,
			,
			ValueIsFilled(FilterPeriodOfSourceDocuments.StartDate));
			
	EndIf;
	
	If ValueIsFilled(FilterPeriodOfSourceDocuments.EndDate) Then
		
		CommonClientServer.AddCompositionItem(
			Filter,
			"Date",
			DataCompositionComparisonType.LessOrEqual,
			FilterPeriodOfSourceDocuments.EndDate,
			,
			ValueIsFilled(FilterPeriodOfSourceDocuments.EndDate));
		
	EndIf;

EndProcedure

&AtServer
Procedure RereadDataAtServer(Val Document, Val PresentationCurrency, MessagesArray)
	
	TimeConsumingOperations.CancelJobExecution(JobID);
	
	JobID = Undefined;
	
	TemplatesArray = New Array;
	TemplatesArray.Add(Template);
	
	TypeOfAccounting = Template.TypeOfAccounting;
	ChartOfAccounts	 = Template.ChartOfAccounts;
	Cancel = False;
	
	InstancesParameters = New Structure;
	InstancesParameters.Insert("ChartOfAccounts"					, ChartOfAccounts);
	InstancesParameters.Insert("PresentationCurrency"				, PresentationCurrency);
	InstancesParameters.Insert("Document"							, Document);
	InstancesParameters.Insert("Cancel"								, Cancel);
	InstancesParameters.Insert("TypeOfAccounting"					, TypeOfAccounting);
	InstancesParameters.Insert("TemplatesArray"						, TemplatesArray);
	InstancesParameters.Insert("DoNotCheckTemplateValidityPeriod"	, DoNotCheckTemplateValidityPeriod);
	
	If IsFileInfobase Then
		
		StorageAddress = PutToTempStorage(Undefined, UUID);
		DataProcessors.AccountingTemplatesTesting.GetAccountingEntriesTablesStructure(InstancesParameters, StorageAddress);
		ProccessResult(MessagesArray);
		
	Else
		
		ExecutionResult = TimeConsumingOperations.StartBackgroundExecution(
			UUID,
			"DataProcessors.AccountingTemplatesTesting.GetAccountingEntriesTablesStructure",
			InstancesParameters,
			"GetAccountingEntriesTablesStructureForTestPurpose");
		
		StorageAddress	= ExecutionResult.StorageAddress;
		JobID			= ExecutionResult.JobID;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteTablesAtServer()
	MasterAccountingFormGeneration.DeleteAttributes(ThisObject);
EndProcedure

&AtClient
Procedure RereadData(Command)
	
	CurrentSourceDocument = Undefined;
	ReadData();
	
EndProcedure

&AtClient
Procedure ReadData()
	
	CurrentData = Items.DocumentList.CurrentData;
	
	If CurrentData = Undefined Then
		
		AdditionalInformation = "";
		CurrentSourceDocument = Undefined;
		DeleteTablesAtServer();
		Return;
		
	EndIf;
	
	Document = CurrentData.Ref;
	
	If CurrentSourceDocument <> Document Then
		CurrentSourceDocument = Document;
	Else
		Return;
	EndIf;
	
	PresentationCurrency = CurrentData.PresentationCurrency;
	
	If ValueIsFilled(Document) And ValueIsFilled(Template) Then
		
		JobID = New UUID;
		LongOperationForm = TimeConsumingOperationsClient.OpenTimeConsumingOperationForm(ThisObject, JobID);
		
		If Not IsFileInfobase Then
			TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
		EndIf;
		
		MessagesArray = New Array;
		
		RereadDataAtServer(Document, PresentationCurrency, MessagesArray);
		
		If IsFileInfobase Then
			TimeConsumingOperationsClient.CloseTimeConsumingOperationForm(LongOperationForm);
		EndIf;
		
		ClearMessages();
		
		For Each MessageRow In MessagesArray Do
			CommonClientServer.MessageToUser(MessageRow.Text);
		EndDo;
		
	EndIf;
	
	If IsFileInfobase Then
		FormManagement();
	EndIf;
	
EndProcedure

&AtServer
Procedure FillRecordSetsMaster(RecordSetMasterSimpleTable, RecordSetMasterCompoundTable, TypeOfEntries)
	
	RecordSetMasterSimpleTable.Clear();
	RecordSetMasterCompoundTable.Clear();
	
	TablesMap = New Map;
	
	For Each MapRow In MasterTablesMap Do
		ThisObject[MapRow.TableName].Clear();
		
		If MapRow.Compound Then 
			TablesMap.Insert(MapRow.TableName, RecordSetMasterCompoundTable.CopyColumns());
		Else
			TablesMap.Insert(MapRow.TableName, RecordSetMasterSimpleTable.CopyColumns());
		EndIf;
	EndDo;
	
	For Each Row In RecordSetMaster Do
		
		SearchStructure = New Structure("TypeOfAccounting, TypeOfEntries", Row.TypeOfAccounting, TypeOfEntries);
		
		FoundRows = MasterTablesMap.FindRows(SearchStructure);
		
		If FoundRows.Count() > 0 Then
			
			CurrentTable = TablesMap.Get(FoundRows[0].TableName);
			
			TableName = FoundRows[0].TableName;
			
			NewRow = CurrentTable.Add();
			FillPropertyValues(NewRow, Row);
			
		EndIf;

		NewRow = RecordSetMasterCompoundTable.Add();
		FillPropertyValues(NewRow, Row);
		
	EndDo;
	
	For Each Row In RecordSetSimple Do
		
		SearchStructure = New Structure("TypeOfAccounting, TypeOfEntries", Row.TypeOfAccounting, TypeOfEntries);
		
		FoundRows = MasterTablesMap.FindRows(SearchStructure);
		
		If FoundRows.Count() > 0 Then
			
			CurrentTable = TablesMap.Get(FoundRows[0].TableName);
			
			TableName = FoundRows[0].TableName;
			
			NewRow = CurrentTable.Add();
			FillPropertyValues(NewRow, Row);
			
		EndIf;

		NewRow = RecordSetMasterSimpleTable.Add();
		FillPropertyValues(NewRow, Row);
		
	EndDo;
	
	SearchStructure = New Structure("TypeOfEntries", Enums.ChartsOfAccountsTypesOfEntries.Simple);
	
	FoundRows = MasterTablesMap.FindRows(SearchStructure);
	
	For Each MapRow In MasterTablesMap Do

		CurrentTable = ThisObject[MapRow.TableName]; 
		
		MapTable = TablesMap.Get(MapRow.TableName);
		
		Index = 1;
		For Each Row In MapTable Do
			
			Row.LineNumber = Index;
			Index = Index + 1;
			
		EndDo;
		
		CurrentTable.Load(MapTable);
		
	EndDo;
	
	DriveServer.ValueTableEnumerateRows(RecordSetMasterSimpleTable	, "LineNumber", 1);
	DriveServer.ValueTableEnumerateRows(RecordSetMasterCompoundTable, "LineNumber", 1);
	
EndProcedure

&AtClient
Procedure DocumentListOnActivateRow(Item)
	ReadData();
EndProcedure

&AtClient
Procedure DoNotCheckTemplateValidityPeriodOnChange(Item)
	
	CurrentSourceDocument = Undefined;
	ReadData();
	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return TimeConsumingOperations.JobCompleted(JobID);
	
EndFunction

&AtServer
Procedure ProccessResult(MessagesArray = Undefined)
	
	DataStructure = GetFromTempStorage(StorageAddress);
	If TypeOf(DataStructure) <> Type("Structure") Then
		AdditionalInformation = NStr("en = 'Execution error.'; ru = 'Ошибка выполнения.';pl = 'Błąd wykonania.';es_ES = 'Error de ejecución.';es_CO = 'Error de ejecución.';tr = 'Uygulama hatası.';it = 'Errore di esecuzione.';de = 'Ausführungsfehler'");
		Return;
	EndIf;
	
	Entries				 = DataStructure.Entries;
	Cancel				 = DataStructure.Cancel;
	TypeOfAccounting	 = DataStructure.TypeOfAccounting;
	ChartOfAccounts		 = DataStructure.ChartOfAccounts;
	PresentationCurrency = DataStructure.PresentationCurrency;
	
	If MasterTablesMap.Count() > 0 Then
		ThisObject[MasterTablesMap[0].TableName].Clear();
	EndIf;
	
	EntriesIsFilled = False;
	
	If ValueIsFilled(Template) Then
		
		IsComplexTypeOfEntries = WorkWithArbitraryParameters.SetComplexTypeOfEntries(Template.ChartOfAccounts, 0);
		
		TableName = ?(IsComplexTypeOfEntries, "Entries", "EntriesSimple");
		
		If Template[TableName].Count() > 0 Then
			EntriesIsFilled = True;
		EndIf;
		
	EndIf;
	
	If Cancel Then
		
		AdditionalInformation = MessagesToUserClientServer.GetTemplateTestingCommonErrorText();
		
		ErrorsArray = TimeConsumingOperations.UserMessages(True, JobID);
		
		MessagesArray = New Array(ErrorsArray);
		
	ElsIf Entries.Property("ErrorID") And EntriesIsFilled Then
		
		If Entries.ErrorID = "InvalidTemplatesPeriod" Then
			AdditionalInformation = MessagesToUserClientServer.GetTemplateTestingInvalidPeriodErrorText();
		ElsIf Entries.ErrorID = "InvalidTemplatesParameters" Then
			AdditionalInformation = MessagesToUserClientServer.GetTemplateTestingInvalidParametersErrorText();
		EndIf;
		
	ElsIf (Entries.TableAccountingJournalEntriesCompound = Undefined
		Or Entries.TableAccountingJournalEntriesCompound.Count() = 0)
		And (Entries.TableAccountingJournalEntriesSimple = Undefined
		Or Entries.TableAccountingJournalEntriesSimple.Count() = 0)
		And EntriesIsFilled Then
		
		AdditionalInformation = MessagesToUserClientServer.GetTemplateTestingInvalidParametersErrorText();
		
	Else
		
		AdditionalInformation = "";
		
	EndIf;
	
	If Entries.TableAccountingJournalEntries <> Undefined
		And Entries.TableAccountingJournalEntries.Count() > 0 Then
		
		If Entries.TableAccountingJournalEntries.Columns.Find("Active") = Undefined Then
			Entries.TableAccountingJournalEntries.Columns.Add("Active");
		EndIf;
		Entries.TableAccountingJournalEntries.FillValues(True, "Active");
		RecordSet.Load(Entries.TableAccountingJournalEntries);
		
	EndIf;
	
	If Entries.TableAccountingJournalEntriesCompound <> Undefined
		And Entries.TableAccountingJournalEntriesCompound.Count() > 0 Then
		
		If Entries.TableAccountingJournalEntriesCompound.Columns.Find("Active") = Undefined Then
			Entries.TableAccountingJournalEntriesCompound.Columns.Add("Active");
		EndIf;
		Entries.TableAccountingJournalEntriesCompound.FillValues(True, "Active");
		
	EndIf;
	
	If Entries.TableAccountingJournalEntriesSimple <> Undefined
		And Entries.TableAccountingJournalEntriesSimple.Count() > 0 Then
		
		If Entries.TableAccountingJournalEntriesSimple.Columns.Find("Active") = Undefined Then
			Entries.TableAccountingJournalEntriesSimple.Columns.Add("Active");
		EndIf;
		Entries.TableAccountingJournalEntriesSimple.FillValues(True, "Active");
		
	EndIf;
	
	If Entries.TableAccountingJournalEntriesCompound <> Undefined
		Or Entries.TableAccountingJournalEntriesSimple <> Undefined Then
		
		MasterAccountingFormGeneration.DeleteAttributes(ThisObject);
		RecordSetMaster.Load(Entries.TableAccountingJournalEntriesCompound);
		For Each Row In RecordSetMaster Do
			
			If Row.RecordType = AccountingRecordType.Debit Then
				Row.AmountDr	= Row.Amount;
				Row.AmountCurDr = Row.AmountCur;
				Row.QuantityDr	= Row.Quantity;
				Row.CurrencyDr	= Row.Currency;
			Else
				Row.AmountCr	= Row.Amount;
				Row.AmountCurCr = Row.AmountCur;
				Row.QuantityCr	= Row.Quantity;
				Row.CurrencyCr	= Row.Currency;
			EndIf;
			
		EndDo;
		
		RecordSetSimple.Load(Entries.TableAccountingJournalEntriesSimple);
		
		ChartOfAccountsAttributes = Common.ObjectAttributesValues(ChartOfAccounts, "TypeOfEntries, UseQuantity, UseAnalyticalDimensions");
		
		TableParameters = New Structure;
		TableParameters.Insert("TypeOfAccounting"		, TypeOfAccounting);
		TableParameters.Insert("ChartOfAccounts"		, ChartOfAccounts);
		TableParameters.Insert("TypeOfEntries"			, ChartOfAccountsAttributes.TypeOfEntries);
		TableParameters.Insert("PagesGroupName"			, "Pages");
		TableParameters.Insert("UseAnalyticalDimensions", ChartOfAccountsAttributes.UseAnalyticalDimensions);
		TableParameters.Insert("UseQuantity"			, ChartOfAccountsAttributes.UseQuantity);
		
		MasterAccountingFormGeneration.GenerateMasterTable(ThisObject, TableParameters, False);
		
		TempRecordSetMasterSimple	= RecordSetMasterSimple.Unload();
		TempRecordSetMasterCompound	= RecordSetMasterCompound.Unload();
		
		FillRecordSetsMaster(TempRecordSetMasterSimple, TempRecordSetMasterCompound, ChartOfAccountsAttributes.TypeOfEntries);
		
		AmountDrTitle = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Amount Dr (%1)'; ru = 'Сумма Дт (%1)';pl = 'Wartość Wn (%1)';es_ES = 'Importe Débito (%1)';es_CO = 'Importe Débito (%1)';tr = 'Tutar Borç (%1)';it = 'Importo deb (%1)';de = 'Betrag Soll (%1)'"), PresentationCurrency);
		AmountCrTitle = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Amount Cr (%1)'; ru = 'Сумма Кт (%1)';pl = 'Wartość Ma (%1)';es_ES = 'Importe Crédito (%1)';es_CO = 'Importe Crédito (%1)';tr = 'Tutar Alacak (%1)';it = 'Importo cred (%1)';de = 'Betrag Haben (%1)'"), PresentationCurrency);
		
		For Each Table In MasterTablesMap Do
			
			If Table.Compound Then
				Items[StringFunctionsClientServer.SubstituteParametersToString("%1AmountDr", Table.TableName)].Title = AmountDrTitle;
				Items[StringFunctionsClientServer.SubstituteParametersToString("%1AmountCr", Table.TableName)].Title = AmountCrTitle;
			EndIf;
			
			Items[Table.TableName].ReadOnly = True;
			Items[Table.TableName].CommandBarLocation = FormItemCommandBarLabelLocation.None;
			
		EndDo;
		
	Else
		
		ChartOfAccountsAttributes = Common.ObjectAttributesValues(ChartOfAccounts, "TypeOfEntries, UseQuantity, UseAnalyticalDimensions");
		
		TableParameters = New Structure;
		TableParameters.Insert("TypeOfAccounting"		, TypeOfAccounting);
		TableParameters.Insert("ChartOfAccounts"		, ChartOfAccounts);
		TableParameters.Insert("TypeOfEntries"			, ChartOfAccountsAttributes.TypeOfEntries);
		TableParameters.Insert("PagesGroupName"			, "Pages");
		TableParameters.Insert("UseAnalyticalDimensions", ChartOfAccountsAttributes.UseAnalyticalDimensions);
		TableParameters.Insert("UseQuantity"			, ChartOfAccountsAttributes.UseQuantity);
		
		MasterAccountingFormGeneration.GenerateMasterTable(ThisObject, TableParameters, False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		
		If JobCompleted(JobID) Then
			
			MessagesArray = New Array;
		
			TimeConsumingOperationsClient.CloseTimeConsumingOperationForm(LongOperationForm);
			
			ProccessResult(MessagesArray);
			
			ClearMessages();
			
			For Each MessageRow In MessagesArray Do
				CommonClientServer.MessageToUser(MessageRow.Text);
			EndDo;
			
			FormManagement();
			
		Else
			
			TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution", 
				IdleHandlerParameters.CurrentInterval, 
				True);
			
		EndIf;
			
		Except
			
		TimeConsumingOperationsClient.CloseTimeConsumingOperationForm(LongOperationForm);
		Raise DetailErrorDescription(ErrorInfo());
		
	EndTry;
	
EndProcedure

#EndRegion