
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If ValueIsFilled(Object.Ref) Then
		
		If Not WriteParameters.Property("NoCheckValueTypes") Then
			
			UsingParameters = CheckValueTypeChange();
			ShouldAskQuestion = UsingParameters.UsedInTemplates;
			
			If ShouldAskQuestion Then
				Cancel = True;
				CheckTypes(UsingParameters);
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region Private

&AtServer
Function CheckValueTypeChange()
	
	OldValue = Common.ObjectAttributeValue(Object.Ref, "ValueType");
	UsingParameters = New Structure("UsedInEntries, UsedInTemplates", False, False);
	
	If Object.ValueType <> OldValue Then
	
		Query = New Query;
		Query.Text = 
		"SELECT
		|	AnalyticalDimensionsSetsAnalyticalDimensions.Ref AS Ref
		|INTO TemporaryTableDimensionsSets
		|FROM
		|	Catalog.AnalyticalDimensionsSets.AnalyticalDimensions AS AnalyticalDimensionsSetsAnalyticalDimensions
		|WHERE
		|	AnalyticalDimensionsSetsAnalyticalDimensions.AnalyticalDimension = &AnalyticalDimension
		|
		|GROUP BY
		|	AnalyticalDimensionsSetsAnalyticalDimensions.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MasterChartOfAccounts.Ref AS Ref,
		|	TemporaryTableDimensionsSets.Ref AS Set,
		|	MasterChartOfAccounts.Code AS Code,
		|	MasterChartOfAccounts.Description AS Description
		|INTO TemporaryTableChartsOfAccounts
		|FROM
		|	TemporaryTableDimensionsSets AS TemporaryTableDimensionsSets
		|		INNER JOIN ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
		|		ON TemporaryTableDimensionsSets.Ref = MasterChartOfAccounts.AnalyticalDimensionsSet
		|
		|GROUP BY
		|	MasterChartOfAccounts.Ref,
		|	TemporaryTableDimensionsSets.Ref,
		|	MasterChartOfAccounts.Code,
		|	MasterChartOfAccounts.Description
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TemporaryTableDimensionsSets.Ref AS Ref,
		|	AnalyticalDimensionsSets.Ref AS Set,
		|	""AnalyticalDimensionSets"" AS Type,
		|	AnalyticalDimensionsSets.Code AS Code,
		|	AnalyticalDimensionsSets.Description AS Description
		|FROM
		|	TemporaryTableChartsOfAccounts AS TemporaryTableChartsOfAccounts
		|		INNER JOIN Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
		|		ON (TemporaryTableChartsOfAccounts.Ref = AccountingEntriesTemplatesEntriesSimple.AccountDr
		|				OR TemporaryTableChartsOfAccounts.Ref = AccountingEntriesTemplatesEntriesSimple.AccountCr)
		|		LEFT JOIN Catalog.AnalyticalDimensionsSets AS AnalyticalDimensionsSets
		|		ON TemporaryTableChartsOfAccounts.Set = AnalyticalDimensionsSets.Ref,
		|	TemporaryTableDimensionsSets AS TemporaryTableDimensionsSets
		|
		|UNION ALL
		|
		|SELECT
		|	TemporaryTableChartsOfAccounts.Ref,
		|	TemporaryTableChartsOfAccounts.Set,
		|	""Accounts"",
		|	TemporaryTableChartsOfAccounts.Code,
		|	TemporaryTableChartsOfAccounts.Description
		|FROM
		|	TemporaryTableChartsOfAccounts AS TemporaryTableChartsOfAccounts
		|
		|UNION ALL
		|
		|SELECT
		|	AccountingEntriesTemplatesEntriesSimple.Ref,
		|	TemporaryTableChartsOfAccounts.Set,
		|	""AccountingEntriesTemplates"",
		|	AccountingEntriesTemplates.Code,
		|	AccountingEntriesTemplates.Description
		|FROM
		|	TemporaryTableChartsOfAccounts AS TemporaryTableChartsOfAccounts
		|		INNER JOIN Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
		|			INNER JOIN Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
		|			ON AccountingEntriesTemplatesEntriesSimple.Ref = AccountingEntriesTemplates.Ref
		|		ON (TemporaryTableChartsOfAccounts.Ref = AccountingEntriesTemplatesEntriesSimple.AccountDr
		|				OR TemporaryTableChartsOfAccounts.Ref = AccountingEntriesTemplatesEntriesSimple.AccountCr)
		|
		|UNION ALL
		|
		|SELECT
		|	AccountingEntriesTemplatesEntries.Ref,
		|	TemporaryTableChartsOfAccounts.Set,
		|	""AccountingEntriesTemplates"",
		|	AccountingEntriesTemplates.Code,
		|	AccountingEntriesTemplates.Description
		|FROM
		|	TemporaryTableChartsOfAccounts AS TemporaryTableChartsOfAccounts
		|		INNER JOIN Catalog.AccountingEntriesTemplates.Entries AS AccountingEntriesTemplatesEntries
		|			INNER JOIN Catalog.AccountingEntriesTemplates AS AccountingEntriesTemplates
		|			ON AccountingEntriesTemplatesEntries.Ref = AccountingEntriesTemplates.Ref
		|		ON TemporaryTableChartsOfAccounts.Ref = AccountingEntriesTemplatesEntries.Account
		|TOTALS
		|	MAX(Ref)
		|BY
		|	Type";
		
		Query.SetParameter("AnalyticalDimension", Object.Ref);
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			UsingParameters.Insert("UsedInTemplates", True);
		EndIf;
			
		UsingTree = QueryResult.Unload(QueryResultIteration.ByGroups);
		ValueToFormAttribute(UsingTree, "Using");
		
	EndIf;
	
	UsingParameters.Insert("OldValue", OldValue);
	
	Return UsingParameters;
	
EndFunction

&AtClient
Procedure CheckTypes(UsingParameters)
	
	Types = Object.ValueType.Types();
	OldTypes = UsingParameters.OldValue.Types();
	UsingObjectsString = "";
		
	AllTypesAreLeft = True;
	
	For Each OldType In OldTypes Do
		
		If Types.Find(OldType) = Undefined Then
			AllTypesAreLeft = False;
			Break;
		EndIf;
		
	EndDo;
	
	If AllTypesAreLeft Then
		
		QueryBoxText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagesToUserClientServer.GetManagerialAnalyticalDimensionTypeLeftWarning(),
			Object.Ref);
			
		ShowQueryBox(New NotifyDescription("CheckTypesEnd", ThisObject, UsingParameters),
			QueryBoxText,
			QuestionDialogMode.YesNo);
	Else
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagesToUserClientServer.GetManagerialAnalyticalDimensionSaveErrorText(),
			Object.Ref);
		
		ShowUsing();
		ShowMessageBox(, MessageText)
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckTypesEnd(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		ShowUsing();
		
		AdditionalParameters.Insert("NoCheckValueTypes", True);
		Write(AdditionalParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowUsing()
	
	ClearMessages();
	
	For Each TypeRow In Using.GetItems() Do
		
		UsingType = GetUsingType(TypeRow.Ref);
		CommonClientServer.MessageToUser(UsingType + ":");
		
		For Each Row In TypeRow.GetItems() Do
			CommonClientServer.MessageToUser(Row.Code + ", " + Row.Description);
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function GetUsingType(Ref)
	
	If TypeOf(Ref) = Type("ChartOfAccountsRef.MasterChartOfAccounts") Then
		Return NStr("en = 'Accounts'; ru = 'Счета учета';pl = 'Konta';es_ES = 'Cuentas';es_CO = 'Cuentas';tr = 'Hesaplar';it = 'Conti';de = 'Konten'");
	EndIf;
	
	Return Ref.Metadata().Synonym;
	
EndFunction

#EndRegion
