#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If NOT ValueIsFilled(Parameters.TransformationTemplate) Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The data processor ""%1"" should only be used from the transformation template'; ru = 'Обработку ""%1"" следует использовать только из шаблона преобразования';pl = 'Procesor danych ""%1"" powinien być używany tylko dla szablonu transformacji';es_ES = 'El procesador de datos ""%1"" sólo debe ser utilizado desde la plantilla de transformación';es_CO = 'El procesador de datos ""%1"" sólo debe ser utilizado desde la plantilla de transformación';tr = 'Veri işlemcisi ""%1"" yalnızca dönüştürme şablonundan kullanılmalıdır';it = 'L''elaboratore dati ""%1"" dovrebbe essere usato dal template di trasformazione';de = 'Der Datenverarbeiter ""%1"" sollte nur aus der Transformationsvorlage verwendet werden'"),
			Metadata.DataProcessors.MappingSettings.Synonym);
		
		CommonClientServer.MessageToUser(MessageText, , , , Cancel);
		
		Return;
		
	EndIf;
	
	TransformationTemplate = Parameters.TransformationTemplate;
	TransformationSettings = DataProcessors.MappingSettings.TranslationTemplateSettings(TransformationTemplate);
	
	MappingID = TransformationSettings.MappingID;
	
	SourceChartOfAccounts	= TransformationSettings.SourceChartOfAccounts;
	ReceiverChartOfAccounts	= TransformationSettings.ReceivingChartOfAccounts;
	
	DescriptionSourceChartOfAccounts	= TransformationSettings.DescriptionSourceChartOfAccounts;
	DescriptionReceiverChartOfAccounts	= TransformationSettings.DescriptionReceivingChartOfAccounts;
	
	NameSourceChartOfAccounts	= TransformationSettings.NameSourceChartOfAccounts;
	NameReceiverChartOfAccounts	= TransformationSettings.NameReceiverChartOfAccounts;
	
	Items.MappingSettings.ChoiceList.Add(DescriptionSourceChartOfAccounts);
	Items.MappingSettings.ChoiceList.Add(DescriptionReceiverChartOfAccounts);
	
	MappingSettings = DescriptionSourceChartOfAccounts;
	
	SetSourceChartOfAccountsTitle(DescriptionSourceChartOfAccounts);
	
	FillSourceAccountsTable();
	FillReceiverAccountsTable();
	
	SetColumsTypes();
	
	Items.ButtonSourceAccountsTableMapped.Check = False;
	Items.ButtonSourceAccountsTableUnmapped.Check = False;
	Items.ButtonReceiverMapped.Check = False;
	Items.ButtonReceiverUnmapped.Check = False;
	Items.ButtonSourceAccountsTableFilterByColumn.Check = False;
	Items.ButtonReceiverFilterByColumn.Check = False;
	
	Items.ReceiverAccountsTableSourceAccountInv.Visible		= InvertTables;
	Items.ReceiverAccountsTableReceivingAccountInv.Visible	= InvertTables;
	
	Items.ReceiverAccountsTableSourceAccount.Visible	= Not InvertTables;
	Items.ReceiverAccountsTableReceivingAccount.Visible	= Not InvertTables;
	
	SetConditionalAppearance();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Exit And Modified Then
		Cancel = True;
		Return;
	EndIf;
	
	If Modified Then
		
		Cancel = True;
		StandardProcessing = False;
		
		Notify = New NotifyDescription("BeforeCloseEnd", ThisObject);
		ShowQueryBox(
			Notify,
			NStr("en = 'Data was changed. Do you want to save?'; ru = 'Данные были изменены. Сохранить изменения?';pl = 'Dane zostały zmienione. Czy chcesz zapisać?';es_ES = 'Datos se han cambiado. ¿Quieres guardarlos?';es_CO = 'Datos se han cambiado. ¿Quieres guardarlos?';tr = 'Veriler değiştirildi. Kaydetmek istiyor musunuz?';it = 'I dati sono cambiati. Volete salvarli?';de = 'Die Daten wurden geändert. Möchten Sie Änderungen speichern?'"),
			QuestionDialogMode.YesNo,
			30,
			DialogReturnCode.Yes);
			
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		SaveMapping();
	EndIf;
	
	Modified = False;
	Close();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure MappingSettingsOnChange(Item)
	FormRefresh();
EndProcedure

#EndRegion

#Region ReceiverAccountsTableFormTableItemsEventHandlers

&AtClient
Procedure ReceiverAccountsTableSourceAccountInvOnChange(Item)
	
	CurrentData = Items.ReceiverAccountsTable.CurrentData;
	
	CurrentData.Ref = MappingRule(
		TransformationTemplate,
		CurrentData.SourceAccount,
		CurrentData.CorrSourceAccount,
		CurrentData.ReceivingAccount,
		CurrentData.MappingID);
	
EndProcedure

&AtClient
Procedure ReceiverAccountsTableSourceAccountOnChange(Item)
	
	CurrentData = Items.ReceiverAccountsTable.CurrentData;
	If ValueIsFilled(CurrentData.SourceAccount) Then
		
		Filter = New Structure("SourceAccount", CurrentData.SourceAccount);
		AccountRow = SourceAccountsTable.FindRows(Filter);
		
		CurrentData.UseDr = True;
		CurrentData.UseCr = True;
		
	EndIf;
	
	CurrentData.Ref = MappingRule(
		TransformationTemplate,
		CurrentData.SourceAccount,
		CurrentData.CorrSourceAccount,
		CurrentData.ReceivingAccount,
		CurrentData.MappingID);
	
EndProcedure

#EndRegion

#Region SourceAccountsTableFormTableItemsEventHandlers

&AtClient
Procedure SourceAccountsTableDragStart(Item, DragParameters, Perform)
	
	MovingItems = ArrayOfAccounts(DragParameters.Value);
	If MovingItems.Count() > 0 Then
		DragParameters.Value = MovingItems;
	Else
		Perform = False;
	EndIf;
		
EndProcedure

&AtClient

#EndRegion

#Region ReceivingAccountsTableFormTableItemsEventHandlers

&AtClient
Procedure ReceiverAccountsTableReceivingAccountOnChange(Item)
	
	CurrentData = Items.ReceiverAccountsTable.CurrentData;
	
	CurrentData.Ref = MappingRule(
		TransformationTemplate,
		CurrentData.SourceAccount,
		CurrentData.CorrSourceAccount,
		CurrentData.ReceivingAccount,
		CurrentData.MappingID);
	
EndProcedure

&AtClient
Procedure ReceiverAccountsTableDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	
	If Row = Undefined Then
		Return;
	EndIf;
	
	CurrentReceiver = ReceiverAccountsTable.FindByID(Row);
	If CurrentReceiver = Undefined Then
		Return;
	EndIf;
	
	For Each AccountsRow In DragParameters.Value Do
		AddMatchedAccount(CurrentReceiver, AccountsRow);
	EndDo;
	
EndProcedure

&AtClient
Procedure ReceiverAccountsTableDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	If Row = Undefined Then
		Return;
	EndIf;
	
	CurrentReceiver = ReceiverAccountsTable.FindByID(Row);
	If CurrentReceiver = Undefined Then
		DragParameters.AllowedActions = DragAllowedActions.DontProcess
	Else
		StandardProcessing = False;
		DragParameters.AllowedActions = DragAllowedActions.Move;
		DragParameters.Action = DragAction.Move;
	EndIf;
	
EndProcedure

&AtClient
Procedure ReceiverAccountsTableOnEditEnd(Item, NewRow, CancelEdit)
	
	If Not CancelEdit Then
		
		CurrentData = Items.ReceiverAccountsTable.CurrentData;
		If ValueIsFilled(CurrentData.SourceAccount)
			And ValueIsFilled(CurrentData.ReceivingAccount) Then
			
			CurrentData.Mapped = True;
			CurrentData.SetingsSaved = False;
			
			If InvertTables Then
				Filter = New Structure("SourceAccount", CurrentData["ReceivingAccount"]);
			Else
				Filter = New Structure("SourceAccount", CurrentData["SourceAccount"]);
			EndIf;
			
			SourceArray = SourceAccountsTable.FindRows(Filter);
			If SourceArray.Count() > 0 Then
				SourceArray[0].Mapped = True;
			EndIf;
			
		EndIf;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ReceiverAccountsTableBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.ReceiverAccountsTable.CurrentData;
	
	If InvertTables Then
		Filter = New Structure("SourceAccount", CurrentData.SourceAccount);
	Else
		Filter = New Structure("ReceivingAccount", CurrentData.ReceivingAccount);
	EndIf;
	
	RowsArray = ReceiverAccountsTable.FindRows(Filter);
	If RowsArray.Count() = 1 Then
		
		Cancel = True;
		
		CurrentData.UseDr  = False;
		CurrentData.UseCr  = False;
		CurrentData.Mapped = False;
		CurrentData.Ref     = "";
		CurrentData.CorrSourceAccount = "";
		
	EndIf;
	
	DeleteMapping(CurrentData.SourceAccount, CurrentData.ReceivingAccount);
	
EndProcedure

&AtClient
Procedure ReceiverAccountsTableBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	Cancel = True;
	
	CurrentData = Items.ReceiverAccountsTable.CurrentData;
	If CurrentData <> Undefined Then
		
		RowIndex = ReceiverAccountsTable.IndexOf(CurrentData);
		NewRow = ReceiverAccountsTable.Insert(RowIndex + 1);
		
		ExcludeProperties = "UseCr, UseDr, CorrSourceAccount, Ref, Mapped, MappingID, "
			+ ?(InvertTables, "ReceivingAccount", "SourceAccount, SourceAccountDescription, SourceAccountCode");
		
		FillPropertyValues(NewRow, CurrentData,	, ExcludeProperties);
		NewRow.MappingID = MappingID();
		
	EndIf;
	
EndProcedure

&AtClient

&AtClient
Procedure ReceiverAccountsTableCorrSourceAccountOnChange(Item)
	
	CurrentData = Items.ReceiverAccountsTable.CurrentData;
	CurrentData.Ref = MappingRule(
		TransformationTemplate,
		CurrentData.SourceAccount,
		CurrentData.CorrSourceAccount,
		CurrentData.ReceivingAccount,
		CurrentData.MappingID);
		
EndProcedure

&AtClient
Procedure ReceiverAccountsTableReceivingAccountInvOnChange(Item)
	
	CurrentData = Items.ReceiverAccountsTable.CurrentData;
	If ValueIsFilled(CurrentData.SourceAccount) Then
		CurrentData.UseDr = True;
		CurrentData.UseCr = True;
	EndIf;
	
	CurrentData.Ref = MappingRule(
		TransformationTemplate,
		CurrentData.SourceAccount,
		CurrentData.CorrSourceAccount,
		CurrentData.ReceivingAccount,
		CurrentData.MappingID);
		
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ReceiverMapped(Command)
	
	Items.ButtonReceiverMapped.Check = Not Items.ButtonReceiverMapped.Check;
	
	If Items.ButtonReceiverUnmapped.Check Then
		Items.ButtonReceiverUnmapped.Check = False;
	EndIf;
	
	SetRowFilterForReceiver();
	
EndProcedure

&AtClient
Procedure ReceiverUnmapped(Command)
	
	Items.ButtonReceiverUnmapped.Check = Not Items.ButtonReceiverUnmapped.Check;
	
	If Items.ButtonReceiverMapped.Check Then
		Items.ButtonReceiverMapped.Check = False;
	EndIf;
	
	SetRowFilterForReceiver();
	
EndProcedure

&AtClient
Procedure ReceiverFilterByCurrentColumn(Command)
	
	Items.ButtonReceiverFilterByColumn.Check = Not Items.ButtonReceiverFilterByColumn.Check;
	
	SetRowFilterForReceiver();
	
EndProcedure

&AtClient
Procedure MatchAccounts(Command)
	
	CurrentReceiver = Items.ReceiverAccountsTable.CurrentData;
	If CurrentReceiver = Undefined Then
		CommonClientServer.MessageToUser(NStr("en = 'The receiving table is empty.'; ru = 'Таблица-получатель пуста.';pl = 'Otrzymana tabela jest pusta.';es_ES = 'La tabla de recepción está vacía.';es_CO = 'La tabla de recepción está vacía.';tr = 'Alıcı tablo boş.';it = 'La tabella di ricezione è vuota.';de = 'Die Eingangstabelle ist leer.'"));
		Return;
	EndIf;
	
	ArrayOfAccounts = ArrayOfAccounts(Items.SourceAccountsTable.SelectedRows);
	For Each Account In ArrayOfAccounts Do
		AddMatchedAccount(CurrentReceiver, Account);
	EndDo;
	
EndProcedure

&AtClient
Procedure ClearMappingInSourceTable(Command)
	
	If Items.SourceAccountsTable.SelectedRows <> Undefined Then
		
		For Each RowID In Items.SourceAccountsTable.SelectedRows Do
			
			Row = SourceAccountsTable.FindByID(RowID);
			
			ClearMappingInSourceTableInRow(Row);
			
			RowIndex = SourceAccountsTable.IndexOf(Row);
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearMapping(Command)
	
	If Items.ReceiverAccountsTable.SelectedRows <> Undefined Then
		
		For Each RowID In Items.ReceiverAccountsTable.SelectedRows Do
			
			Row = ReceiverAccountsTable.FindByID(RowID);
			
			ClearMappingInRow(Row);
			
			RowIndex = ReceiverAccountsTable.IndexOf(Row);
			
			FieldName = ?(InvertTables, "SourceAccount", "ReceivingAccount");
			If RowIndex > 0 And ReceiverAccountsTable[RowIndex - 1][FieldName] = Row[FieldName] Then
				ReceiverAccountsTable.Delete(Row);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveChanges(Command)
	
	SaveMapping();
	
	Modified = False;
	
EndProcedure

&AtClient
Procedure SaveAndClose(Command)
	
	SaveMapping();
	Modified = False;
	Close();
	
EndProcedure

&AtClient
Procedure SourceMapped(Command)
	
	Items.ButtonSourceAccountsTableMapped.Check = Not Items.ButtonSourceAccountsTableMapped.Check;
	
	If Items.ButtonSourceAccountsTableUnmapped.Check Then
		Items.ButtonSourceAccountsTableUnmapped.Check = False;
	EndIf;
	
	If Items.ButtonSourceAccountsTableMapped.Check Then
		Filter = New FixedStructure("Mapped", True);
	Else
		Filter = Undefined;
	EndIf;
	SetRowFilterForSource(Filter);
	
EndProcedure

&AtClient
Procedure SourceUnmapped(Command)
	
	Items.ButtonSourceAccountsTableUnmapped.Check = Not Items.ButtonSourceAccountsTableUnmapped.Check;
	
	If Items.ButtonSourceAccountsTableMapped.Check Then
		Items.ButtonSourceAccountsTableMapped.Check = False;
	EndIf;
	
	If Items.ButtonSourceAccountsTableUnmapped.Check Then
		Filter = New FixedStructure("Mapped", False);
	Else
		Filter = Undefined;
	EndIf;
	SetRowFilterForSource(Filter);
	
EndProcedure

&AtClient
Procedure SourceFilterByCurrentColumn(Command)
	
	Items.ButtonSourceAccountsTableFilterByColumn.Check = Not Items.ButtonSourceAccountsTableFilterByColumn.Check;
	
	Filter = RowFilterForSource();
	SetRowFilterForSource(Filter);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillSourceAccountsTable()
	
	Query = New Query("
	|SELECT
	|	Mapping.SourceAccount AS SourceAccount,
	|	COUNT(DISTINCT Mapping.ReceivingAccount) AS ReceivingAccount
	|INTO Mapping
	|FROM
	|	Catalog.Mapping AS Mapping
	|WHERE
	|	Mapping.Owner = &TranslationTemplate
	|
	|GROUP BY
	|	Mapping.SourceAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Table.Ref AS SourceAccount,
	|	Table.Code AS Code,
	|	Table.Description AS Description,
	|	Table.Currency AS Currency,
	|	CASE
	|		WHEN &MappingField IS NULL
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Mapped,
	|	&IsHeaderField AS IsHeader
	|FROM
	|	&ChartOfAccounts AS Table
	|		LEFT JOIN Mapping AS Mapping
	|		ON (Table.Ref = &ConnectionField)
	|ORDER BY
	|	Table.Code HIERARCHY
	|");
	
	If InvertTables Then
		
		Query.Text = StrReplace(Query.Text, "&MappingField", "Mapping.SourceAccount");
		Query.Text = StrReplace(Query.Text, "&ConnectionField", "Mapping.ReceivingAccount");
		
		NameChartOfAccounts = NameReceiverChartOfAccounts;
		
	Else
		
		Query.Text = StrReplace(Query.Text, "&MappingField", "Mapping.ReceivingAccount");
		Query.Text = StrReplace(Query.Text, "&ConnectionField", "Mapping.SourceAccount");
		
		NameChartOfAccounts = NameSourceChartOfAccounts;
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&ChartOfAccounts", "ChartOfAccounts." + NameChartOfAccounts);
	
	HasTypeOfAccount = Common.HasObjectAttribute("TypeOfAccount", Metadata.ChartsOfAccounts[NameChartOfAccounts]);
	If HasTypeOfAccount Then
		IsHeaderField = "CASE WHEN Table.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Header) THEN TRUE ELSE FALSE END";
	Else
		IsHeaderField = "FALSE";
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&IsHeaderField", IsHeaderField);
	
	Query.SetParameter("TranslationTemplate", TransformationTemplate);
	
	ValueToFormAttribute(Query.Execute().Unload(), "SourceAccountsTable");
	
EndProcedure

&AtServer
Procedure FillReceiverAccountsTable()
	
	Query = New Query("
	|SELECT
	|	Mapping.Ref AS Ref,
	|	Mapping.ReceivingAccount AS ReceivingAccount,
	|	ReceivingChartOfAccounts.Code AS ReceivingAccountCode,
	|	Mapping.CorrSourceAccount AS CorrSourceAccount,
	|	Mapping.MappingID AS MappingID,
	|	Settings.UseDr AS UseDr,
	|	Settings.UseCr AS UseCr,
	|	Mapping.SourceAccount AS SourceAccount,
	|	SourceChartOfAccounts.Code AS SourceAccountCode
	|INTO Mapping
	|FROM
	|	Catalog.Mapping AS Mapping
	|		LEFT JOIN #ReceivingChartOfAccounts AS ReceivingChartOfAccounts
	|		ON (ReceivingChartOfAccounts.Ref = Mapping.ReceivingAccount)
	|		LEFT JOIN #SourceChartOfAccounts AS SourceChartOfAccounts
	|		ON (SourceChartOfAccounts.Ref = Mapping.SourceAccount)
	|		INNER JOIN InformationRegister.MappingRules AS Settings
	|		ON Mapping.Ref = Settings.AccountsMapping
	|			AND (Settings.TranslationTemplate = &TranslationTemplate)
	|WHERE
	|	Mapping.Owner = &TranslationTemplate
	|;
	|////////////////////////////////////////////////
	|");
	
	Query.Text = StrReplace(Query.Text, "#SourceChartOfAccounts", "ChartOfAccounts." + NameSourceChartOfAccounts);
	Query.Text = StrReplace(Query.Text, "#ReceivingChartOfAccounts", "ChartOfAccounts." + NameReceiverChartOfAccounts);
	
	Query.SetParameter("TranslationTemplate", TransformationTemplate);
	
	If InvertTables Then
		
		Query.Text = Query.Text + "
		|SELECT
		|	Table.Ref AS SourceAccount,
		|	Table.Description AS BasicAccountDescription,
		|	Table.Code AS SourceAccountCode,
		|	Table.Currency AS Currency,
		|	CASE
		|		WHEN Mapping.ReceivingAccount IS NULL
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS Mapped,
		|	ISNULL(Mapping.UseDr, FALSE) AS UseDr,
		|	ISNULL(Mapping.UseCr, FALSE) AS UseCr,
		|	ISNULL(Mapping.ReceivingAccount, &EmptyRef) AS ReceivingAccount,
		|	ISNULL(Mapping.CorrSourceAccount, &EmptyRef) AS CorrSourceAccount,
		|	ISNULL(Mapping.MappingID, 0) AS MappingID,
		|	ISNULL(Mapping.Ref, VALUE(Catalog.Mapping.EmptyRef)) AS Ref,
		|	TRUE AS SetingsSaved,
		|	ISNULL(Mapping.ReceivingAccountCode, """""""") AS ReceivingAccountCode
		|FROM
		|	&ChartOfAccounts AS Table
		|		LEFT JOIN Mapping AS Mapping
		|		ON Table.Ref = Mapping.SourceAccount
		|
		|ORDER BY
		|	Table.Code HIERARCHY,
		|	ReceivingAccountCode,
		|	MappingID
		|";
		
		Query.Text = StrReplace(Query.Text, "&ChartOfAccounts", "ChartOfAccounts." + NameSourceChartOfAccounts);
		Query.Text = StrReplace(Query.Text, "&EmptyRef", "VALUE(ChartOfAccounts." + NameSourceChartOfAccounts + ".EmptyRef)");
		
		FieldName = "SourceAccount";
		
	Else
		
		Query.Text = Query.Text + "
		|SELECT
		|	Table.Ref AS ReceivingAccount,
		|	Table.Description AS BasicAccountDescription,
		|	Table.Code AS ReceivingAccountCode,
		|	Table.Currency AS Currency,
		|	CASE
		|		WHEN Mapping.SourceAccount IS NULL
		|			THEN FALSE
		|		ELSE TRUE
		|	END AS Mapped,
		|	ISNULL(Mapping.UseDr, FALSE) AS UseDr,
		|	ISNULL(Mapping.UseCr, FALSE) AS UseCr,
		|	ISNULL(Mapping.SourceAccount, &EmptyRef) AS SourceAccount,
		|	ISNULL(Mapping.CorrSourceAccount, &EmptyRef) AS CorrSourceAccount,
		|	ISNULL(Mapping.MappingID, 0) AS MappingID,
		|	ISNULL(Mapping.Ref, VALUE(Catalog.Mapping.EmptyRef)) AS Ref,
		|	TRUE AS SetingsSaved,
		|	ISNULL(Mapping.SourceAccountCode, """""""") AS SourceAccountCode
		|FROM
		|	&ChartOfAccounts AS Table
		|		LEFT JOIN Mapping AS Mapping
		|		ON Table.Ref = Mapping.ReceivingAccount
		|
		|ORDER BY
		|	Table.Code HIERARCHY,
		|	SourceAccountCode,
		|	MappingID";
		
		Query.Text = StrReplace(Query.Text, "&ChartOfAccounts", "ChartOfAccounts." + NameReceiverChartOfAccounts);
		Query.Text = StrReplace(Query.Text, "&EmptyRef", "VALUE(ChartOfAccounts." + NameReceiverChartOfAccounts + ".EmptyRef)");
		
		FieldName = "ReceivingAccount";
		
	EndIf;
	
	ReceiverAccountsTable.Clear();
	
	CurrentAccount = "";
	
	Result = Query.Execute().Unload();
	For Each AccountRow In Result Do
		
		NewRow = ReceiverAccountsTable.Add();
		FillPropertyValues(NewRow, AccountRow);
		
		If CurrentAccount = AccountRow[FieldName] Then
			NewRow.BasicAccountDescription = "";
		Else
			CurrentAccount = AccountRow[FieldName];
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function MappingRule(TransformationTemplate, SourceAccount, CorrSourceAccount, ReceivingAccount, MappingID)
	
	Return Catalogs.Mapping.RollbackMapping(
		TransformationTemplate,
		SourceAccount,
		CorrSourceAccount,
		ReceivingAccount,
		MappingID);
		
EndFunction

&AtClient
Procedure SetRowFilterForReceiver(RowFilter = Undefined)
	
	If RowFilter = Undefined Then
		RowFilter = RowFilterForReceiver();
	EndIf;
	
	Items.ReceiverAccountsTable.RowFilter = RowFilter;
	
EndProcedure

&AtClient
Procedure SetRowFilterForSource(RowFilter)
	Items.SourceAccountsTable.RowFilter = RowFilter;
EndProcedure

&AtClient
Function RowFilterForReceiver()
	
	Filter = New Structure;
	
	If Items.ButtonReceiverMapped.Check Then
		Filter.Insert("Mapped", True);
	EndIf;
	
	If Items.ButtonReceiverUnmapped.Check Then
		Filter.Insert("Mapped", False);
	EndIf;
	
	If Items.ButtonReceiverFilterByColumn.Check
		And Items.ReceiverAccountsTable.CurrentData <> Undefined Then
		
		ColumnName = StrReplace(Items.ReceiverAccountsTable.CurrentItem.Name, "ReceiverAccountsTable", "");
		ColumnName = StrReplace(ColumnName, "Inv", "");
		
		Filter.Insert(ColumnName, Items.ReceiverAccountsTable.CurrentData[ColumnName]);
	EndIf;
	
	If Filter.Count() > 0 Then
		RowFilterForReceiver = New FixedStructure(Filter);
	Else
		RowFilterForReceiver = Undefined;
	EndIf;
	
	Return RowFilterForReceiver;
	
EndFunction

&AtClient
Function ArrayOfAccounts(RowsArray)
	
	ArrayOfAccounts = New Array;
	SourceArrayOfAccounts = New Array;
	
	For Each Row In RowsArray Do
		
		FoundedRow = SourceAccountsTable.FindByID(Row);
		If FoundedRow = Undefined Then
			Continue;
		EndIf;
		
		If SourceArrayOfAccounts.Find(FoundedRow.SourceAccount) = Undefined Then
			ArrayOfAccounts.Add(FoundedRow);
			SourceArrayOfAccounts.Add(FoundedRow.SourceAccount);
		EndIf;
		
	EndDo;
	
	Return ArrayOfAccounts;
	
EndFunction

&AtClient
Procedure AddMatchedAccount(Receiver, Source)
	
	Settings = New Structure;
	Settings.Insert("UseDr", True);
	Settings.Insert("UseCr", True);
	
	If InvertTables Then
		
		Settings.Insert("SourceAccount", Receiver["SourceAccount"]);
		Settings.Insert("ReceivingAccount", Source.SourceAccount);
		
		Account = Receiver["ReceivingAccount"];
		
	Else
		
		Settings.Insert("SourceAccount", Source.SourceAccount);
		Settings.Insert("ReceivingAccount", Receiver["ReceivingAccount"]);
		
		Account = Receiver["SourceAccount"];
		
	EndIf;
	
	If Not ValueIsFilled(Account) Then
		
		FillPropertyValues(Receiver, Settings);
		
		Source.Mapped = True;
		Receiver.Mapped = True;
		
		Receiver.MappingID = MappingID();
		
	Else
		
		ExistRows = ReceiverAccountsTable.FindRows(Settings);
		If ExistRows.Count() > 0 Then
			Return;
		EndIf;
		
		SourceRow = ReceiverAccountsTable.Insert(ReceiverAccountsTable.IndexOf(Receiver) + 1);
		FillPropertyValues(SourceRow, Settings);
		
		Source.Mapped = True;
		SourceRow.Mapped = True;
		
		Receiver.MappingID = MappingID();
		
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Function MappingID()
	
	CurrentID = CurrentID + 1;
	
	Return CurrentID;
	
EndFunction

&AtClient
Procedure ClearMappingInRow(Row)
	
	SourceAccount = Row.SourceAccount;
	
	If InvertTables Then
		Row.ReceivingAccount	= "";
	Else
		Row.CorrSourceAccount	= "";
		Row.SourceAccount		= "";
	EndIf;
	
	Row.UseDr				= "";
	Row.UseCr				= "";
	Row.DrSettings			= "";
	Row.Ref					= "";
	Row.Mapped				= False;
	
	Filter = New Structure("SourceAccount", SourceAccount);
	If ReceiverAccountsTable.FindRows(Filter).Count() = 0 Then
		
		Filter = New Structure("SourceAccount", SourceAccount);
		SourceRow = SourceAccountsTable.FindRows(Filter);
		If SourceRow.Count() > 0 Then 
			SourceRow[0].Mapped = False;
		EndIf;
	EndIf;
	
	Modified = True;
	
EndProcedure

&AtClient
Procedure ClearMappingInSourceTableInRow(Row)
	
	Filter = New Structure("SourceAccount", Row.SourceAccount);
	ReceiverAccountsRows = ReceiverAccountsTable.FindRows(Filter);
	
	For Each ReceiverAccountsRow In ReceiverAccountsRows Do
		
		ClearMappingInRow(ReceiverAccountsRow);
		
	EndDo;
	
	Row.Mapped = False;
	Modified = True;
	
EndProcedure

&AtServer
Procedure SaveMapping()
			
	If Not ValueIsFilled(TransformationTemplate) Then
		Return;
	EndIf;
	
	MappingTable = FormAttributeToValue("ReceiverAccountsTable");
	
	Query = New Query(
	"SELECT
	|	Mapping.Ref AS Ref,
	|	Mapping.SourceAccount AS SourceAccount,
	|	Mapping.ReceivingAccount AS ReceivingAccount,
	|	Mapping.CorrSourceAccount AS CorrSourceAccount,
	|	Mapping.MappingID AS MappingID,
	|	ISNULL(Settings.UseDr, FALSE) AS UseDr,
	|	ISNULL(Settings.UseCr, FALSE) AS UseCr,
	|	Mapping.DeletionMark AS DeletionMark
	|INTO ExistSettings
	|FROM
	|	Catalog.Mapping AS Mapping
	|		LEFT JOIN InformationRegister.MappingRules AS Settings
	|		ON Mapping.Ref = Settings.AccountsMapping
	|			AND (Settings.TranslationTemplate = &TransformationTemplate)
	|WHERE
	|	Mapping.Owner = &TransformationTemplate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MappingTable.SourceAccount AS SourceAccount,
	|	MappingTable.ReceivingAccount AS ReceivingAccount,
	|	MappingTable.UseDr AS UseDr,
	|	MappingTable.UseCr AS UseCr,
	|	MappingTable.CorrSourceAccount AS CorrSourceAccount,
	|	MappingTable.MappingID AS MappingID,
	|	MappingTable.Ref AS Ref
	|INTO NewSettings
	|FROM
	|	&MappingTable AS MappingTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NewSettings.SourceAccount AS NewSourceAccount,
	|	NewSettings.ReceivingAccount AS NewReceivingAccount,
	|	NewSettings.MappingID AS NewMappingID,
	|	NewSettings.UseDr AS NewUseDr,
	|	NewSettings.UseCr AS NewUseCr,
	|	NewSettings.CorrSourceAccount AS NewCorrSourceAccount,
	|	NewSettings.Ref AS NewRef,
	|	ISNULL(ExistSettings.Ref, VALUE(Catalog.Mapping.EmptyRef)) AS OldRef,
	|	ISNULL(ExistSettings.SourceAccount, &EmptyRef) AS OldSourceAccount,
	|	ISNULL(ExistSettings.ReceivingAccount, &EmptyRef) AS OldReceivingAccount,
	|	ISNULL(ExistSettings.MappingID, 0) AS OldMappingID,
	|	ISNULL(ExistSettings.UseDr, FALSE) AS OldUseDr,
	|	ISNULL(ExistSettings.UseCr, FALSE) AS OldUseCr,
	|	ISNULL(ExistSettings.CorrSourceAccount, &EmptyRef) AS OldCorrSourceAccount,
	|	ISNULL(ExistSettings.DeletionMark, False) AS OldDeletionMark
	|FROM
	|	NewSettings AS NewSettings
	|		LEFT JOIN ExistSettings AS ExistSettings
	|		ON NewSettings.SourceAccount = ExistSettings.SourceAccount
	|			AND NewSettings.CorrSourceAccount = ExistSettings.CorrSourceAccount
	|			AND NewSettings.ReceivingAccount = ExistSettings.ReceivingAccount
	|			AND NewSettings.MappingID = ExistSettings.MappingID
	|
	|UNION ALL
	|
	|SELECT
	|	&EmptyRef AS NewSourceAccount,
	|	&EmptyRef AS NewReceivingAccount,
	|	0 AS NewMappingID,
	|	FALSE AS NewUseDr,
	|	FALSE AS NewUseCr,
	|	&EmptyRef AS NewCorrSourceAccount,
	|	VALUE(Catalog.Mapping.EmptyRef) AS NewRef,
	|	ExistSettings.Ref AS OldRef,
	|	ExistSettings.SourceAccount AS OldSourceAccount,
	|	ExistSettings.ReceivingAccount AS OldReceivingAccount,
	|	ExistSettings.MappingID AS OldMappingID,
	|	ISNULL(ExistSettings.UseDr, FALSE) AS OldUseDr,
	|	ISNULL(ExistSettings.UseCr, FALSE) AS OldUseCr,
	|	ExistSettings.CorrSourceAccount AS OldCorrSourceAccount,
	|	ExistSettings.DeletionMark AS OldDeletionMark
	|FROM
	|	ExistSettings AS ExistSettings
	|		LEFT JOIN NewSettings AS NewSettings
	|		ON NewSettings.SourceAccount = ExistSettings.SourceAccount
	|			AND NewSettings.CorrSourceAccount = ExistSettings.CorrSourceAccount
	|			AND NewSettings.ReceivingAccount = ExistSettings.ReceivingAccount
	|			AND NewSettings.MappingID = ExistSettings.MappingID
	|WHERE
	|	NewSettings.Ref Is Null
	|");
	
	Query.Text = StrReplace(Query.Text, "&EmptyRef", "VALUE(ChartOfAccounts." + NameSourceChartOfAccounts + ".EmptyRef)");
	
	Query.TempTablesManager = New TempTablesManager;
	
	Query.SetParameter("TransformationTemplate", TransformationTemplate);
	Query.SetParameter("MappingTable", MappingTable);
	
	Selection = Query.Execute().Select();
	
	BeginTransaction();
	
	While Selection.Next() Do
		
		If Not ValueIsFilled(Selection.NewSourceAccount)
			And ValueIsFilled(Selection.OldRef) Then // Mapping was deleted
			
			FinancialAccounting.SaveMapSettings(TransformationTemplate, Selection.OldRef);
			
		ElsIf Not ValueIsFilled(Selection.OldRef)
			And ValueIsFilled(Selection.NewSourceAccount)
			And ValueIsFilled(Selection.NewReceivingAccount) Then // Add new mapping
			
			ChangeParameters = New Structure;
			ChangeParameters.Insert("Owner",				TransformationTemplate);
			ChangeParameters.Insert("SourceAccount",		Selection.NewSourceAccount);
			ChangeParameters.Insert("ReceivingAccount",		Selection.NewReceivingAccount);
			ChangeParameters.Insert("CorrSourceAccount",	Selection.NewCorrSourceAccount);
			ChangeParameters.Insert("MappingID",			Selection.NewMappingID);
			ChangeParameters.Insert("Ref");
			
			Catalogs.Mapping.ChangeObjectByParameters(ChangeParameters);
			
			If ValueIsFilled(ChangeParameters.Ref) Then
				
				ResourceStructure = New Structure;
				ResourceStructure.Insert("UseDr", Selection.NewUseDr);
				ResourceStructure.Insert("UseCr", Selection.NewUseCr);
				ResourceStructure.Insert("CorrSourceAccount", Selection.NewCorrSourceAccount);
				
				FinancialAccounting.SaveMapSettings(TransformationTemplate, ChangeParameters.Ref, ResourceStructure);
				
			EndIf;
			
		ElsIf ValueIsFilled(Selection.OldRef)
			And Selection.NewUseDr <> Selection.OldUseDr
			And Selection.NewUseCr <> Selection.OldUseCr
			And Selection.NewUseDr <> Selection.OldUseDr Then // Mapping was changed
					
			ResourceStructure = New Structure;
			ResourceStructure.Insert("UseDr", Selection.NewUseDr);
			ResourceStructure.Insert("UseCr", Selection.NewUseCr);
			ResourceStructure.Insert("CorrSourceAccount", Selection.NewCorrSourceAccount);
			
			FinancialAccounting.SaveMapSettings(TransformationTemplate, Selection.OldRef, ResourceStructure);
			
		EndIf;
		
	EndDo;
	
	CommitTransaction();
	
	FillReceiverAccountsTable();
	
EndProcedure

&AtClient
Function RowFilterForSource()
	
	Filter = New Structure;
	
	If Items.ButtonSourceAccountsTableMapped.Check Then
		Filter.Insert("Mapped", True);
	EndIf;
	
	If Items.ButtonSourceAccountsTableUnmapped.Check Then
		Filter.Insert("Mapped", False);
	EndIf;
	
	If Items.ButtonSourceAccountsTableFilterByColumn.Check
		And Items.SourceAccountsTable.CurrentData <> Undefined Then
		ColumnName = StrReplace(Items.SourceAccountsTable.CurrentItem.Name, "SourceAccountsTable", "");
		Filter.Insert(ColumnName, Items.SourceAccountsTable.CurrentData[ColumnName]);
	EndIf;
	
	If Filter.Count() > 0 Then
		RowFilterForSource = New FixedStructure(Filter);
	Else
		RowFilterForSource = Undefined;
	EndIf;
	
	Return RowFilterForSource;
	
EndFunction

&AtClient
Procedure DeleteMapping(SourceAccount, ReceivingAccount)
	
	If InvertTables Then
		Filter = New Structure("SourceAccount", "ReceivingAccount");
	Else
		Filter = New Structure("SourceAccount", "SourceAccount");
	EndIf;
	
	SourceArray = SourceAccountsTable.FindRows(Filter);
	If SourceArray.Count() > 0 Then
		SourceArray[0].Mapped = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure FormRefresh()
	
	CurrentMapping = FormAttributeToValue("ReceiverAccountsTable");
	InvertTables = (MappingSettings <> DescriptionSourceChartOfAccounts);
	
	If InvertTables Then
		
		Query = New Query("
		|SELECT
		|	Table.Mapped AS Mapped,
		|	Table.UseDr AS UseDr,
		|	Table.UseCr AS UseCr,
		|	Table.MappingID AS MappingID,
		|	Table.ReceivingAccount AS ReceivingAccount,
		|	Table.CorrSourceAccount AS CorrSourceAccount,
		|	Table.Ref AS Ref,
		|	Table.SetingsSaved AS SetingsSaved,
		|	Table.ReceivingAccountCode AS ReceivingAccountCode,
		|	Table.SourceAccount AS SourceAccount
		|INTO CurrentMapping
		|FROM
		|	&CurrentMapping AS Table
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Table.Ref AS SourceAccount,
		|	Table.Description AS SourceAccountDescription,
		|	Table.Currency AS Currency,
		|	CurrentMapping.Mapped AS Mapped,
		|	ISNULL(CurrentMapping.UseDr, FALSE) AS UseDr,
		|	ISNULL(CurrentMapping.UseCr, FALSE) AS UseCr,
		|	ISNULL(CurrentMapping.MappingID, FALSE) AS MappingID,
		|	ISNULL(CurrentMapping.ReceivingAccount, &EmptyRef) AS ReceivingAccount,
		|	ISNULL(CurrentMapping.CorrSourceAccount, &EmptyRef) AS CorrSourceAccount,
		|	ISNULL(CurrentMapping.Ref, VALUE(Catalog.Mapping.EmptyRef)) AS Ref,
		|	ISNULL(CurrentMapping.SetingsSaved, FALSE) AS SetingsSaved,
		|	CurrentMapping.ReceivingAccountCode AS ReceivingAccountCode
		|FROM
		|	&ChartOfAccounts AS Table
		|		LEFT JOIN CurrentMapping AS CurrentMapping
		|		ON Table.Ref = CurrentMapping.SourceAccount
		|
		|ORDER BY
		|	Table.Code HIERARCHY,
		|	ReceivingAccountCode");
		
		Query.Text = StrReplace(Query.Text, "&ChartOfAccounts", "ChartOfAccounts." + NameSourceChartOfAccounts);
		Query.Text = StrReplace(Query.Text, "&EmptyRef", "VALUE(ChartOfAccounts." + NameSourceChartOfAccounts + ".EmptyRef)");
		
		Query.SetParameter("CurrentMapping", CurrentMapping);
		
		FieldName = "ReceivingAccount";
		
	Else
		
		Query = New Query("
		|SELECT
		|	Table.Mapped AS Mapped,
		|	Table.UseDr AS UseDr,
		|	Table.UseCr AS UseCr,
		|	Table.MappingID AS MappingID,
		|	Table.ReceivingAccount AS ReceivingAccount,
		|	Table.CorrSourceAccount AS CorrSourceAccount,
		|	Table.Ref AS Ref,
		|	Table.SetingsSaved AS SetingsSaved,
		|	Table.SourceAccountCode AS SourceAccountCode,
		|	Table.SourceAccount AS SourceAccount
		|INTO CurrentMapping
		|FROM
		|	&CurrentMapping AS Table
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Table.Ref AS ReceivingAccount,
		|	Table.Description AS SourceAccountDescription,
		|	Table.Currency AS Currency,
		|	CurrentMapping.Mapped AS Mapped,
		|	ISNULL(CurrentMapping.UseDr, FALSE) AS UseDr,
		|	ISNULL(CurrentMapping.UseCr, FALSE) AS UseCr,
		|	ISNULL(CurrentMapping.MappingID, FALSE) AS MappingID,
		|	ISNULL(CurrentMapping.SourceAccount, &EmptyRef) AS SourceAccount,
		|	ISNULL(CurrentMapping.CorrSourceAccount, &EmptyRef) AS CorrSourceAccount,
		|	ISNULL(CurrentMapping.Ref, VALUE(Catalog.Mapping.EmptyRef)) AS Ref,
		|	ISNULL(CurrentMapping.SetingsSaved, FALSE) AS SetingsSaved,
		|	CurrentMapping.SourceAccountCode AS SourceAccountCode
		|FROM
		|	&ChartOfAccounts AS Table
		|		LEFT JOIN CurrentMapping AS CurrentMapping
		|		ON Table.Ref = CurrentMapping.ReceivingAccount
		|
		|ORDER BY
		|	Table.Code HIERARCHY,
		|	SourceAccountCode");
		
		Query.Text = StrReplace(Query.Text, "&ChartOfAccounts", "ChartOfAccounts." + NameReceiverChartOfAccounts);
		Query.Text = StrReplace(Query.Text, "&EmptyRef", "VALUE(ChartOfAccounts." + NameReceiverChartOfAccounts + ".EmptyRef)");
		
		Query.SetParameter("CurrentMapping", CurrentMapping);
		
		FieldName = "SourceAccount";
		
	EndIf;
	
	Query.TempTablesManager = New TempTablesManager;
	
	Result = Query.Execute().Unload();
	ReceiverAccountsTable.Clear();
	
	CurrentAccount = "";
	For Each AccountRow In Result Do
		
		NewRow = ReceiverAccountsTable.Add();
		FillPropertyValues(NewRow, AccountRow);
		
		If CurrentAccount = AccountRow[FieldName] Then
			NewRow.SourceAccountDescription = "";
		Else
			CurrentAccount = AccountRow[FieldName];
		EndIf;;
		
	EndDo;
	
	Items.ReceiverAccountsTableSourceAccountInv.Visible = InvertTables;
	Items.ReceiverAccountsTableReceivingAccountInv.Visible = InvertTables;
	
	Items.ReceiverAccountsTableSourceAccount.Visible = Not InvertTables;
	Items.ReceiverAccountsTableReceivingAccount.Visible = Not InvertTables;
	
	If InvertTables Then
		
		Query.Text = 
		"SELECT DISTINCT
		|	Table.Ref AS SourceAccount,
		|	Table.Code AS Code,
		|	Table.Description AS Description,
		|	CurrentSettings.Mapped AS Mapped,
		|	Table.Description AS SourceAccountDescription,
		|	Table.Currency AS Currency,
		|	&IsHeaderField AS IsHeader
		|FROM
		|	&ChartOfAccounts AS Table
		|		LEFT JOIN CurrentMapping AS CurrentSettings
		|		ON Table.Ref = CurrentSettings.ReceivingAccount
		|
		|ORDER BY
		|	Table.Code HIERARCHY
		|";
		
		NameChartOfAccounts = NameReceiverChartOfAccounts;
		
	Else
		
		Query.Text = 
		"SELECT DISTINCT
		|	Table.Ref AS SourceAccount,
		|	Table.Code AS Code,
		|	Table.Description AS Description,
		|	CurrentSettings.Mapped AS Mapped,
		|	Table.Description AS SourceAccountDescription,
		|	Table.Currency AS Currency,
		|	&IsHeaderField AS IsHeader
		|FROM
		|	&ChartOfAccounts AS Table
		|		LEFT JOIN CurrentMapping AS CurrentSettings
		|		ON Table.Ref = CurrentSettings.SourceAccount
		|
		|ORDER BY
		|	Table.Code HIERARCHY
		|";
		
		NameChartOfAccounts = NameSourceChartOfAccounts;
		
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&ChartOfAccounts", "ChartOfAccounts." + NameChartOfAccounts);
	
	HasTypeOfAccount = Common.HasObjectAttribute("TypeOfAccount", Metadata.ChartsOfAccounts[NameChartOfAccounts]);
	If HasTypeOfAccount Then
		IsHeaderField = "CASE WHEN Table.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Header) THEN TRUE ELSE FALSE END";
	Else
		IsHeaderField = "FALSE";
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&IsHeaderField", IsHeaderField);
	
	SourceAccountsTable.Clear();
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewRow = SourceAccountsTable.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
	If InvertTables Then
		SetSourceChartOfAccountsTitle(DescriptionReceiverChartOfAccounts);
	Else
		SetSourceChartOfAccountsTitle(DescriptionSourceChartOfAccounts);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetColumsTypes()
	
	Array = New Array();
	Array.Add(Type("ChartOfAccountsRef." + NameSourceChartOfAccounts));
	
	TypeDescription = New TypeDescription(Array);
	
	Items.ReceiverAccountsTableSourceAccount.TypeRestriction = TypeDescription;
	Items.ReceiverAccountsTableCorrSourceAccount.TypeRestriction = TypeDescription;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"SourceAccountsTable.IsHeader",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "SourceAccountsTable");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Font", New Font( , , True));
	
EndProcedure

&AtServer
Procedure SetSourceChartOfAccountsTitle(DescriptionChartOfAccounts)
	
	Items.GroupSourceChartOfAccounts.Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Source chart of accounts: %1'; ru = 'Исходный план счетов: %1';pl = 'Źródłowy płan kont: %1';es_ES = 'Diagrama fuente de las cuentas:%1';es_CO = 'Diagrama fuente de las cuentas:%1';tr = 'Kaynak hesap planı: %1';it = 'Sorgente piano dei conti: %1';de = 'Ursprungs-Kontenplan: %1'"),
		DescriptionChartOfAccounts);
	
EndProcedure

#EndRegion