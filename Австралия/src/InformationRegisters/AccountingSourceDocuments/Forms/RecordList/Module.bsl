
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	HasEditRights = AccessRight("Edit", Metadata.InformationRegisters.AccountingSourceDocuments);
	
	Items.RecordListCreate.Visible						= HasEditRights;
	Items.RecordListCopyRecord.Visible					= HasEditRights;
	Items.RecordListDeleteRecords.Visible				= HasEditRights;
	Items.FormOpenDefaultList.Visible					= HasEditRights;
	Items.RecordListCopyRecord1.Visible					= HasEditRights;
	Items.RecordListContextMenuDeleteRecords.Visible	= HasEditRights;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlers

&AtClient
Procedure OnClosingInputDataDialog(ResultData, AdditionalParameters) Export
	
	If ResultData <> Undefined Then
		Items.RecordList.Refresh();
		Items.RecordList.CurrentRow = New DynamicListRowKey(ResultData);
	EndIf;
	
EndProcedure

&AtClient
Procedure RecordListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Item.CurrentData;
	
	FormParameters = New Structure;
	FormParameters.Insert("NewRecord"			, False);
	FormParameters.Insert("Period"				, CurrentData.Period);
	FormParameters.Insert("Company"				, CurrentData.Company);
	FormParameters.Insert("TypeOfAccounting"	, CurrentData.TypeOfAccounting);
	FormParameters.Insert("Author"				, CurrentData.Author);
		
	OpenForm("InformationRegister.AccountingSourceDocuments.Form.InputData",
		FormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("OnClosingInputDataDialog", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure OpenDefaultList(Command)
	OpenForm("InformationRegister.AccountingSourceDocuments.Form.ListForm");
EndProcedure

&AtClient
Procedure Create(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("NewRecord", True);
		
	OpenForm("InformationRegister.AccountingSourceDocuments.Form.InputData",
		FormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("OnClosingInputDataDialog", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure CopyRecord(Command)
	
	CurrentRow = Items.RecordList.CurrentData;

	If CurrentRow = Undefined Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("NewRecord"		, True);
	FormParameters.Insert("IsCopy"			, True);
	FormParameters.Insert("Company"			, CurrentRow.Company);
	FormParameters.Insert("TypeOfAccounting", CurrentRow.TypeOfAccounting);
	FormParameters.Insert("Period"			, CurrentRow.Period);
		
	OpenForm("InformationRegister.AccountingSourceDocuments.Form.InputData",
		FormParameters,
		ThisObject,
		,
		,
		,
		New NotifyDescription("OnClosingInputDataDialog", ThisObject),
		FormWindowOpeningMode.LockOwnerWindow);
		
EndProcedure

&AtClient
Procedure DeleteRecords(Command)
	
	Notification = New NotifyDescription("DeleteRecordsEnd", ThisObject);
	Mode		 = QuestionDialogMode.YesNo;
	QueryMessage = NStr("en = 'Do you want to delete this record?'; ru = 'Удалить запись?';pl = 'Czy chcesz usunąć ten wpis?';es_ES = '¿Quiere borrar este registro?';es_CO = '¿Quiere borrar este registro?';tr = 'Bu kaydı silmek istiyor musunuz?';it = 'Eliminare questa registrazione?';de = 'Möchten Sie diesen Eintrag löschen?'");
	
	ShowQueryBox(Notification, QueryMessage, Mode, 0);
	
EndProcedure

&AtClient
Procedure DeleteRecordsEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		CurrentRow = Items.RecordList.CurrentData;
		
		ClearMessages();
		
		If CheckEffectivePeriodAtServer(CurrentRow.Company, CurrentRow.TypeOfAccounting, CurrentRow.Period) Then
			Return;
		EndIf;
		
		DeleteRecordsAtServer(CurrentRow.Company, CurrentRow.TypeOfAccounting, CurrentRow.Period);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CheckDocumentsAfterSetDate(Result, Messages, ChosenDocumentTypes, Company, TypeOfAccounting, Period)
	
	Query = New Query;
	QueryText = "";
	
	FirstText = True;
	For Each DocumentTypeItem In ChosenDocumentTypes Do
		
		DocumentTypeMeta = Common.MetadataObjectByID(DocumentTypeItem);
		If TypeOf(DocumentTypeMeta) <> Type("MetadataObject") 
			Or DocumentTypeMeta.Attributes.Find("Company") = Undefined Then
			
			Continue;
			
		Else
			
			QueryTemplate =
			"SELECT TOP 1
			|	DocumentData.Date AS Date,
			|	&DocumentTypeItemSynonym AS DocumentType
			|FROM
			|	&DocumentTable AS DocumentData
			|WHERE
			|	DocumentData.Posted
			|	AND DocumentData.Date >= &Date
			|	AND DocumentData.Company = &Company";
			
			DocSynonym		= StrTemplate("""%1""", DocumentTypeItem.Synonym);
			DocTableName	= StrTemplate("Document.%1", DocumentTypeMeta.Name);
			
			QueryTemplate = StrReplace(QueryTemplate, "&DocumentTypeItemSynonym", DocSynonym);
			QueryTemplate = StrReplace(QueryTemplate, "&DocumentTable", DocTableName);
			
			If FirstText Then
				QueryText = QueryTemplate;
				FirstText = False;
			Else
				QueryText = QueryText + DriveClientServer.GetQueryUnion() + QueryTemplate;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Query.Text = QueryText;
	Query.SetParameter("Company", Company);
	Query.SetParameter("Date"	, Period);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Result = False;
		Template = NStr("en = 'Cannot delete the item from the list. Documents were already posted for ""%1"" and ""%2"".'; ru = 'Не удалось удалить элемент из списка. Для ""%1"" и ""%2"" уже проведены документы.';pl = 'Nie można usunąć pozycji z listy. Dokumenty już zostały zatwierdzone dla ""%1"" i ""%2"".';es_ES = 'No se puede eliminar el artículo de la lista. Los documentos ya fueron contabilizados para ""%1"" y ""%2"".';es_CO = 'No se puede eliminar el artículo de la lista. Los documentos ya fueron contabilizados para ""%1"" y ""%2"".';tr = 'Öğe listeden silinemiyor. ""%1"" ve ""%2"" için kayıtlı belgeler var.';it = 'Impossibile eliminare l''elemento dall''elenco. I documenti sono già stati pubblicati per ""%1"" e ""%2"".';de = 'Fehler beim Löschen des Elements aus der Liste. Dokumente wurden bereits für ""%1"" und ""%2"" gebucht.'");
		Message = StrTemplate(Template, Company, TypeOfAccounting);
		
		Messages.Add(Message);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteRecordsAtServer(Company, TypeOfAccounting, Period)
	
	Result = True;
	Messages = New Array;
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountingSourceDocuments.DocumentType AS DocumentType
	|FROM
	|	InformationRegister.AccountingSourceDocuments AS AccountingSourceDocuments
	|WHERE
	|	AccountingSourceDocuments.Period = &Period
	|	AND AccountingSourceDocuments.Company = &Company
	|	AND AccountingSourceDocuments.TypeOfAccounting = &TypeOfAccounting
	|	AND AccountingSourceDocuments.Uses";

	Query.SetParameter("Company", Company);
	Query.SetParameter("Period", Period);
	Query.SetParameter("TypeOfAccounting", TypeOfAccounting);
	
	QueryResult = Query.Execute();
	
	ChosenDocumentTypes = QueryResult.Unload().UnloadColumn("DocumentType");
	
	If ChosenDocumentTypes.Count() > 0 Then
		CheckDocumentsAfterSetDate(Result, Messages, ChosenDocumentTypes, Company, TypeOfAccounting, Period);
	EndIf;
	
	If Result Then
		
		AccountingSourceDocumentsTable = InformationRegisters.AccountingSourceDocuments.CreateRecordSet();
		
		AccountingSourceDocumentsTable.Filter.Company.Set(Company);
		AccountingSourceDocumentsTable.Filter.Period.Set(Period);
		AccountingSourceDocumentsTable.Filter.TypeOfAccounting.Set(TypeOfAccounting);
		
		AccountingSourceDocumentsTable.Read();
		AccountingSourceDocumentsTable.Clear();
		AccountingSourceDocumentsTable.Write();
		
		Items.RecordList.Refresh();
		
	Else 
		
		For Each Message In Messages Do
			DriveServer.ShowMessageAboutError(, Message);
		EndDo;
		
	EndIf;
	
EndProcedure

&AtServer
Function CheckEffectivePeriodAtServer(Company, TypeOfAccounting, Period)
	Var EndPeriod;
	
	Cancel = False;
	
	Query = New Query;
	Query.Text = "
	|SELECT ALLOWED DISTINCT TOP 2
	|	AccountingSourceDocuments.Period AS Period
	|FROM
	|	InformationRegister.AccountingSourceDocuments AS AccountingSourceDocuments
	|WHERE
	|	AccountingSourceDocuments.Company = &Company
	|	AND AccountingSourceDocuments.TypeOfAccounting = &TypeOfAccounting
	|	AND AccountingSourceDocuments.Period >= &BeginPeriod
	|
	|ORDER BY
	|	Period";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("TypeOfAccounting", TypeOfAccounting);
	Query.SetParameter("BeginPeriod", Period);
	
	Periods = Query.Execute().Unload();
	
	If Periods.Count() > 1 Then
		
		EndPeriod = BegOfDay(Periods[1].Period);
		
	EndIf;
	
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	AccountingJournalEntriesCompound.Account AS Account
	|INTO MasterEntries
	|FROM
	|	AccountingRegister.AccountingJournalEntriesCompound AS AccountingJournalEntriesCompound
	|WHERE
	|	AccountingJournalEntriesCompound.Company = &Company
	|	AND AccountingJournalEntriesCompound.TypeOfAccounting = &TypeOfAccounting
	|	AND AccountingJournalEntriesCompound.Active
	|	AND &PeriodConditionCompound
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	AccountingJournalEntriesSimple.AccountDr
	|FROM
	|	AccountingRegister.AccountingJournalEntriesSimple AS AccountingJournalEntriesSimple
	|WHERE
	|	AccountingJournalEntriesSimple.Company = &Company
	|	AND AccountingJournalEntriesSimple.TypeOfAccounting = &TypeOfAccounting
	|	AND AccountingJournalEntriesSimple.Active
	|	AND &PeriodConditionSimple
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	AccountingJournalEntriesSimple.AccountCr
	|FROM
	|	AccountingRegister.AccountingJournalEntriesSimple AS AccountingJournalEntriesSimple
	|WHERE
	|	AccountingJournalEntriesSimple.Company = &Company
	|	AND AccountingJournalEntriesSimple.TypeOfAccounting = &TypeOfAccounting
	|	AND AccountingJournalEntriesSimple.Active
	|	AND &PeriodConditionSimple
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	MasterChartOfAccounts.ChartOfAccounts AS ChartOfAccounts
	|FROM
	|	MasterEntries AS MasterEntries
	|		LEFT JOIN ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
	|		ON MasterEntries.Account = MasterChartOfAccounts.Ref
	|
	|GROUP BY
	|	MasterChartOfAccounts.ChartOfAccounts";
	
	Query.Text = ?(EndPeriod = Undefined,
		StrReplace(Query.Text, "&PeriodConditionCompound", "AccountingJournalEntriesCompound.Period >= &BeginPeriod"),
		StrReplace(Query.Text, "&PeriodConditionCompound", "AccountingJournalEntriesCompound.Period BETWEEN &BeginPeriod AND &EndPeriod")); 
	
	Query.Text = ?(EndPeriod = Undefined,
		StrReplace(Query.Text, "&PeriodConditionSimple", "AccountingJournalEntriesSimple.Period >= &BeginPeriod"),
		StrReplace(Query.Text, "&PeriodConditionSimple", "AccountingJournalEntriesSimple.Period BETWEEN &BeginPeriod AND &EndPeriod")); 
	
	If Not EndPeriod = Undefined Then
		Query.SetParameter("EndPeriod", EndPeriod);
	EndIf;
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			ErrorMessage = NStr("en = 'Cannot delete the item from the list. Documents were already posted for ""%1"" and ""%2"".'; ru = 'Не удалось удалить элемент из списка. Для ""%1"" и ""%2"" уже проведены документы.';pl = 'Nie można usunąć pozycji z listy. Dokumenty już zostały zatwierdzone dla ""%1"" i ""%2"".';es_ES = 'No se puede eliminar el artículo de la lista. Los documentos ya fueron contabilizados para ""%1"" y ""%2"".';es_CO = 'No se puede eliminar el artículo de la lista. Los documentos ya fueron contabilizados para ""%1"" y ""%2"".';tr = 'Öğe listeden silinemiyor. ""%1"" ve ""%2"" için kayıtlı belgeler var.';it = 'Impossibile eliminare l''elemento dall''elenco. I documenti sono già stati pubblicati per ""%1"" e ""%2"".';de = 'Fehler beim Löschen des Elements aus der Liste. Dokumente wurden bereits für ""%1"" und ""%2"" gebucht.'");
			ErrorMessage = StrTemplate(ErrorMessage, Company, TypeOfAccounting);
			DriveServer.ShowMessageAboutError(Undefined, ErrorMessage, , , , Cancel);
			
		EndDo;
		
	EndIf;
	
	Return Cancel;
	
EndFunction

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "NewElementCreated" Then
		Items.RecordList.Refresh();
		Items.RecordList.CurrentRow = New DynamicListRowKey(Parameter);
	EndIf;
	
EndProcedure

#EndRegion